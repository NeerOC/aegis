-- Spell cache and wrapper (mirrors Aegis common/spell.lua).
local FAIL_BACKOFF = 0.0
local CAST_THROTTLE = 0.0

Aegis._cast_throttle_until = Aegis._cast_throttle_until or 0

local function cast_success_throttle()
  local ms = AegisSettings and AegisSettings.AegisCastSuccessThrottleMs
  return (tonumber(ms) or 30) / 1000
end

local CAST_OPTS_G1 = { ground = 1 }

local RESULT_SUCCESS = 0
local RESULT_THROTTLED = 9
local RESULT_NOT_READY = 10
local RESULT_ON_CD = 11
local RESULT_QUEUED = 12

local SPELL_DEBUG_MAX = 80
Aegis._spell_debug_log = Aegis._spell_debug_log or {}
Aegis._spell_debug_idx = Aegis._spell_debug_idx or 0

local RESULT_NAMES = {
  [0]  = "SUCCESS",
  [9]  = "THROTTLED",
  [10] = "NOT_READY",
  [11] = "ON_CD",
  [12] = "QUEUED",
}

Aegis._spell_debug_tick = Aegis._spell_debug_tick or 0

local function spell_debug_log(entry)
  if not AegisSettings or not AegisSettings.AegisSpellDebug then return end
  entry.time_real = os.time()
  entry.tick = Aegis._spell_debug_tick
  local log = Aegis._spell_debug_log
  Aegis._spell_debug_idx = Aegis._spell_debug_idx + 1
  local idx = ((Aegis._spell_debug_idx - 1) % SPELL_DEBUG_MAX) + 1
  log[idx] = entry
end

---@class SpellWrapper
---@field Id number       The spell ID.
---@field Name string     Human-readable spell name (matches spellbook).
---@field IsKnown boolean True when the player currently knows this spell.
local SpellWrapper = {}
SpellWrapper.__index = SpellWrapper

function SpellWrapper:new(id, name)
  return setmetatable({
    Id = id or 0,
    Name = name or "",
    IsKnown = id and id > 0 and (game.is_spell_known(id) or false) or false,
    _fail_until = 0,
    _cast_until = 0,
  }, SpellWrapper)
end

function SpellWrapper:IsReady()
  if self.Id == 0 or not self.IsKnown then
    return false
  end
  local now = os.clock()
  if now < self._fail_until or now < self._cast_until then
    return false
  end
  local ok, cd = pcall(game.spell_cooldown, self.Id)
  if not ok or not cd then
    return false
  end
  return not cd.on_cooldown and cd.enabled
end

function SpellWrapper:IsUsable()
  if self.Id == 0 or not self.IsKnown then
    return false
  end
  if game.is_usable_spell then
    local ok, usable, nomana = pcall(game.is_usable_spell, self.Id)
    if ok and usable ~= nil then
      return usable
    end
  end
  return self:IsReady()
end

function SpellWrapper:NoMana()
  if self.Id == 0 then
    return false
  end
  if game.is_usable_spell then
    local ok, usable, nomana = pcall(game.is_usable_spell, self.Id)
    if ok and nomana ~= nil then
      return nomana
    end
  end
  return false
end

function SpellWrapper:GetCooldown()
  if self.Id == 0 then
    return nil
  end
  local ok, cd = pcall(game.spell_cooldown, self.Id)
  return ok and cd or nil
end

--- Seconds remaining on this spell's cooldown (0 if ready / not on CD).
function SpellWrapper:CooldownRemains()
  local cd = self:GetCooldown()
  if not cd or not cd.on_cooldown then return 0 end
  return cd.remains or cd.duration or 0
end

--- Fetch the WoW Lua-side GetSpellInfo tuple. The immutable fields
--- (name/rank/icon/minRange/maxRange) are cached on the wrapper; castTime
--- is returned live each call since it shifts with talents and haste.
--- Returns nil when the bridge or spell id is unavailable.
function SpellWrapper:_LiveInfo()
  if self.Id == 0 then return nil, 0 end
  if not wow or not wow.call_game_lua then return nil, 0 end
  local ok, name, rank, icon, castTime, minRange, maxRange =
      pcall(wow.call_game_lua, "GetSpellInfo", self.Id)
  if not ok or name == nil then return self._info_cache, 0 end
  if not self._info_cache then
    self._info_cache = {
      name     = name or "",
      rank     = rank or "",
      icon     = icon or "",
      minRange = tonumber(minRange) or 0,
      maxRange = tonumber(maxRange) or 0,
    }
  end
  return self._info_cache, tonumber(castTime) or 0
end

--- Cast time in seconds. 0 for instants. Live (talents + haste applied).
function SpellWrapper:CastTime()
  if self.Id == 0 then return 0 end
  local _info, ct_ms = self:_LiveInfo()
  if ct_ms > 0 then return ct_ms / 1000 end
  if _info then return 0 end
  -- Bridge unavailable: fall back to the shim DB leaf.
  local ok, db = pcall(game.get_spell_info, self.Id)
  if not ok or not db then return 0 end
  local ms = db.cast_time or db.cast_time_ms or 0
  if ms <= 0 then return 0 end
  return ms > 10 and (ms / 1000) or ms
end

--- Rank string (e.g. "Rank 5"). Empty when not ranked or bridge missing.
function SpellWrapper:Rank()
  local info = self:_LiveInfo()
  return info and info.rank or ""
end

--- Icon texture path. Empty when bridge missing.
function SpellWrapper:Icon()
  local info = self:_LiveInfo()
  return info and info.icon or ""
end

--- Max range in yards. 0 = no declared range (self/melee/buff).
function SpellWrapper:MaxRange()
  local info = self:_LiveInfo()
  if info then return info.maxRange end
  local ok, db = pcall(game.get_spell_info, self.Id)
  return ok and db and (db.max_range or 0) or 0
end

--- Min range in yards. 0 = no minimum.
function SpellWrapper:MinRange()
  local info = self:_LiveInfo()
  if info then return info.minRange end
  local ok, db = pcall(game.get_spell_info, self.Id)
  return ok and db and (db.min_range or 0) or 0
end

local SCHOOL_INDEX = {
  Physical = 1,
  Holy = 2,
  Fire = 3,
  Nature = 4,
  Frost = 5,
  Shadow = 6,
  Arcane = 7,
}

---@return number|nil total Scaled DoT damage, or nil when not a parseable DoT.
function SpellWrapper:DotTotal()
  if self.Id == 0 then return nil end
  local now = os.clock()
  if self._dot_total_at and (now - self._dot_total_at) < 1.0 then
    return self._dot_total
  end
  if not wow or not wow.run_lua or not wow.read_lua_path then return nil end

  local script = [[
    local tip = _G.__aegis_dot_tip
    if not tip then
      tip = CreateFrame("GameTooltip", "AegisDotScanTip", UIParent, "GameTooltipTemplate")
      _G.__aegis_dot_tip = tip
    end
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    tip:ClearLines()
    if tip.SetSpellByID then tip:SetSpellByID(]] .. self.Id .. [[)
    else tip:SetHyperlink("spell:]] .. self.Id .. [[") end
    local base, school, duration
    local nlines = tip.NumLines and tip:NumLines() or 0
    for i = 4, nlines do
      local fs = _G["AegisDotScanTipTextLeft" .. i]
      local t = fs and fs:GetText() or ""
      if t ~= "" then
        local b, sch, d = t:match("(%d+)%s+(%a+)%s+damage%s+over%s+(%d+)%s+sec")
        if b then
          base, school, duration = tonumber(b), sch, tonumber(d)
          break
        end
        local b2, d2 = t:match("(%d+)%s+damage%s+over%s+(%d+)%s+sec")
        if b2 then
          base, duration = tonumber(b2), tonumber(d2)
          break
        end
      end
    end
    local req = 0
    if C_Spell and C_Spell.GetSpellLevelLearned then
      req = C_Spell.GetSpellLevelLearned(]] .. self.Id .. [[) or 0
    end
    _G.__aegis_dot_base     = base or 0
    _G.__aegis_dot_school   = school or ""
    _G.__aegis_dot_duration = duration or 0
    _G.__aegis_dot_req_lvl  = req
  ]]

  if not pcall(wow.run_lua, script) then return nil end

  local base = tonumber(wow.read_lua_path("__aegis_dot_base")) or 0
  if base <= 0 then
    self._dot_total    = nil
    self._dot_total_at = now
    return nil
  end

  local school     = tostring(wow.read_lua_path("__aegis_dot_school") or "")
  local duration   = tonumber(wow.read_lua_path("__aegis_dot_duration")) or 0
  local req_lvl    = tonumber(wow.read_lua_path("__aegis_dot_req_lvl")) or 0

  ---@type number
  local sp         = 0
  local school_idx = SCHOOL_INDEX[school]
  if school_idx and wow.eval_lua then
    local ok, v = pcall(wow.eval_lua, "GetSpellBonusDamage(" .. school_idx .. ")")
    if ok then
      local n = tonumber(v)
      if n then sp = n end
    end
  end

  local player_lvl = (Me and Me.Level) or 0
  local coef       = duration > 0 and math.min(1.0, duration / 15) or 0
  local penalty    = 1.0
  if req_lvl > 0 and player_lvl > 0 then
    penalty = math.min(1.0, (req_lvl + 11) / player_lvl)
  end

  local scaled       = base + sp * coef * penalty

  Aegis._dot_last    = {
    base       = base,
    school     = school,
    duration   = duration,
    req_lvl    = req_lvl,
    player_lvl = player_lvl,
    sp         = sp,
    coef       = coef,
    penalty    = penalty,
    scaled     = scaled,
  }

  self._dot_total    = scaled
  self._dot_total_at = now
  return scaled
end

---@param target Unit       The enemy to apply the DoT to.
---@param min_landing_pct? number  Minimum % of total DoT damage that must land before target dies (default 0 = always cast).
---@return boolean cast     True if the cast was issued, false if skipped.
function SpellWrapper:Apply(target, min_landing_pct)
  if not target or target.IsDead then return false end
  if self.Name ~= "" and target.HasDebuffByMe and target:HasDebuffByMe(self.Name) then
    return false
  end
  local total = self:DotTotal()
  if not total or total <= 0 then
    return self:CastEx(target)
  end
  local hp = target.Health or 0
  if hp <= 0 then return false end
  local landing_pct = (math.min(hp, total) / total) * 100
  if landing_pct < (min_landing_pct or 0) then return false end
  return self:CastEx(target)
end

function SpellWrapper:InRange(target)
  if not target then return true end
  if Me and (target == Me or (target.Guid and target.Guid == Me.Guid)) then
    return true
  end
  local max_range = self:MaxRange()
  if max_range < 0.1 then
    return Me and Me:InMeleeRange(target) or false
  end
  local d = Me and Me:GetDistance(target) or -1
  if d < 0 then return true end
  return d <= max_range
end

function SpellWrapper:IsCurrentSpell()
  if self.Id == 0 then
    return false
  end
  local ok, val = pcall(game.IsCurrentSpell, self.Id)
  return ok and val or false
end

function SpellWrapper:IsAutoRepeat()
  if self.Id == 0 then
    return false
  end
  local ok, val = pcall(game.IsAutoRepeatSpell, self.Id)
  return ok and val or false
end

--- Returns true if helpful, false if harmful, nil if unknown.
function SpellWrapper:IsHelpful()
  if self.Id == 0 then
    return nil
  end
  local ok, val = pcall(wow.eval_lua, "C_Spell.IsSpellHelpful(" .. self.Id .. ")")
  if ok and val ~= nil then
    return val
  end
  return nil
end

--- Low-level cast via cast_spell_at_unit.
function SpellWrapper:Cast(target)
  if self.Id == 0 then
    return -1, "no spell id"
  end

  if target and target.obj_ptr then
    local ok, c, desc = pcall(game.cast_spell_at_unit, self.Id, target.obj_ptr, CAST_OPTS_G1)
    if ok then
      return c, desc or ""
    end
    return -1, tostring(c)
  end

  if Me and Me.obj_ptr then
    local ok, c, desc = pcall(game.cast_spell_at_unit, self.Id, Me.obj_ptr, CAST_OPTS_G1)
    if ok then
      return c, desc or ""
    end
    return -1, tostring(c)
  end

  return -1, "no target obj_ptr"
end

--- Full-check cast: known → throttle → cooldown → Cast().
function SpellWrapper:CastEx(target, opts, skipusable2, skipfacing2, skiplos2)
  if type(opts) == "table" then
    opts = opts
  else
    opts = { skipUsable = opts or false, skipFacing = skipusable2 or false, skipLos = skiplos2 or false }
  end
  local skipusable = opts.skipUsable or false
  local skipfacing = opts.skipFacing or false
  local skiplos    = opts.skipLos or false
  local skipmoving = opts.skipMoving or false
  local debugging  = AegisSettings and AegisSettings.AegisSpellDebug or false
  local tgt_name   = target and target.Name or "self"
  local tgt_hp     = target and target.HealthPct or nil

  if self.Id == 0 or not self.IsKnown then
    return false
  end
  if Aegis._tick_throttled then
    return false
  end

  local now = os.clock()
  if now < self._fail_until then
    if debugging then
      spell_debug_log({
        time = now,
        spell = self.Name,
        id = self.Id,
        target = tgt_name,
        target_hp = tgt_hp,
        result = "SKIP",
        reason = "fail_backoff",
        detail = string.format("until=%.2f", self._fail_until)
      })
    end
    return false
  end
  if now < self._cast_until then
    if debugging then
      spell_debug_log({
        time = now,
        spell = self.Name,
        id = self.Id,
        target = tgt_name,
        target_hp = tgt_hp,
        result = "SKIP",
        reason = "cast_throttle",
        detail = string.format("until=%.2f", self._cast_until)
      })
    end
    return false
  end

  local throttle_until = Aegis._cast_throttle_until or 0
  if now < throttle_until then
    if debugging then
      spell_debug_log({
        time = now,
        spell = self.Name,
        id = self.Id,
        target = tgt_name,
        target_hp = tgt_hp,
        result = "SKIP",
        reason = "global_cast_throttle",
        detail = string.format("until=%.2f", throttle_until)
      })
    end
    return false
  end

  local is_usable = true
  if not skipusable then
    local ok, usable = pcall(game.is_usable_spell, self.Id)
    if ok and not usable then
      if debugging then
        spell_debug_log({
          time = now,
          spell = self.Name,
          id = self.Id,
          target = tgt_name,
          target_hp = tgt_hp,
          result = "SKIP",
          reason = "not_usable",
          detail = "is_usable_spell=false"
        })
      end
      return false
    end
    is_usable = not ok or usable
  end

  local cok, cd = pcall(game.spell_cooldown, self.Id)
  if cok and cd and cd.on_cooldown then
    if debugging then
      spell_debug_log({
        time = now,
        spell = self.Name,
        id = self.Id,
        target = tgt_name,
        target_hp = tgt_hp,
        result = "SKIP",
        reason = "on_cooldown",
        detail = string.format("dur=%.1f", cd.duration or 0)
      })
    end
    return false
  end

  if not skipmoving and Me and Me.IsMoving and Me:IsMoving() then
    local ct = self:CastTime()
    if ct > 0 then
      if debugging then
        spell_debug_log({
          time = now,
          spell = self.Name,
          id = self.Id,
          target = tgt_name,
          target_hp = tgt_hp,
          result = "SKIP",
          reason = "moving",
          detail = string.format("cast_time=%.2f", ct)
        })
      end
      return false
    end
  end

  local dist = -1
  if target and target ~= Me and Me and Me.GetDistance then
    dist = Me:GetDistance(target)
  end

  if target and target ~= Me and not self:InRange(target) then
    if debugging then
      spell_debug_log({
        time = now,
        spell = self.Name,
        id = self.Id,
        target = tgt_name,
        target_hp = tgt_hp,
        target_dist = dist,
        result = "SKIP",
        reason = "out_of_range"
      })
    end
    return false
  end

  local point_blank = dist >= 0 and dist < 2.0
  local target_is_friend = false
  if target and target ~= Me and Me and Me.CanAttack then
    target_is_friend = not Me:CanAttack(target)
  end

  if not point_blank and not skipfacing and not target_is_friend and not self:IsHelpful()
      and target and target ~= Me and Me and Me.obj_ptr and target.obj_ptr then
    local fok, facing = pcall(game.is_facing, Me.obj_ptr, target.obj_ptr)
    if fok and not facing then
      if debugging then
        spell_debug_log({
          time = now,
          spell = self.Name,
          id = self.Id,
          target = tgt_name,
          target_hp = tgt_hp,
          target_dist = dist,
          result = "SKIP",
          reason = "not_facing"
        })
      end
      return false
    end
  end

  local code, desc = self:Cast(target)

  if debugging then
    spell_debug_log({
      time = now,
      spell = self.Name,
      id = self.Id,
      target = tgt_name,
      target_hp = tgt_hp,
      target_dist = dist > 0 and dist or nil,
      result = RESULT_NAMES[code] or string.format("FAIL(%d)", code),
      reason = desc or "",
      detail = string.format("usable=%s cd=%s",
        tostring(is_usable),
        (cok and cd) and (cd.on_cooldown and "yes" or "no") or "?")
    })
  end

  if code == RESULT_SUCCESS or code == RESULT_QUEUED then
    Aegis._last_cast = self.Name
    Aegis._last_cast_time = now
    Aegis._last_cast_tgt = tgt_name
    Aegis._last_cast_code = code
    Aegis._last_cast_desc = desc or ""
    Aegis._current_action = "CAST: " .. self.Name .. " -> " .. (tgt_name or "self")
    self._fail_until = 0
    self._cast_until = now + CAST_THROTTLE
    return true
  elseif code == RESULT_THROTTLED then
    Aegis._tick_throttled = true
    return false
  elseif code == RESULT_NOT_READY or code == RESULT_ON_CD then
    Aegis._tick_throttled = true
    return false
  else
    self._fail_until = now + FAIL_BACKOFF
    Aegis._last_fail = self.Name
    Aegis._last_fail_time = now
    Aegis._last_fail_code = code
    Aegis._last_fail_desc = desc or ""
    return false
  end
end

--- Cast at a world position (ground-targeted AoE).
function SpellWrapper:CastAtPos(x_or_entity, y, z)
  if self.Id == 0 or not self.IsKnown then
    return false
  end
  if Aegis._tick_throttled then
    return false
  end

  local now = os.clock()
  if now < self._fail_until or now < self._cast_until then
    return false
  end

  local uok, usable = pcall(game.is_usable_spell, self.Id)
  if uok and not usable then
    return false
  end
  local cok, cd = pcall(game.spell_cooldown, self.Id)
  if cok and cd and cd.on_cooldown then
    return false
  end

  local x
  if type(x_or_entity) == "table" and x_or_entity.Position then
    local pos = x_or_entity.Position
    x, y, z = pos.x, pos.y, pos.z
  else
    x = x_or_entity
  end

  if not x or not y or not z then
    return false
  end

  local ok, c, d = pcall(game.cast_at_pos, self.Id, x, y, z)
  local code = ok and c or -1
  local desc = ok and (d or "") or tostring(c)

  if code == RESULT_SUCCESS or code == RESULT_QUEUED then
    Aegis._last_cast = self.Name
    Aegis._last_cast_time = now
    Aegis._last_cast_tgt = "ground"
    Aegis._last_cast_code = code
    Aegis._last_cast_desc = desc
    self._fail_until = 0
    self._cast_until = now + CAST_THROTTLE
    return true
  elseif code == RESULT_THROTTLED then
    Aegis._tick_throttled = true
    return false
  elseif code == RESULT_NOT_READY or code == RESULT_ON_CD then
    Aegis._tick_throttled = true
    return false
  else
    self._fail_until = now + FAIL_BACKOFF
    Aegis._last_fail = self.Name
    Aegis._last_fail_time = now
    Aegis._last_fail_code = code
    Aegis._last_fail_desc = desc
    return false
  end
end

---@class InterruptOptions
---@field playersOnly? boolean  Only consider Player-type targets. Defaults to false.
---@field customRange? number   Override max range (yards). Defaults to the spell's max_range.

---@param options? InterruptOptions
function SpellWrapper:Interrupt(options)
  options            = options or {}
  local players_only = options.playersOnly or false
  local custom_range = options.customRange

  local mode         = AegisSettings.AegisInterruptMode or 0
  if mode == 2 then
    return false
  end

  if not self:IsReady() then
    return false
  end

  local spell_range = custom_range
  if not spell_range then
    local ok, info = pcall(game.get_spell_info, self.Id)
    if ok and info and info.max_range and info.max_range > 0 then
      spell_range = info.max_range
    else
      spell_range = 5
    end
  end

  local current_target = Me and Me.Target or nil
  local current_target_guid = current_target and not current_target.IsDead and current_target.Guid or nil

  local ok, interrupts = pcall(require, "data.interrupts")
  if not ok then
    interrupts = nil
  end

  local targets = Combat and Combat.Targets or {}
  local best_target = nil
  local best_distance = math.huge

  for _, target in ipairs(targets) do
    if not target or target.IsDead then goto continue end

    if players_only and not target.is_player then goto continue end

    local casting = false
    local spell_id = 0
    local confirmed_immune = false
    local cast_info = nil

    if target.obj_ptr then
      local ok_cast, cast = pcall(game.unit_casting_info, target.obj_ptr)
      if ok_cast and cast then
        casting = true
        spell_id = cast.spell_id or 0
        cast_info = cast
        if cast.not_interruptible then confirmed_immune = true end
      else
        local ok_chan, chan = pcall(game.unit_channel_info, target.obj_ptr)
        if ok_chan and chan then
          casting = true
          spell_id = chan.spell_id or 0
          cast_info = chan
          if chan.not_interruptible then confirmed_immune = true end
        end
      end
    end

    if not casting then
      if target.IsCasting then
        casting = true
        spell_id = target.CastingSpellId or 0
      elseif target.IsChanneling then
        casting = true
        spell_id = target.ChannelingSpellId or 0
      end
    end

    if not casting or confirmed_immune then goto continue end

    if interrupts then
      local found_in_interrupts = false
      for _, int_spell_id in pairs(interrupts) do
        if type(int_spell_id) == "number" and int_spell_id == spell_id then
          found_in_interrupts = true
          break
        end
      end

      if mode == 0 and not found_in_interrupts then goto continue end
      if mode == 1 and not found_in_interrupts then goto continue end
    end

    local in_range = false
    local distance = Me:GetDistance(target)

    if Me:InMeleeRange(target) then
      in_range = true
    elseif distance <= spell_range then
      in_range = true
    end

    if not in_range then goto continue end

    if not Me:InMeleeRange(target) and Me.obj_ptr and target.obj_ptr then
      local fok, facing = pcall(game.is_facing, Me.obj_ptr, target.obj_ptr)
      if fok and not facing then goto continue end
    end

    local should_interrupt = true
    if cast_info and AegisSettings.AegisInterruptTiming then
      local now = os.clock() * 1000

      if cast_info.cast_start and cast_info.cast_end then
        local cast_duration = cast_info.cast_end - cast_info.cast_start
        local cast_remaining = cast_info.cast_end - now
        local cast_pct_remaining = (cast_remaining / cast_duration) * 100

        local interrupt_pct = AegisSettings.AegisInterruptPercentage or 80
        should_interrupt = cast_pct_remaining <= interrupt_pct
      elseif cast_info.channel_start then
        local channel_time = now - cast_info.channel_start
        local random_delay = 700 + (math.random() * 800 - 400)
        should_interrupt = channel_time > random_delay
      end
    end

    if not should_interrupt then goto continue end

    local priority = 0
    if current_target_guid and target.Guid == current_target_guid then
      priority = -1000
    else
      priority = distance
    end

    if priority < best_distance then
      best_target = target
      best_distance = priority
    end

    ::continue::
  end

  if best_target then
    Aegis._interrupt_log = Aegis._interrupt_log or {}
    Aegis._interrupt_log_idx = (Aegis._interrupt_log_idx or 0) + 1
    local slot = ((Aegis._interrupt_log_idx - 1) % 5) + 1
    Aegis._interrupt_log[slot] = {
      time = os.clock(),
      spell = best_target.CastingSpellName or best_target.ChannelingSpellName or "?",
      target = best_target.Name or "?",
      interrupt = self.Name,
    }
    Aegis._current_action = "INTERRUPT: " .. self.Name .. " -> " .. (best_target.Name or "?")
    return self:CastEx(best_target)
  end

  return false
end

local function rand_queue_throttle()
  return 0.125 + math.random() * 0.125
end

function SpellWrapper:CastQueued(target, opts)
  if self.Id == 0 or not self.IsKnown then return false end
  opts = opts or {}

  local now = os.clock()
  if now < self._fail_until then return false end
  if now < (self._queue_attempt_until or 0) then return false end

  local gcd_remains = 0
  local gok, gcd = pcall(game.spell_cooldown, 61304)
  if gok and gcd and gcd.on_cooldown then
    gcd_remains = gcd.remains or gcd.duration or 0
  end

  local cast_remains = 0
  if Me and Me.obj_ptr then
    local cok, cast = pcall(game.unit_casting_info, Me.obj_ptr)
    if cok and cast then
      local end_ms = cast.cast_end or 0
      if end_ms > 0 then
        local now_ms_val = (game.now_ms and game.now_ms()) or (os.clock() * 1000)
        cast_remains = math.max(0, (end_ms - now_ms_val) / 1000)
      end
    end
  end

  local blocker_remains = math.max(gcd_remains, cast_remains)
  local queue_window = Spell:SpellQueueWindow()

  if blocker_remains <= 0 then
    return self:CastEx(target)
  end

  if blocker_remains > queue_window then
    return false
  end

  if Aegis._tick_throttled then
    return false
  end

  if not opts.skipusable then
    local uok, usable, nomana = pcall(game.is_usable_spell, self.Id)
    if uok and not usable then
      if not nomana then return false end
    end
  end

  local cok, cd = pcall(game.spell_cooldown, self.Id)
  if cok and cd and cd.on_cooldown then
    local cd_remains = cd.remains or cd.duration or 0
    local cd_slack_ms = (AegisSettings and AegisSettings.AegisSpellQueueSlackMs) or 75
    local cd_slack = cd_slack_ms / 1000
    if cd_remains > blocker_remains + cd_slack then return false end
  end

  if target and target ~= Me then
    if not self:InRange(target) then return false end
  end

  local code, desc = self:Cast(target)

  if code == RESULT_SUCCESS or code == RESULT_QUEUED then
    Aegis._last_cast      = self.Name
    Aegis._last_cast_time = now
    Aegis._last_cast_tgt  = target and target.Name or "self"
    Aegis._last_cast_code = code
    Aegis._last_cast_desc = desc or ""
    self._fail_until      = 0
    self._cast_until      = now + CAST_THROTTLE
    return true
  elseif code == RESULT_THROTTLED or code == RESULT_NOT_READY or code == RESULT_ON_CD then
    self._queue_attempt_until = now + rand_queue_throttle()
    return false
  else
    self._fail_until      = now + FAIL_BACKOFF
    Aegis._last_fail      = self.Name
    Aegis._last_fail_time = now
    Aegis._last_fail_code = code
    Aegis._last_fail_desc = desc or ""
    return false
  end
end

local NullSpell = SpellWrapper:new(0, "")

local function fmtSpellKey(name)
  local function tchelper(first, rest)
    return first:upper() .. rest:lower()
  end
  return name:gsub("(%a)([%w_'-]*)", tchelper):gsub("[%s_'%-:(),]+", "")
end

local SpellCache = {}

---@class Spell
---@field Cache table<string, SpellWrapper>
---@field CacheCount number
---@field NullSpell SpellWrapper
---@field Wrapper SpellWrapper
---@field [string] SpellWrapper
Spell = setmetatable({
  Cache = SpellCache,
  CacheCount = 0,
  NullSpell = NullSpell,
  Wrapper = SpellWrapper,
}, {
  ---@param tbl table
  ---@param key string
  ---@return SpellWrapper
  __index = function(tbl, key)
    if SpellCache[key] then
      return SpellCache[key]
    end
    return NullSpell
  end,
})

function Spell:UpdateCache()
  SpellCache = {}

  local ok, spells = pcall(game.known_spells, true)
  if not ok or not spells then
    print("[Aegis] Spell cache: failed to read known spells")
    Spell.Cache = SpellCache
    return
  end

  -- Keep the highest-id entry per name. WoW spellbook usually lists ranks
  -- low → high, and higher-rank spells have higher ids in TBC, so taking
  -- the max id picks the top rank we actually know.
  for _, s in ipairs(spells) do
    if type(s) == "table" and s.name and s.id then
      local key = fmtSpellKey(s.name)
      local existing = SpellCache[key]
      if not existing or s.id > (existing.Id or 0) then
        SpellCache[key] = SpellWrapper:new(s.id, s.name)
      end
    end
  end

  local pok, pet_spells = pcall(game.pet_spells, true)
  if pok and pet_spells then
    for _, s in ipairs(pet_spells) do
      if type(s) == "table" and s.name and s.id then
        local key = fmtSpellKey(s.name)
        local existing = SpellCache[key]
        if not existing or s.id > (existing.Id or 0) then
          SpellCache[key] = SpellWrapper:new(s.id, s.name)
        end
      end
    end
  end

  Spell.Cache = SpellCache
  local count = 0
  for _ in pairs(SpellCache) do
    count = count + 1
  end
  Spell.CacheCount = count
  print(string.format("[Aegis] Cached %d spells", count))
end

--- Process CLEU events to extend per-spell-id double-cast throttle.
function Spell:ProcessCleuEvents(events)
  if not events or not Me or not Me.Guid then return end
  local me_guid = Me.Guid
  local now = os.clock()
  for _, ev in ipairs(events) do
    if ev.subevent == "SPELL_CAST_SUCCESS" and ev.source_guid == me_guid then
      local id = ev.spell_id or 0
      -- Skip auto-repeat shots (5019 Shoot / 75 Auto Shot) so wanding/auto-
      -- shooting doesn't keep pushing the global cast throttle forward.
      if id ~= 5019 and id ~= 75 then
        local new_until = now + cast_success_throttle()
        if new_until > (Aegis._cast_throttle_until or 0) then
          Aegis._cast_throttle_until = new_until
        end
      end
    end
  end
end

--- Check if the Global Cooldown is currently active.
function Spell:IsGCDActive()
  local ok, cd = pcall(game.spell_cooldown, 61304)
  return ok and cd and cd.on_cooldown or false
end

--- Seconds remaining on the GCD (0 if GCD is not active).
function Spell:GCDRemains()
  local ok, cd = pcall(game.spell_cooldown, 61304)
  if ok and cd and cd.on_cooldown then
    return cd.remains or cd.duration or 0
  end
  return 0
end

--- Base GCD length (seconds).
function Spell:GCD()
  return 1.5
end

--- Configured spell-queue window in seconds.
function Spell:SpellQueueWindow()
  local ms = AegisSettings and (AegisSettings.AegisSpellQueueWindowMs
    or AegisSettings.AegisSpellQueueSlackMs)
  local n = tonumber(ms)
  if n and n > 0 then
    if n > 10 then return n / 1000 end
    return n
  end
  return 0.4
end

--- Create a SpellWrapper by explicit ID.
function Spell:ById(id)
  return SpellWrapper:new(id, game.get_spell_name(id) or "")
end

--- Create a SpellWrapper by name lookup.
function Spell:ByName(name)
  local key = fmtSpellKey(name)
  if SpellCache[key] then
    return SpellCache[key]
  end
  local id = game.find_spell_id(name)
  if id then
    return SpellWrapper:new(id, name)
  end
  return NullSpell
end

local COL_SUCCESS = { 0.3, 1.0, 0.4, 1.0 }
local COL_SKIP    = { 1.0, 0.9, 0.3, 1.0 }
local COL_FAIL    = { 1.0, 0.3, 0.3, 1.0 }
local COL_DETAIL  = { 0.4, 0.4, 0.4, 1.0 }

function Spell:DrawDebugWindow()
  if not AegisSettings or not AegisSettings.AegisSpellDebug then return end

  imgui.set_next_window_size(560, 420, 4)
  local vis, open = imgui.begin_window("Aegis Spell Debug", 0)
  if not vis then
    imgui.end_window()
    return
  end
  if not open then
    AegisSettings.AegisSpellDebug = false
  end

  local log = Aegis._spell_debug_log
  local total = #log
  if total == 0 then
    imgui.text("No spell events yet. Enable the toggle and fight something.")
    imgui.end_window()
    return
  end

  local head = Aegis._spell_debug_idx or 0

  imgui.text(string.format("%d entries (newest first)  |  tick #%d", total, Aegis._spell_debug_tick or 0))
  imgui.separator()

  for i = 0, total - 1 do
    local raw = ((head - 1 - i) % total) + 1
    local e = log[raw]
    if e then
      local col = COL_SKIP
      if e.result == "SUCCESS" or e.result == "QUEUED" then
        col = COL_SUCCESS
      elseif e.result and e.result:find("FAIL") then
        col = COL_FAIL
      end

      local parts = {}
      parts[#parts + 1] = string.format("[%s]", e.result or "?")
      parts[#parts + 1] = string.format("%s (%d)", e.spell or "?", e.id or 0)

      if e.target and e.target ~= "" then
        parts[#parts + 1] = "-> " .. e.target
      end
      if e.target_hp then
        parts[#parts + 1] = string.format("%.0f%%", e.target_hp)
      end
      if e.target_dist then
        parts[#parts + 1] = string.format("%.1fyd", e.target_dist)
      end
      if e.reason and e.reason ~= "" then
        parts[#parts + 1] = "| " .. e.reason
      end

      imgui.text_colored(col[1], col[2], col[3], col[4], table.concat(parts, "  "))

      if e.detail and e.detail ~= "" then
        imgui.text_colored(COL_DETAIL[1], COL_DETAIL[2], COL_DETAIL[3], COL_DETAIL[4],
          "    " .. e.detail)
      end
    end
  end

  imgui.end_window()
end

return Spell
