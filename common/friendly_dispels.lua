---@class FriendlyDispels
local FriendlyDispels = {}

local MAGIC = 1
local CURSE = 2
local DISEASE = 3
local POISON = 4

local CLASS_CAPS = {
  [2] = {
    [MAGIC] = { { key = "Cleanse", ids = { 4987 } } },
    [POISON] = { { key = "Cleanse", ids = { 4987 } }, { key = "Purify", ids = { 1152 } } },
    [DISEASE] = { { key = "Cleanse", ids = { 4987 } }, { key = "Purify", ids = { 1152 } } },
  },
  [5] = {
    [MAGIC] = { { key = "DispelMagic", ids = { 988, 527 } } },
    [DISEASE] = { { key = "AbolishDisease", ids = { 552 } }, { key = "CureDisease", ids = { 528 } } },
  },
  [7] = {
    [POISON] = { { key = "CurePoison", ids = { 526 } } },
    [DISEASE] = { { key = "CureDisease", ids = { 2870 } } },
  },
  [8] = {
    [CURSE] = { { key = "RemoveLesserCurse", ids = { 475 } } },
  },
  [11] = {
    [CURSE] = { { key = "RemoveCurse", ids = { 2782 } } },
    [POISON] = { { key = "AbolishPoison", ids = { 2893 } }, { key = "CurePoison", ids = { 8946 } } },
  },
}

local _index_source = nil
local _allow_ids, _allow_names = nil, nil
local _blocked_ids, _blocked_names = nil, nil

local function dispel_data()
  local ok, data = pcall(require, "data.friendly_dispels_tbc")
  return ok and type(data) == "table" and data or {}
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

local function build_indexes(data)
  local allow_ids, allow_names = {}, {}
  local blocked_ids, blocked_names = {}, {}
  for _, record in ipairs(data.FriendlyDispels or {}) do
    add_record(allow_ids, allow_names, record)
  end
  for _, record in ipairs(data.BlockedDispels or {}) do
    add_record(blocked_ids, blocked_names, record)
  end
  return allow_ids, allow_names, blocked_ids, blocked_names
end

local function ensure_indexes()
  local data = dispel_data()
  if data ~= _index_source then
    _allow_ids, _allow_names, _blocked_ids, _blocked_names = build_indexes(data)
    _index_source = data
  end
end

local function aura_id(aura)
  return tonumber(aura and (aura.spell_id or aura.spellId or aura.id or aura.Id)) or 0
end

local function aura_name(aura)
  return aura and (aura.name or aura.spell_name or aura.Name or aura.SpellName) or ""
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

local function record_has_type(record, dtype)
  if not record then return false end
  if not record.types or #record.types == 0 then return true end
  for _, t in ipairs(record.types) do
    if tonumber(t) == tonumber(dtype) then return true end
  end
  return false
end

local function lookup(index_ids, index_names, aura)
  local sid = aura_id(aura)
  if sid > 0 and index_ids[sid] then return index_ids[sid] end
  local key = normalize_name(aura_name(aura))
  if key ~= "" then return index_names[key] end
  return nil
end

local function is_harmful(aura)
  if not aura then return false end
  if aura.is_harmful == false or aura.IsHarmful == false then return false end
  if aura.is_helpful == true or aura.IsHelpful == true then return false end
  return aura.is_harmful == true or aura.IsHarmful == true or lookup(_allow_ids, _allow_names, aura) ~= nil
end

local function unit_alive(unit)
  return unit and not unit.IsDead
end

local function unit_guid(unit)
  return unit and (unit.Guid or unit.guid or unit.GUID) or nil
end

local function contains_guid(list, guid)
  if not guid then return false end
  for _, unit in ipairs(list or {}) do
    if unit_guid(unit) == guid then return true end
  end
  return false
end

local function friends()
  local out, seen = {}, {}
  local function add(unit)
    if not unit_alive(unit) then return end
    local guid = unit_guid(unit)
    if guid and seen[guid] then return end
    if guid then seen[guid] = true end
    out[#out + 1] = unit
  end

  if Heal and Heal.Friends then
    for _, unit in ipairs(Heal.Friends.All or {}) do add(unit) end
  end
  add(Me)
  return out
end

local function role_bonus(unit)
  local guid = unit_guid(unit)
  local score = 0
  if unit and unit.IsTank then
    local ok, is_tank = pcall(unit.IsTank, unit)
    if ok and is_tank then score = score + 30 end
  end
  if Heal and Heal.Friends then
    if contains_guid(Heal.Friends.Tanks or {}, guid) then score = score + 30 end
    if contains_guid(Heal.Friends.Healers or {}, guid) then score = score + 15 end
  end
  return score
end

local function health_bonus(unit)
  local hp = tonumber(unit and unit.HealthPct) or 100
  if hp >= 100 then return 0 end
  return math.floor((100 - hp) / 5)
end

local function class_caps()
  local class_id = tonumber(Me and Me.ClassId) or 0
  return CLASS_CAPS[class_id] or {}
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

function FriendlyDispels.Metadata(spell_id, spell_name)
  ensure_indexes()
  local aura = { spell_id = spell_id, name = spell_name }
  return lookup(_allow_ids, _allow_names, aura)
end

function FriendlyDispels.Blocked(spell_id, spell_name)
  ensure_indexes()
  local aura = { spell_id = spell_id, name = spell_name }
  return lookup(_blocked_ids, _blocked_names, aura)
end

function FriendlyDispels.CanRemoveType(dispel_type)
  dispel_type = tonumber(dispel_type) or 0
  return class_caps()[dispel_type] ~= nil
end

function FriendlyDispels.Find()
  ensure_indexes()
  local caps = class_caps()
  local best = nil

  for _, unit in ipairs(friends()) do
    for _, aura in ipairs(unit.Auras or {}) do
      repeat
        if not is_harmful(aura) then break end
        local dtype = aura_dispel_type(aura)
        if dtype == 0 or not caps[dtype] then break end

        local blocked = lookup(_blocked_ids, _blocked_names, aura)
        if blocked and record_has_type(blocked, dtype) then break end

        local record = lookup(_allow_ids, _allow_names, aura)
        if not record or not record_has_type(record, dtype) then break end

        local score = (tonumber(record.priority) or 50) + role_bonus(unit) + health_bonus(unit)
        if not best or score > best.score then
          best = {
            unit = unit,
            aura = aura,
            dispel_type = dtype,
            record = record,
            score = score,
          }
        end
      until true
    end
  end

  return best
end

function FriendlyDispels.Try(prefix)
  if not AegisSettings or not AegisSettings[(prefix or "") .. "UseEncounterDispels"] then return false end
  if not Me or (Me.IsDead == true) then return false end
  local found = FriendlyDispels.Find()
  if not found then return false end

  for _, spec in ipairs(class_caps()[found.dispel_type] or {}) do
    local s = spell_ready(spec)
    if s and s.CastEx and s:CastEx(found.unit) then return true end
  end

  return false
end

FriendlyDispels.DispelTypes = {
  Magic = MAGIC,
  Curse = CURSE,
  Disease = DISEASE,
  Poison = POISON,
}
FriendlyDispels.CLASS_CAPS = CLASS_CAPS

return FriendlyDispels
