---@meta

-- Unit wrapper — provides Aegis-style OOP methods over jmrMoP entity tables.

---@class Unit
---@field InCombat boolean
---@field Health number
---@field MaxHealth number
---@field HealthPct number
---@field Power number
---@field PowerType number
---@field Energy number
---@field MaxPower number
---@field PowerPct number
---@field Speed number
---@field Class string
---@field ClassId number
---@field Level number
---@field Name string
---@field Guid string
---@field Position table
---@field Facing number
---@field IsDead boolean
---@field IsPlayer boolean
---@field IsMounted boolean
---@field IsCasting boolean
---@field IsChanneling boolean
---@field Auras table
---@field obj_ptr userdata
---@field cgunit userdata
---@field Powers table<number, number> Key = power type index, Value = current amount
---@field MaxPowers table<number, number> Key = power type index, Value = max amount
---@field EntryId number Creature template / NPC entry id.
---@field guid_lo number Low 32 bits of the unit's GUID.
---@field guid_hi number High 32 bits of the unit's GUID.
---@field Race number
---@field UnitFlags number Raw UNIT_FIELD_FLAGS.
---@field UnitFlags3 number Raw UNIT_FIELD_FLAGS_3.
---@field DynamicFlags number Raw UNIT_DYNAMIC_FLAGS.
---@field Classification number 0 = normal, 1 = elite, 2 = rare, 3 = world boss, 4 = rare elite.
---@field ClassificationName string Friendly form of `Classification`.
---@field MountDisplayId number 0 when not mounted.
---@field CastingSpellId number
---@field CastingSpellName string
---@field ChannelingSpellId number
---@field ChannelingSpellName string
---@field CastTargetGuid string
---@field CastTargetName string
---@field CastStartMs number
---@field CastEndMs number
---@field CastDurationMs number
---@field BoundingRadius number
---@field CombatReach number
---@field SpecId number
---@field SpecName string
---@field CreatedByGuid string Owner GUID for pets/totems/etc.
---@field SummonedByGuid string Summoner GUID for guardian-type pets.
---@field Target Unit|nil Cached current target (only set on the local player; nil elsewhere).
---@field _is_lootable boolean Whether the unit currently has lootable status (mirrors entity.is_lootable).
---@field _data table|nil Optional creature metadata attached by external scanners (e.g., creature_type / is_boss).
local Unit = {}
Unit.__index = Unit

-- Filter expired auras out of the OM snapshot.
local function filter_live_auras(raw)
  if not raw or #raw == 0 then return raw end
  local now_ms
  if wow and wow.now_ms then
    local ok, v = pcall(wow.now_ms)
    if ok and v then now_ms = tonumber(v) end
  end
  if not now_ms then return raw end

  local out = {}
  for i = 1, #raw do
    local a = raw[i]
    local dur = tonumber(a.duration_ms) or 0
    local exp = tonumber(a.expire_ms) or 0
    if dur == 0 or exp == 0 or exp > now_ms then
      out[#out + 1] = a
    end
  end
  return out
end

function Unit:New(entity)
  if not entity then
    return nil
  end
  local u = entity.unit or {}
  local o = setmetatable({
    obj_ptr             = entity.obj_ptr,
    cgunit              = entity.cgunit,
    Guid                = entity.guid or "",
    guid_lo             = entity.guid_lo or 0,
    guid_hi             = entity.guid_hi or 0,
    Name                = entity.name or u.name or "",
    Position            = entity.position,
    Facing              = entity.facing or 0,
    EntryId             = entity.entry_id or 0,
    Class               = entity.class or "",

    Health              = u.health or 0,
    MaxHealth           = u.max_health or 1,
    Level               = u.level or 0,
    UnitFlags           = u.unit_flags or 0,
    Power               = u.power or 0,
    MaxPower            = u.max_power or 1,
    PowerType           = u.power_type or 0,
    Speed               = u.speed or 0,
    ClassId             = u.class_id or 0,
    Race                = u.race or 0,
    IsDead              = u.is_dead or false,
    IsPlayer            = u.is_player or false,
    InCombat            = u.in_combat or false,
    IsMounted           = u.is_mounted or false,
    MountDisplayId      = u.mount_display_id or 0,
    Classification      = u.classification or 0,
    ClassificationName  = u.classification_name or "normal",
    IsCasting           = u.is_casting or false,
    IsChanneling        = u.is_channeling or false,
    CastingSpellId      = u.casting_spell_id or 0,
    CastingSpellName    = u.casting_spell_name or "",
    ChannelingSpellId   = u.channeling_spell_id or 0,
    ChannelingSpellName = u.channeling_spell_name or "",
    CastTargetGuid      = entity.cast_target_guid or u.cast_target_guid or "",
    CastTargetName      = entity.cast_target_name or u.cast_target_name or "",
    CastEndMs           = entity.cast_end_ms or u.cast_end_ms or 0,
    CastStartMs         = entity.cast_start_ms or u.cast_start_ms or 0,
    CastDurationMs      = entity.cast_duration_ms or u.cast_duration_ms or 0,
    Auras               = filter_live_auras(u.auras or {}),

    BoundingRadius      = u.bounding_radius or 0,
    CombatReach         = u.combat_reach or 0,
    UnitFlags3          = u.unit_flags3 or 0,

    SpecId              = u.spec_id or 0,
    SpecName            = u.spec_name or "",

    Powers              = u.powers or {},
    MaxPowers           = u.max_powers or {},
    Energy              = u.powers and u.powers[2] or 0,
    CreatedByGuid       = entity.created_by_guid or u.created_by_guid or "",
    SummonedByGuid      = entity.summoned_by_guid or u.summoned_by_guid or "",

    DynamicFlags        = entity.dynamic_flags or u.dynamic_flags or 0,
    _is_lootable        = entity.is_lootable or u.is_lootable or false,
  }, Unit)

  o.HealthPct = o.MaxHealth > 0 and (o.Health / o.MaxHealth * 100) or 0
  o.PowerPct = o.MaxPower > 0 and (o.Power / o.MaxPower * 100) or 0
  return o
end

function Unit:IsCastingOrChanneling()
  if self.IsCasting or self.IsChanneling then
    return true
  end
  local token = self:_UnitToken()
  if token then
    local ok, cast = pcall(game.unit_casting_info, token)
    if ok and cast then
      return true
    end
    local ok2, chan = pcall(game.unit_channel_info, token)
    if ok2 and chan then
      return true
    end
  end
  return false
end

--- Resolve a WoW unit token ("player"/"target"/nil) for this unit.
function Unit:_UnitToken()
  if Me and self.Guid == Me.Guid then
    return "player"
  end
  local ok, tgt = pcall(game.target)
  if ok and tgt and tgt.guid == self.Guid then
    return "target"
  end
  return nil
end

--- Run fn(unit_token) with a token that resolves to this unit.
function Unit:WithToken(fn)
  local tok = self:_UnitToken()
  if tok then return fn(tok) end
  if wow and wow.with_mouseover then
    return wow.with_mouseover(self.Guid, fn)
  end
  return nil
end

--- Force a mouseover swap to address this unit.
function Unit:WithMouseover(fn)
  if not wow or not wow.with_mouseover then return nil end
  return wow.with_mouseover(self.Guid, fn)
end

--- Call a WoW Lua function with this unit's token as first arg.
function Unit:UnitCall(name, ...)
  if not wow or not wow.call_game_lua then return nil end
  local n = select("#", ...)
  local args = { ... }
  local unpack_ = table.unpack
  return self:WithToken(function(tok)
    return wow.call_game_lua(name, tok, unpack_(args, 1, n))
  end)
end

function Unit:DeadOrGhost()
  if self.IsDead then
    return true
  end
  local ok, result = pcall(game.unit_dead_or_ghost, self.obj_ptr)
  return ok and result or self.IsDead
end

---Missing power for the given slot. Defaults to slot 0 (active display
---power: mana / rage / energy / focus, matching `Power` / `MaxPower`).
---Returns max(0, max - current) so the result is never negative even if
---the unit briefly overflows its cap.
---@param power_type? number Power slot index (0 = primary, 2 = combo points, …).
---@return number
function Unit:PowerDeficit(power_type)
  power_type = power_type or 0
  if power_type == 0 then
    return math.max(0, (self.MaxPower or 0) - (self.Power or 0))
  end
  local maxp = self.MaxPowers and self.MaxPowers[power_type] or 0
  local curp = self.Powers and self.Powers[power_type] or 0
  return math.max(0, maxp - curp)
end

function Unit:CanAttack(other)
  if not other then
    return false
  end
  local ok, result = pcall(game.unit_can_attack, self.obj_ptr, other.obj_ptr)
  return ok and result or false
end

function Unit:IsAttackable()
  local ok, result = pcall(game.unit_is_attackable, self.obj_ptr)
  return ok and result or false
end

function Unit:IsEnemy(other)
  if other then
    local ok, result = pcall(game.unit_is_enemy, self.obj_ptr, other.obj_ptr)
    return ok and result or false
  end
  local ok, result = pcall(game.unit_is_enemy, self.obj_ptr)
  return ok and result or false
end

function Unit:IsFriend(other)
  if other then
    local ok, result = pcall(game.unit_is_friend, self.obj_ptr, other.obj_ptr)
    return ok and result or false
  end
  local ok, result = pcall(game.unit_is_friend, self.obj_ptr)
  return ok and result or false
end

function Unit:GetReaction(other)
  if not other then
    return 4
  end
  local ok, result = pcall(game.unit_reaction, self.obj_ptr, other.obj_ptr)
  return ok and result or 4
end

function Unit:GetDistance(other)
  if not other then
    return 999
  end

  local sp = self.Position
  local op = other.Position

  if not sp and self.obj_ptr then
    local ok, x, y, z = pcall(game.entity_position, self.obj_ptr)
    if ok and x then
      sp = { x = x, y = y, z = z }
      self.Position = sp
    end
  end
  if not op and other.obj_ptr then
    local ok, x, y, z = pcall(game.entity_position, other.obj_ptr)
    if ok and x then
      op = { x = x, y = y, z = z }
      other.Position = op
    end
  end

  if not sp or not op then
    return -1
  end
  return game.distance(sp.x, sp.y, sp.z, op.x, op.y, op.z)
end

function Unit:InMeleeRange(other)
  if not other then
    return false
  end

  local d = self:GetDistance(other)
  if d < 0 then
    return true
  end

  if game.entity_bounds and other.obj_ptr then
    local ok, bounds = pcall(game.entity_bounds, other.obj_ptr)
    if ok and bounds then
      local melee_range = 5.0 + (bounds.width * 0.5)
      return d <= melee_range
    end
  end

  return d <= 5.0
end

function Unit:IsFacing(other, threshold)
  if not other then
    return false
  end
  local ok, result = pcall(game.is_facing, self.obj_ptr, other.obj_ptr, threshold)
  return ok and result or false
end

function Unit:HasAura(name_or_id)
  local auras = self.Auras
  if auras then
    local is_id = type(name_or_id) == "number"
    for i = 1, #auras do
      local a = auras[i]
      if is_id then
        if a.spell_id == name_or_id then
          return true
        end
      else
        if a.name == name_or_id then
          return true
        end
      end
    end
    return false
  end
  local ok, result = pcall(game.has_aura, self.obj_ptr, name_or_id)
  return ok and result or false
end

function Unit:GetAura(name_or_id)
  local ok, result = pcall(game.aura_info, self.obj_ptr, name_or_id)
  if ok and result then
    return result
  end
  return nil
end

function Unit:GetAuraByMe(name_or_id)
  local ok, result = pcall(game.aura_info, self.obj_ptr, name_or_id)
  if not ok or not result then
    return nil
  end
  if result.is_from_player then
    return result
  end
  return nil
end

function Unit:HasDebuffByMe(name_or_id)
  return self:GetAuraByMe(name_or_id) ~= nil
end

function Unit:HasVisibleAura(name_or_id)
  return self:HasAura(name_or_id)
end

function Unit:GetVisibleAura(name_or_id)
  return self:GetAura(name_or_id)
end

function Unit:HasBuffByMe(name_or_id)
  return self:GetAuraByMe(name_or_id) ~= nil
end

function Unit:Role()
  local ok, result = pcall(game.unit_role, self.obj_ptr)
  return ok and result or "NONE"
end

function Unit:IsTank()
  local ok, result = pcall(game.unit_is_tank, self.obj_ptr)
  return ok and result or false
end

function Unit:IsHealer()
  local ok, result = pcall(game.unit_is_healer, self.obj_ptr)
  return ok and result or false
end

function Unit:IsDPS()
  local ok, result = pcall(game.unit_is_dps, self.obj_ptr)
  return ok and result or false
end

function Unit:IsMoving()
  return self.Speed > 0.1
end

function Unit:IsElite()
  local c = self.Classification
  return c == 1 or c == 2 or c == 3
end

function Unit:IsRare()
  local c = self.Classification
  return c == 2 or c == 4
end

function Unit:IsWorldBoss()
  return self.Classification == 3
end

--- True if the unit is boss-level.
function Unit:IsBoss()
  local data = self._data
  if data and data.is_boss ~= nil then
    return data.is_boss
  end
  return self.Classification == 3
end

function Unit:IsLootable()
  return self._is_lootable
end

--- Check if this unit is interruptible.
function Unit:IsInterruptible()
  if not self:IsCastingOrChanneling() then
    return false
  end
  local token = self:_UnitToken()
  if token then
    local ok, cast = pcall(game.unit_casting_info, token)
    if ok and cast then
      return not cast.not_interruptible
    end
    local ok2, chan = pcall(game.unit_channel_info, token)
    if ok2 and chan then
      return not chan.not_interruptible
    end
  end
  return self.IsCasting or self.IsChanneling
end

function Unit:CastingInfo()
  if not self.obj_ptr then
    return nil, nil
  end
  local token = self:_UnitToken()
  if token then
    local ok, cast = pcall(game.unit_casting_info, token)
    local ok2, chan = pcall(game.unit_channel_info, token)
    return ok and cast or nil, ok2 and chan or nil
  end
  local cast = nil
  local chan = nil
  if self.IsCasting then
    cast = { spell_id = self.CastingSpellId, spell_name = self.CastingSpellName }
  end
  if self.IsChanneling then
    chan = { spell_id = self.ChannelingSpellId, spell_name = self.ChannelingSpellName }
  end
  return cast, chan
end

-- Resolve the unit's target (returns a Unit wrapper or nil).
function Unit:GetTarget()
  local tgt
  if Me and self.Guid == Me.Guid then
    local ok, t = pcall(game.target)
    if not ok or not t or not t.obj_ptr then
      return nil
    end
    tgt = t
  else
    local ok, t = pcall(game.unit_target, self.obj_ptr)
    if not ok or not t or not t.obj_ptr then
      return nil
    end
    tgt = t
  end

  local entities = Aegis and Aegis._entity_cache or {}
  for _, e in ipairs(entities) do
    if e.obj_ptr == tgt.obj_ptr then
      return Unit:New(e)
    end
  end

  return Unit:New(tgt)
end

-- Check if this unit is a valid target
function Unit:validTarget()
  if self.IsDead or self:DeadOrGhost() then
    return false
  end

  if Me and Me.CanAttack and not Me:CanAttack(self) then
    return false
  end

  return true
end

-- True if this enemy unit's target is the local player, pet, or a party/raid member.
function Unit:isUnitInCombatWithPartyOrMe()
  local target = self:GetTarget()
  if not target then return false end

  local t_lo = target.guid_lo or 0
  if t_lo == 0 then return false end

  if Me and Me.guid_lo and t_lo == Me.guid_lo then return true end

  if Pet and Pet.GetPrimary then
    local pet = Pet.GetPrimary()
    if pet and pet.guid_lo and pet.guid_lo ~= 0 and t_lo == pet.guid_lo then
      return true
    end
  end

  if not Me or not Me.InGroup or not Me:InGroup() then return false end

  local ok, roster = pcall(game.group_members)
  if not ok or not roster then return false end
  for _, m in ipairs(roster) do
    if m.guid_lo == t_lo then return true end
  end
  return false
end

-- True if another group has tapped this mob and we get no credit/loot.
function Unit:IsTapDenied()
  local r = self:UnitCall("UnitIsTapDenied")
  return r == true or r == 1
end

--- Get combo points the player has on this unit.
function Unit:GetComboPoints()
  local token = self:_UnitToken()
  local ok, cp = pcall(wow.call_game_lua, "GetComboPoints", "player", token)
  if ok and cp then
    return cp
  end
  return 0
end

--- Seconds until this unit dies (math.huge when no sample exists).
function Unit:TimeToDeath()
  if Combat and Combat.TimeToDeath then
    return Combat:TimeToDeath(self.Guid)
  end
  return math.huge
end

Unit.TimeToDie = Unit.TimeToDeath

Unit.Target = nil

return Unit
