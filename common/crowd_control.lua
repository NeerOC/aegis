---@class CrowdControl
local CrowdControl = {}

local include_file = (Aegis and Aegis.include) or include
local DATA = include_file and include_file("data/cc_tbc.lua") or {}
local AuraCC = nil
do
  local ok, mod = pcall(require, "data.CrowdControl")
  if ok and type(mod) == "table" then AuraCC = mod end
end

local ACTIONS = DATA.Actions or {
  Polymorph = "polymorph",
  Sap = "sap",
  FreezingTrap = "freezing_trap",
  Banish = "banish",
  Fear = "fear",
  Seduce = "seduce",
  Shackle = "shackle",
  Hibernate = "hibernate",
  TurnEvil = "turn_evil",
}
local CREATURE_TYPES = DATA.CreatureTypes or {
  Beast = 1,
  Dragonkin = 2,
  Demon = 3,
  Elemental = 4,
  Undead = 6,
  Humanoid = 7,
}

local CLASS_ACTIONS = {
  [2] = {
    [ACTIONS.TurnEvil] = { { key = "TurnEvil", ids = { 10326, 5627, 2878 } } },
  },
  [3] = {
    [ACTIONS.FreezingTrap] = { { key = "FreezingTrap", ids = { 14311, 14310, 1499 }, self_cast = true } },
  },
  [4] = {
    [ACTIONS.Sap] = { { key = "Sap", ids = { 11297, 2070, 6770 }, require_stealth = true, require_ooc_target = true } },
  },
  [5] = {
    [ACTIONS.Shackle] = { { key = "ShackleUndead", ids = { 10955, 9485, 9484 } } },
  },
  [8] = {
    [ACTIONS.Polymorph] = { { key = "Polymorph", ids = { 12826, 12825, 12824, 118, 28272, 28271 } } },
  },
  [9] = {
    [ACTIONS.Banish] = { { key = "Banish", ids = { 18647, 710 } } },
    [ACTIONS.Fear] = { { key = "Fear", ids = { 6215, 6213, 5782 } } },
    [ACTIONS.Seduce] = { { key = "Seduction", pet_action = true } },
  },
  [11] = {
    [ACTIONS.Hibernate] = { { key = "Hibernate", ids = { 18658, 18657, 2637 } } },
  },
}

local _candidate_ids, _candidate_names = nil, nil
local _blocked_ids, _blocked_names = nil, nil
local _add_ids, _add_names = nil, nil
local _last_cast_at = {}

local function normalize_name(name)
  name = tostring(name or ""):lower()
  name = name:gsub("[%s%p]+", " ")
  name = name:gsub("^%s+", ""):gsub("%s+$", "")
  return name
end

local function add_record(ids, names, record)
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

local function ensure_indexes()
  if _candidate_ids then return end
  _candidate_ids, _candidate_names = {}, {}
  _blocked_ids, _blocked_names = {}, {}
  _add_ids, _add_names = {}, {}
  for _, record in ipairs(DATA.Candidates or {}) do add_record(_candidate_ids, _candidate_names, record) end
  for _, record in ipairs(DATA.Blocked or {}) do add_record(_blocked_ids, _blocked_names, record) end
  for _, record in ipairs(DATA.AddPriority or {}) do add_record(_add_ids, _add_names, record) end
end

local function unit_guid(unit)
  return unit and (unit.Guid or unit.guid or unit.GUID) or nil
end

local function unit_name(unit)
  return unit and (unit.Name or unit.name) or ""
end

local function unit_id(unit)
  if not unit then return 0 end
  if unit.NPCID then
    local ok, id = pcall(unit.NPCID, unit)
    if ok and tonumber(id) then return tonumber(id) or 0 end
  end
  return tonumber(unit.NPCId or unit.EntryId or unit.entry_id) or 0
end

local function lookup(ids, names, unit)
  ensure_indexes()
  local id = unit_id(unit)
  if id > 0 and ids[id] then return ids[id] end
  local key = normalize_name(unit_name(unit))
  if key ~= "" then return names[key] end
  return nil
end

local function creature_type(unit)
  local value = tonumber(unit and (unit.CreatureType or unit.creature_type)) or 0
  if value <= 0 and unit and unit._data then
    value = tonumber(unit._data.creature_type) or 0
  end
  return value
end

local function creature_type_name(unit)
  local name = unit and (unit.CreatureTypeName or unit.creature_type_name) or ""
  if (not name or name == "") and unit and unit._data then
    name = unit._data.creature_type_name or ""
  end
  return normalize_name(name)
end

local function creature_allowed(record, unit)
  local allowed = record and record.creature_types
  if not allowed or #allowed == 0 then return true end
  local actual = creature_type(unit)
  for _, candidate in ipairs(allowed) do
    if actual > 0 and actual == tonumber(candidate) then return true end
  end

  local cname = creature_type_name(unit)
  if cname ~= "" then
    for _, candidate in ipairs(allowed) do
      for label, id in pairs(CREATURE_TYPES) do
        if tonumber(candidate) == id and normalize_name(label) == cname then return true end
      end
    end
  end
  return false
end

local function unit_has_cc(unit)
  if not unit then return false end
  if AuraCC and AuraCC.UnitHasAnyCC and AuraCC.UnitHasAnyCC(unit) then return true end
  for _, aura in ipairs(unit.Auras or {}) do
    local name = normalize_name(aura and (aura.name or aura.spell_name or aura.Name))
    if name ~= "" and (
          name:find("polymorph", 1, true)
          or name:find("shackle", 1, true)
          or name:find("hibernate", 1, true)
          or name == "banish"
          or name == "fear"
          or name == "seduction"
          or name:find("freezing trap", 1, true)) then
      return true
    end
  end
  return false
end

local function add_target(out, seen, unit)
  if not unit or unit.IsDead then return end
  local guid = unit_guid(unit)
  if guid and seen[guid] then return end
  if guid then seen[guid] = true end
  out[#out + 1] = unit
end

local function target_candidates(options)
  local out, seen = {}, {}
  options = options or {}
  for _, unit in ipairs(options.targets or {}) do add_target(out, seen, unit) end
  add_target(out, seen, Me and Me.Target)
  add_target(out, seen, Me and Me.Focus)
  add_target(out, seen, Combat and Combat.BestTarget)
  for _, unit in ipairs(Combat and Combat.Targets or {}) do add_target(out, seen, unit) end
  if Aegis and Aegis._entity_cache and Unit and Unit.New then
    for _, entity in ipairs(Aegis._entity_cache) do
      local unit = Unit:New(entity)
      if unit then add_target(out, seen, unit) end
    end
  end
  return out
end

local function target_distance(unit)
  if not Me or not Me.GetDistance or not unit then return math.huge end
  local ok, dist = pcall(Me.GetDistance, Me, unit)
  return ok and (tonumber(dist) or math.huge) or math.huge
end

local function record_allows_action(record, action)
  for _, candidate in ipairs(record and record.actions or {}) do
    if candidate == action then return true end
  end
  return false
end

local function class_actions()
  return CLASS_ACTIONS[tonumber(Me and Me.ClassId) or 0] or {}
end

local function first_action(record, actions)
  local order = {
    ACTIONS.Polymorph, ACTIONS.Shackle, ACTIONS.Banish, ACTIONS.Hibernate,
    ACTIONS.TurnEvil, ACTIONS.Sap, ACTIONS.Seduce, ACTIONS.Fear, ACTIONS.FreezingTrap,
  }
  for _, action in ipairs(order) do
    if actions[action] and record_allows_action(record, action) then return action end
  end
  return nil
end

local function spell_ready(spec)
  if not spec then return nil end
  if Spell and Spell.ById then
    for _, id in ipairs(spec.ids or {}) do
      local s = Spell:ById(id)
      if s and s.IsKnown and (not s.IsReady or s:IsReady()) then return s end
    end
  end
  local fallback = Spell and spec.key and Spell[spec.key] or nil
  if fallback and fallback.IsKnown and (not fallback.IsReady or fallback:IsReady()) then return fallback end
  return nil
end

local function spec_allowed(spec, unit)
  if spec.require_stealth and not (Me and Me.IsStealthed) then return false end
  if spec.require_ooc_target and unit and unit.InCombat then return false end
  return true
end

local function throttle_ready(prefix, interval)
  prefix = prefix or "CrowdControl"
  interval = interval or 4.0
  local now = os.clock()
  return not _last_cast_at[prefix] or now - _last_cast_at[prefix] >= interval
end

local function target_score(unit, record)
  local score = tonumber(record and record.priority) or 50
  if Encounter and Encounter.IsImportantTrash and Encounter.IsImportantTrash(unit) then score = score + 20 end
  if Me and Me.Target and unit_guid(unit) == unit_guid(Me.Target) then score = score + 10 end
  local dist = target_distance(unit)
  if dist < math.huge then score = score - math.floor(dist / 5) end
  return score
end

function CrowdControl.Metadata(unit_or_id_or_name)
  ensure_indexes()
  if type(unit_or_id_or_name) == "number" then return _candidate_ids[unit_or_id_or_name] end
  if type(unit_or_id_or_name) == "string" then return _candidate_names[normalize_name(unit_or_id_or_name)] end
  return lookup(_candidate_ids, _candidate_names, unit_or_id_or_name)
end

function CrowdControl.Blocked(unit_or_id_or_name)
  ensure_indexes()
  if type(unit_or_id_or_name) == "number" then return _blocked_ids[unit_or_id_or_name] end
  if type(unit_or_id_or_name) == "string" then return _blocked_names[normalize_name(unit_or_id_or_name)] end
  return lookup(_blocked_ids, _blocked_names, unit_or_id_or_name)
end

function CrowdControl.Find(options)
  ensure_indexes()
  options = options or {}
  local actions = class_actions()
  local max_range = tonumber(options.range or options.max_range) or 30
  local allow_guarded = options.allow_guarded == true
  local allow_manual = options.allow_manual == true
  local best = nil

  for _, unit in ipairs(target_candidates(options)) do
    repeat
      if unit.IsPlayer or unit.is_player then break end
      if Encounter and Encounter.IsBoss and Encounter.IsBoss(unit) then break end
      if target_distance(unit) > max_range then break end
      if unit_has_cc(unit) then break end
      if lookup(_blocked_ids, _blocked_names, unit) then break end

      local record = lookup(_candidate_ids, _candidate_names, unit)
      if not record then break end
      if record.manual_only and not allow_manual then break end
      if record.guarded and not allow_guarded then break end
      if not creature_allowed(record, unit) then break end

      local action = first_action(record, actions)
      if not action then break end
      local score = target_score(unit, record)
      if not best or score > best.score then
        best = { unit = unit, record = record, action = action, score = score }
      end
    until true
  end

  return best
end

function CrowdControl.Try(prefix, options)
  options = options or {}
  if not AegisSettings or not AegisSettings[(prefix or "") .. "UseCrowdControl"] then return false end
  if not Me or Me.IsDead then return false end
  if not throttle_ready(prefix, options.min_interval or 4.0) then return false end

  local found = CrowdControl.Find(options)
  if not found then return false end

  for _, spec in ipairs(class_actions()[found.action] or {}) do
    repeat
      if not spec_allowed(spec, found.unit) then break end
      if spec.self_cast and not options.allow_self_cast_cc then break end
      if spec.pet_action then
        if Pet and Pet.CastAction and (not Pet.IsActionReady or Pet.IsActionReady(spec.key)) then
          if found.unit and found.unit.obj_ptr and Me and Me.SetTarget then
            pcall(Me.SetTarget, Me, found.unit)
          end
          if Pet.CastAction(spec.key) then
            _last_cast_at[prefix or "CrowdControl"] = os.clock()
            return true
          end
        end
        break
      end
      local spell = spell_ready(spec)
      if not spell or not spell.CastEx then break end
      local target = spec.self_cast and Me or found.unit
      if spell:CastEx(target) then
        _last_cast_at[prefix or "CrowdControl"] = os.clock()
        return true
      end
    until true
  end

  return false
end

function CrowdControl.FindAddPriority(options)
  ensure_indexes()
  options = options or {}
  local max_range = tonumber(options.range or options.max_range) or 40
  local best = nil
  for _, unit in ipairs(target_candidates(options)) do
    repeat
      if unit.IsDead then break end
      if target_distance(unit) > max_range then break end
      local record = lookup(_add_ids, _add_names, unit)
      if not record then break end
      local score = target_score(unit, record)
      if not best or score > best.score then
        best = { unit = unit, record = record, score = score }
      end
    until true
  end
  return best
end

function CrowdControl.BestAddTarget(options)
  local found = CrowdControl.FindAddPriority(options)
  return found and found.unit or nil
end

CrowdControl.Actions = ACTIONS
CrowdControl.CLASS_ACTIONS = CLASS_ACTIONS

return CrowdControl
