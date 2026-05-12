---@class Interrupts
---@field IsWhitelisted fun(spell_id: number, spell_name: string): boolean
---@field ActiveCast fun(unit: Unit): table|nil
---@field Metadata fun(spell_id: number, spell_name: string): table|nil
local Interrupts = {}

local function interrupt_data()
  local ok, data = pcall(require, "data.interrupts")
  return ok and type(data) == "table" and data or {}
end

local _index_source = nil
local _index_ids = nil
local _index_names = nil

local function normalize_name(name)
  name = tostring(name or ""):lower()
  name = name:gsub("[%s%p]+", " ")
  name = name:gsub("^%s+", ""):gsub("%s+$", "")
  return name
end

local function build_indexes(data)
  local ids, names = {}, {}

  local function add_record(record)
    if type(record) ~= "table" then return end
    for _, id in ipairs(record.ids or {}) do
      id = tonumber(id)
      if id and id > 0 then ids[id] = record end
    end
    for _, name in ipairs(record.names or {}) do
      local key = normalize_name(name)
      if key ~= "" then names[key] = record end
    end
  end

  for _, value in pairs(data or {}) do
    if type(value) == "number" then
      ids[value] = { ids = { value }, priority = 50, tags = { "legacy" } }
    end
  end
  for _, record in ipairs(data.EncounterInterrupts or {}) do
    add_record(record)
  end

  return ids, names
end

local function interrupt_metadata(spell_id, spell_name)
  spell_id = tonumber(spell_id) or 0
  local data = interrupt_data()
  if data ~= _index_source then
    _index_ids, _index_names = build_indexes(data)
    _index_source = data
  end
  if spell_id > 0 and _index_ids[spell_id] then return _index_ids[spell_id] end
  local key = normalize_name(spell_name)
  if key ~= "" and _index_names[key] then return _index_names[key] end
  return nil
end

local function is_whitelisted(spell_id, spell_name)
  return interrupt_metadata(spell_id, spell_name) ~= nil
end

local function tag_score(record)
  if not record then return 0 end
  if record.priority then return tonumber(record.priority) or 0 end
  local score = 0
  for _, tag in ipairs(record.tags or {}) do
    if tag == "wipe" then score = math.max(score, 100) end
    if tag == "mind_control" then score = math.max(score, 95) end
    if tag == "heal" then score = math.max(score, 90) end
    if tag == "summon" then score = math.max(score, 80) end
    if tag == "aoe" then score = math.max(score, 70) end
  end
  return score
end

local function active_cast(unit)
  if not unit or unit.IsDead then return nil end

  if unit.obj_ptr then
    local ok_cast, cast = pcall(game.unit_casting_info, unit.obj_ptr)
    if ok_cast and cast then
      if cast.not_interruptible then return nil end
      return {
        spell_id = cast.spell_id or 0,
        spell_name = cast.spell_name or "",
        info = cast,
        channel = false,
      }
    end

    local ok_chan, chan = pcall(game.unit_channel_info, unit.obj_ptr)
    if ok_chan and chan then
      if chan.not_interruptible then return nil end
      return {
        spell_id = chan.spell_id or 0,
        spell_name = chan.spell_name or "",
        info = chan,
        channel = true,
      }
    end
  end

  if unit.IsCasting then
    return {
      spell_id = unit.CastingSpellId or 0,
      spell_name = unit.CastingSpellName or "",
      info = nil,
      channel = false,
    }
  end

  if unit.IsChanneling then
    return {
      spell_id = unit.ChannelingSpellId or 0,
      spell_name = unit.ChannelingSpellName or "",
      info = nil,
      channel = true,
    }
  end

  return nil
end

local function should_interrupt(cast)
  if not cast then return false end
  if not AegisSettings or not AegisSettings.AegisInterruptTiming then return true end

  local info = cast.info
  if not info then return true end
  local now = os.clock() * 1000

  if info.cast_start and info.cast_end then
    local duration = info.cast_end - info.cast_start
    if duration <= 0 then return true end
    local remaining = info.cast_end - now
    local remaining_pct = (remaining / duration) * 100
    return remaining_pct <= (AegisSettings.AegisInterruptPercentage or 80)
  end

  if info.channel_start then
    local elapsed = now - info.channel_start
    local delay = 700 + (math.random() * 800 - 400)
    return elapsed > delay
  end

  return true
end

local function unit_distance(unit)
  if not Me or not Me.GetDistance or not unit then return math.huge end
  local ok, dist = pcall(Me.GetDistance, Me, unit)
  return ok and dist or math.huge
end

local function target_in_range(unit, range)
  if not Me or not unit then return false end
  if Me.InMeleeRange and Me:InMeleeRange(unit) then return true end
  return unit_distance(unit) <= (range or 5)
end

local function los_ok(unit, los_check)
  if los_check == false then return true end
  if not Me or not Me.obj_ptr or not unit or not unit.obj_ptr then return true end
  local ok, visible = pcall(game.is_visible, Me.obj_ptr, unit.obj_ptr, 0x03)
  return not ok or visible ~= false
end

local function facing_ok(unit, range)
  if not Me or not unit then return true end
  if Me.InMeleeRange and Me:InMeleeRange(unit) then return true end
  if not Me.obj_ptr or not unit.obj_ptr then return true end
  local ok, facing = pcall(game.is_facing, Me.obj_ptr, unit.obj_ptr)
  return not ok or facing ~= false
end

function Interrupts.FindTarget(options)
  options = options or {}
  local mode = AegisSettings and AegisSettings.AegisInterruptMode or 0
  if mode == 2 then return nil end

  local range = options.customRange or options.range or 5
  local players_only = options.playersOnly or false
  local los_check = options.losCheck ~= false
  local facing_check = options.facingCheck ~= false
  local current_guid = Me and Me.Target and not Me.Target.IsDead and Me.Target.Guid or nil
  local targets = Combat and Combat.Targets or {}
  local best, best_priority = nil, math.huge

  for _, unit in ipairs(targets) do
    repeat
      if not unit or unit.IsDead then break end
      if players_only and not unit.IsPlayer then break end

      local cast = active_cast(unit)
      if not cast then break end
      local metadata = interrupt_metadata(cast.spell_id, cast.spell_name)
      if mode == 1 and not metadata then break end
      if not target_in_range(unit, range) then break end
      if not los_ok(unit, los_check) then break end
      if facing_check and not facing_ok(unit, range) then break end
      if not should_interrupt(cast) then break end

      local dist = unit_distance(unit)
      local priority = dist - tag_score(metadata)
      if current_guid and unit.Guid == current_guid then priority = priority - 1000 end
      if priority < best_priority then
        best = unit
        best_priority = priority
      end
    until true
  end

  return best
end

function Interrupts.Cast(spell, options)
  if not spell or not spell.IsReady or not spell:IsReady() then return false end
  local target = Interrupts.FindTarget(options)
  if not target then return false end
  return spell:CastEx(target)
end

function Interrupts.CastAoE(spell, options)
  if not spell or not spell.IsReady or not spell:IsReady() then return false end
  options = options or {}
  local target = Interrupts.FindTarget({
    customRange = options.customRange or options.range or 8,
    range = options.range or options.customRange or 8,
    losCheck = options.losCheck,
    playersOnly = options.playersOnly,
    facingCheck = false,
  })
  if not target then return false end
  return spell:CastEx(Me, { skipUsable = true, skipFacing = true })
end

Interrupts.IsWhitelisted = is_whitelisted
Interrupts.ActiveCast = active_cast
Interrupts.Metadata = interrupt_metadata

return Interrupts
