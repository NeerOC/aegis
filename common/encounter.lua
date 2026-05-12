-- Encounter identity helpers for TBC PvE content.

---@class Encounter
local Encounter = {}

local DATA = include("data/encounters_tbc.lua") or { instances = {} }

local by_id = {}
local by_name = {}

local function normalize_name(name)
  name = tostring(name or ""):lower()
  name = name:gsub("[%s%p]+", " ")
  name = name:gsub("^%s+", ""):gsub("%s+$", "")
  return name
end

local function add_identity(record, instance, role)
  if not record or not record.name then return end
  local entry = {
    name = record.name,
    ids = record.ids or {},
    role = record.role or role,
    tags = record.tags or {},
    instance = instance.name,
    instance_type = instance.type,
    modes = instance.modes or {},
  }

  by_name[normalize_name(record.name)] = entry
  for _, alias in ipairs(record.aliases or record.localized_names or {}) do
    by_name[normalize_name(alias)] = entry
  end
  for _, id in ipairs(record.ids or {}) do
    id = tonumber(id)
    if id and id > 0 then by_id[id] = entry end
  end
end

for _, instance in ipairs(DATA.instances or {}) do
  for _, record in ipairs(instance.bosses or {}) do
    add_identity(record, instance, "boss")
  end
  for _, record in ipairs(instance.important_trash or {}) do
    add_identity(record, instance, "trash")
  end
end

local function npc_id(unit)
  if not unit then return nil end
  if unit.NPCID then
    local ok, id = pcall(unit.NPCID, unit)
    if ok and tonumber(id) and tonumber(id) > 0 then return tonumber(id) end
  end
  local id = tonumber(unit.NPCId or unit.EntryId)
  if id and id > 0 then return id end
  return nil
end

function Encounter.Lookup(unit_or_id_or_name)
  local t = type(unit_or_id_or_name)
  if t == "number" then return by_id[unit_or_id_or_name] end
  if t == "string" then return by_name[normalize_name(unit_or_id_or_name)] end
  if t ~= "table" then return nil end

  local id = npc_id(unit_or_id_or_name)
  if id and by_id[id] then return by_id[id] end
  return by_name[normalize_name(unit_or_id_or_name.Name or unit_or_id_or_name.name)]
end

function Encounter.IsBoss(unit)
  local entry = Encounter.Lookup(unit)
  return entry and entry.role == "boss" or false
end

function Encounter.IsImportantTrash(unit)
  local entry = Encounter.Lookup(unit)
  return entry and entry.role == "trash" or false
end

function Encounter.UnitContext(unit)
  return Encounter.Lookup(unit)
end

function Encounter.CurrentContext()
  local candidates = {}

  if Me and Me.Target then candidates[#candidates + 1] = Me.Target end
  if Me and Me.Focus then candidates[#candidates + 1] = Me.Focus end
  if Combat and Combat.BestTarget then candidates[#candidates + 1] = Combat.BestTarget end
  if Tank and Tank.BestTarget then candidates[#candidates + 1] = Tank.BestTarget end
  if Combat and Combat.Targets then
    for _, unit in ipairs(Combat.Targets) do candidates[#candidates + 1] = unit end
  end

  for _, unit in ipairs(candidates) do
    local entry = Encounter.Lookup(unit)
    if entry then return entry, unit end
  end

  if Aegis and Aegis._entity_cache then
    for _, entity in ipairs(Aegis._entity_cache) do
      if entity and (entity.class == "Unit" or entity.class == "Player") then
        local unit = Unit and Unit.New and Unit:New(entity) or entity
        local entry = Encounter.Lookup(unit)
        if entry then return entry, unit end
      end
    end
  end

  return nil, nil
end

function Encounter.All()
  return DATA.instances or {}
end

Encounter._by_id = by_id
Encounter._by_name = by_name

return Encounter
