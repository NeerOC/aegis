---@class OffensiveDispels
local OffensiveDispels = {}

local ACTION_PURGE = "purge"
local ACTION_DISPEL = "dispel"
local ACTION_SPELLSTEAL = "spellsteal"
local MAGIC = 1

local CLASS_ACTIONS = {
  [5] = {
    [ACTION_DISPEL] = { { key = "DispelMagic", ids = { 988, 527 } } },
  },
  [7] = {
    [ACTION_PURGE] = { { key = "Purge", ids = { 8012, 370 } } },
  },
  [8] = {
    [ACTION_SPELLSTEAL] = { { key = "Spellsteal", ids = { 30449 } } },
  },
}

local _index_source = nil
local _allow_ids, _allow_names = nil, nil
local _blocked_ids, _blocked_names = nil, nil
local _last_cast_at = {}

local function data()
  local ok, result = pcall(require, "data.offensive_dispels_tbc")
  return ok and type(result) == "table" and result or {}
end

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

local function build_indexes(source)
  local allow_ids, allow_names = {}, {}
  local blocked_ids, blocked_names = {}, {}
  for _, record in ipairs(source.HostileDispels or {}) do
    add_record(allow_ids, allow_names, record)
  end
  for _, record in ipairs(source.BlockedDispels or {}) do
    add_record(blocked_ids, blocked_names, record)
  end
  return allow_ids, allow_names, blocked_ids, blocked_names
end

local function ensure_indexes()
  local source = data()
  if source ~= _index_source then
    _allow_ids, _allow_names, _blocked_ids, _blocked_names = build_indexes(source)
    _index_source = source
  end
end

local function aura_id(aura)
  return tonumber(aura and (aura.spell_id or aura.spellId or aura.id or aura.Id)) or 0
end

local function aura_name(aura)
  return aura and (aura.name or aura.spell_name or aura.Name or aura.SpellName) or ""
end

local function lookup(ids, names, aura)
  local sid = aura_id(aura)
  if sid > 0 and ids[sid] then return ids[sid] end
  local key = normalize_name(aura_name(aura))
  if key ~= "" then return names[key] end
  return nil
end

local function aura_dispel_type(aura)
  local dtype = tonumber(aura and (aura.dispel_type or aura.dispelType or aura.DispelType)) or 0
  local sid = aura_id(aura)
  if dtype == 0 and sid > 0 and game and game.spell_dispel_type then
    local ok, found = pcall(game.spell_dispel_type, sid)
    if ok then dtype = tonumber(found) or 0 end
  end
  return dtype
end

local function is_helpful_magic(aura)
  if not aura then return false end
  if aura.is_harmful == true or aura.IsHarmful == true then return false end
  if aura.is_helpful == false or aura.IsHelpful == false then return false end
  if aura.is_helpful == true or aura.IsHelpful == true then
    local dtype = aura_dispel_type(aura)
    return dtype == 0 or dtype == MAGIC or lookup(_allow_ids, _allow_names, aura) ~= nil
  end
  return lookup(_allow_ids, _allow_names, aura) ~= nil
end

local function record_allows_action(record, action)
  if not record or not action then return false end
  for _, candidate in ipairs(record.actions or {}) do
    if candidate == action then return true end
  end
  return false
end

local function unit_guid(unit)
  return unit and (unit.Guid or unit.guid or unit.GUID) or nil
end

local function add_target(out, seen, unit)
  if not unit or unit.IsDead then return end
  local guid = unit_guid(unit)
  if guid and seen[guid] then return end
  if guid then seen[guid] = true end
  out[#out + 1] = unit
end

local function target_candidates()
  local out, seen = {}, {}
  add_target(out, seen, Me and Me.Target)
  add_target(out, seen, Me and Me.Focus)
  add_target(out, seen, Combat and Combat.BestTarget)
  add_target(out, seen, Tank and Tank.BestTarget)
  for _, unit in ipairs(Combat and Combat.Targets or {}) do add_target(out, seen, unit) end
  for _, unit in ipairs(Tank and Tank.PriorityList or {}) do add_target(out, seen, unit) end
  if Aegis and Aegis._entity_cache and Unit and Unit.New and Encounter then
    for _, entity in ipairs(Aegis._entity_cache) do
      local unit = Unit:New(entity)
      if unit and (Encounter.IsBoss(unit) or Encounter.IsImportantTrash(unit)) then
        add_target(out, seen, unit)
      end
    end
  end
  return out
end

local function class_actions()
  return CLASS_ACTIONS[tonumber(Me and Me.ClassId) or 0] or {}
end

local function first_action(record, actions)
  local order = { ACTION_SPELLSTEAL, ACTION_PURGE, ACTION_DISPEL }
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

local function target_distance(unit)
  if not Me or not Me.GetDistance or not unit then return math.huge end
  local ok, dist = pcall(Me.GetDistance, Me, unit)
  return ok and (tonumber(dist) or math.huge) or math.huge
end

local function target_bonus(unit)
  local score = 0
  if Me and Me.Target and unit_guid(unit) == unit_guid(Me.Target) then score = score + 30 end
  if Combat and Combat.BestTarget and unit_guid(unit) == unit_guid(Combat.BestTarget) then score = score + 20 end
  if unit.IsBoss then
    local ok, is_boss = pcall(unit.IsBoss, unit)
    if ok and is_boss then score = score + 25 end
  end
  if Encounter and Encounter.IsImportantTrash and Encounter.IsImportantTrash(unit) then score = score + 15 end
  local dist = target_distance(unit)
  if dist < math.huge then score = score - math.floor(dist / 5) end
  return score
end

local function throttle_ready(prefix, interval)
  prefix = prefix or "OffensiveDispels"
  interval = interval or 2.0
  local now = os.clock()
  return not _last_cast_at[prefix] or now - _last_cast_at[prefix] >= interval
end

function OffensiveDispels.Metadata(spell_id, spell_name)
  ensure_indexes()
  local aura = { spell_id = spell_id, name = spell_name }
  return lookup(_allow_ids, _allow_names, aura)
end

function OffensiveDispels.Blocked(spell_id, spell_name)
  ensure_indexes()
  local aura = { spell_id = spell_id, name = spell_name }
  return lookup(_blocked_ids, _blocked_names, aura)
end

function OffensiveDispels.Find(options)
  ensure_indexes()
  options = options or {}
  local actions = class_actions()
  local best = nil
  local max_range = tonumber(options.range or options.max_range) or 30

  for _, unit in ipairs(options.targets or target_candidates()) do
    local dist = target_distance(unit)
    if dist <= max_range or dist == math.huge then
      for _, aura in ipairs(unit.Auras or {}) do
        repeat
          if not is_helpful_magic(aura) then break end
          if lookup(_blocked_ids, _blocked_names, aura) then break end
          local record = lookup(_allow_ids, _allow_names, aura)
          if not record then break end
          local action = first_action(record, actions)
          if not action then break end
          local score = (tonumber(record.priority) or 50) + target_bonus(unit)
          if not best or score > best.score then
            best = {
              unit = unit,
              aura = aura,
              record = record,
              action = action,
              score = score,
            }
          end
        until true
      end
    end
  end

  return best
end

function OffensiveDispels.Try(prefix, options)
  options = options or {}
  if not AegisSettings or not AegisSettings[(prefix or "") .. "UseOffensiveDispels"] then return false end
  if not Me or Me.IsDead then return false end
  if not throttle_ready(prefix, options.min_interval or 2.0) then return false end

  local found = OffensiveDispels.Find(options)
  if not found then return false end

  local spells = class_actions()[found.action] or {}
  for _, spec in ipairs(spells) do
    local spell = spell_ready(spec)
    if spell and spell.CastEx and spell:CastEx(found.unit) then
      _last_cast_at[prefix] = os.clock()
      return true
    end
  end

  return false
end

OffensiveDispels.Actions = {
  Purge = ACTION_PURGE,
  Dispel = ACTION_DISPEL,
  Spellsteal = ACTION_SPELLSTEAL,
}
OffensiveDispels.CLASS_ACTIONS = CLASS_ACTIONS

return OffensiveDispels
