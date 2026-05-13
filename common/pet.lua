-- Pet library for Aegis Core.

---@class Pet
Pet = Pet or {}

local PET_TOKEN = "pet"
local PET_TARGET_TOKEN = "pettarget"
local PET_ACTION_SLOTS = 10

local ACTION_TOKENS = {
  attack = {
    PET_ACTION_ATTACK = true,
    ATTACK = true,
  },
  follow = {
    PET_ACTION_FOLLOW = true,
    FOLLOW = true,
  },
  stay = {
    PET_ACTION_WAIT = true,
    PET_ACTION_STAY = true,
    STAY = true,
  },
  move_to = {
    PET_ACTION_MOVE_TO = true,
    PET_ACTION_MOVE = true,
  },
  assist = {
    PET_MODE_ASSIST = true,
    ASSIST = true,
  },
  defensive = {
    PET_MODE_DEFENSIVE = true,
    DEFENSIVE = true,
  },
  passive = {
    PET_MODE_PASSIVE = true,
    PASSIVE = true,
  },
  aggressive = {
    PET_MODE_AGGRESSIVE = true,
    AGGRESSIVE = true,
  },
}

local PetUnit = {}

local _info_cache = nil
local _info_cache_tick = -1
local _actions_cache = nil
local _actions_cache_tick = -1
local _primary_cache = nil
local _primary_cache_tick = -1
local _summons_cache = nil
local _summons_cache_tick = -1

local PET_DEBUG_MAX = 80

local function tick_key()
  return (Aegis and Aegis._spell_debug_tick) or 0
end

local function pet_debug_log(entry)
  if not AegisSettings or not AegisSettings.AegisSpellDebug then return end
  if not Aegis then return end

  entry.kind = "PET"
  entry.time = entry.time or os.clock()

  Aegis._spell_debug_log = Aegis._spell_debug_log or {}
  Aegis._spell_debug_idx = (Aegis._spell_debug_idx or 0) + 1
  entry.time_real = os.time()
  entry.tick = Aegis._spell_debug_tick
  local idx = ((Aegis._spell_debug_idx - 1) % PET_DEBUG_MAX) + 1
  Aegis._spell_debug_log[idx] = entry
end

function Pet.DebugLog(entry)
  pet_debug_log(entry or {})
end

local function call_game_lua(name, ...)
  if not wow or type(wow.call_game_lua) ~= "function" then
    return nil
  end

  local ok, a, b, c, d, e, f, g, h = pcall(wow.call_game_lua, name, ...)
  if not ok then
    return nil
  end

  return a, b, c, d, e, f, g, h
end

local function eval_lua(expr)
  if not wow or type(wow.eval_lua) ~= "function" then
    return nil
  end

  local ok, result = pcall(wow.eval_lua, expr)
  if not ok then
    return nil
  end
  return result
end

local function run_lua(script)
  if not wow or type(wow.run_lua) ~= "function" then
    return false
  end

  local ok = pcall(wow.run_lua, script)
  return ok == true
end

local function run_pet_script(action, script, reason, target)
  local fired = run_lua(script)
  pet_debug_log({
    spell = "Pet " .. tostring(action or "Action"),
    action = action,
    target = target,
    result = fired and "SUCCESS" or "FAIL",
    reason = reason or "fallback script",
  })
  return fired
end

local function lua_bool(value)
  if value == true then return true end
  if type(value) == "number" then return value ~= 0 end
  if type(value) == "string" then
    local s = value:match("^%s*(.-)%s*$") or value
    local lower = s:lower()
    if lower == "" or lower == "0" or lower == "false" or lower == "nil" or lower == "off" or lower == "no" then
      return false
    end
    local n = tonumber(value)
    if n ~= nil then return n ~= 0 end
    return true
  end
  return false
end

local function raw_label(value)
  if type(value) == "string" then
    return string.format("%q<%s>", value, type(value))
  end
  return string.format("%s<%s>", tostring(value), type(value))
end

local function pet_action_autocast_enabled(slot)
  slot = tonumber(slot)
  if not slot then return nil end

  local expr = string.format([[
(function()
  local slot = %d
  if C_ActionBar and C_ActionBar.IsEnabledAutoCastPetAction then
    local ok, enabled = pcall(C_ActionBar.IsEnabledAutoCastPetAction, slot)
    if ok and enabled ~= nil then return enabled end
  end

  local button = _G["PetActionButton" .. slot]
  if button then
    local shine = button.shine or button.Shine or _G["PetActionButton" .. slot .. "Shine"]
    if shine then
      if shine.IsShown then return shine:IsShown() end
      if shine.IsVisible then return shine:IsVisible() end
    end
  end

  local shine = _G["PetActionButton" .. slot .. "Shine"] or
                _G["PetActionButton" .. slot .. "AutoCastShine"] or
                _G["PetActionButton" .. slot .. "AutoCast"]
  if shine then
    if shine.IsShown then return shine:IsShown() end
    if shine.IsVisible then return shine:IsVisible() end
  end

  return nil
end)()
]], slot)

  return eval_lua(expr)
end

local function bool_call(name, ...)
  local value = call_game_lua(name, ...)
  return lua_bool(value)
end

local function number_call(name, ...)
  local value = call_game_lua(name, ...)
  return tonumber(value) or 0
end

local function string_call(name, ...)
  local value = call_game_lua(name, ...)
  if type(value) == "string" then
    return value
  end
  return ""
end

local function norm(value)
  value = tostring(value or "")
  value = value:gsub("[%s_%-:()]+", "")
  return value:lower()
end

local function same_guid(a, b)
  if not a or not b or a == "" or b == "" then
    return false
  end
  return tostring(a):lower() == tostring(b):lower()
end

local function entity_guid(entity)
  if not entity then return "" end
  local unit = entity.unit or {}
  return entity.guid or unit.guid or ""
end

local function entity_name(entity)
  if not entity then return "" end
  local unit = entity.unit or {}
  return entity.name or unit.name or ""
end

local function entity_health(entity)
  local unit = entity and entity.unit or {}
  return tonumber(unit.health or entity.health) or 0
end

local function entity_max_health(entity)
  local unit = entity and entity.unit or {}
  return tonumber(unit.max_health or entity.max_health) or 0
end

local function entity_family(entity)
  local unit = entity and entity.unit or {}
  return entity and (entity.creature_family or unit.creature_family or
    entity.family or unit.family) or nil
end

local function owner_matches_player(entity)
  if not entity or not Me then return false end
  local unit = entity.unit or {}
  local player_guid = Me.Guid or ""

  if same_guid(entity.created_by_guid or unit.created_by_guid, player_guid) then
    return true
  end
  if same_guid(entity.summoned_by_guid or unit.summoned_by_guid, player_guid) then
    return true
  end
  if same_guid(entity.charmed_by_guid or unit.charmed_by_guid, player_guid) then
    return true
  end

  local plo = tonumber(Me.guid_lo) or 0
  local phi = tonumber(Me.guid_hi) or 0
  if plo ~= 0 or phi ~= 0 then
    local owner_lo = tonumber(entity.owner_guid_lo or unit.owner_guid_lo or
      entity.created_by_guid_lo or unit.created_by_guid_lo or
      entity.summoned_by_guid_lo or unit.summoned_by_guid_lo) or 0
    local owner_hi = tonumber(entity.owner_guid_hi or unit.owner_guid_hi or
      entity.created_by_guid_hi or unit.created_by_guid_hi or
      entity.summoned_by_guid_hi or unit.summoned_by_guid_hi) or 0
    return owner_lo == plo and owner_hi == phi
  end

  return false
end

local function unit_exists(token)
  return string_call("UnitGUID", token) ~= ""
end

local function read_unit_info(token)
  local guid = string_call("UnitGUID", token)
  if guid == "" then
    return { exists = false, token = token }
  end

  local name = string_call("UnitName", token)
  local health = number_call("UnitHealth", token)
  local max_health = number_call("UnitHealthMax", token)
  local power = number_call("UnitPower", token)
  local max_power = number_call("UnitPowerMax", token)
  local power_type, power_token = call_game_lua("UnitPowerType", token)

  local info = {
    exists = true,
    token = token,
    guid = guid,
    name = name,
    family = string_call("UnitCreatureFamily", token),
    health = health,
    max_health = max_health,
    health_pct = max_health > 0 and (health / max_health * 100) or 0,
    power = power,
    max_power = max_power,
    power_pct = max_power > 0 and (power / max_power * 100) or 0,
    power_type = tonumber(power_type) or 0,
    power_token = power_token or "",
    is_dead = bool_call("UnitIsDeadOrGhost", token) or bool_call("UnitIsDead", token),
    in_combat = bool_call("UnitAffectingCombat", token),
    is_connected = bool_call("UnitIsConnected", token),
  }

  return info
end

local function overlay_unit_fields(unit, info)
  if not unit or not info or not info.exists then
    return unit
  end

  unit.UnitToken = info.token
  -- Prefer the hex Guid set by Unit:New(entity). Only fall back to info.guid
  -- (WoW Lua "Creature-0-..." format) when no hex was available, so we never
  -- mix formats with the rest of the codebase.
  if not unit.Guid or unit.Guid == "" then
    unit.Guid = info.guid or ""
  end
  unit.Name = info.name or unit.Name or ""
  unit.Health = info.health or unit.Health or 0
  unit.MaxHealth = info.max_health or unit.MaxHealth or 1
  unit.HealthPct = info.health_pct or unit.HealthPct or 0
  unit.Power = info.power or unit.Power or 0
  unit.MaxPower = info.max_power or unit.MaxPower or 1
  unit.PowerPct = info.power_pct or unit.PowerPct or 0
  unit.PowerType = info.power_type or unit.PowerType or 0
  unit.PowerToken = info.power_token or unit.PowerToken or ""
  unit.CreatureFamily = info.family or unit.CreatureFamily or ""
  unit.IsDead = info.is_dead or unit.IsDead or false
  unit.InCombat = info.in_combat or unit.InCombat or false
  unit.IsConnected = info.is_connected
  unit.IsPet = true

  return unit
end

local function find_entity_for_token(info)
  if not info or not info.exists then
    return nil
  end

  local entities = Aegis and Aegis._entity_cache or {}
  for _, entity in ipairs(entities) do
    if same_guid(entity_guid(entity), info.guid) then
      return entity
    end
  end

  for _, entity in ipairs(entities) do
    if owner_matches_player(entity) then
      return entity
    end
  end

  if info.name and info.name ~= "" then
    for _, entity in ipairs(entities) do
      if entity_name(entity) == info.name then
        local eh = entity_health(entity)
        local emh = entity_max_health(entity)
        if (eh == 0 or eh == info.health) and (emh == 0 or emh == info.max_health) then
          return entity
        end
      end
    end
  end

  return nil
end

function PetUnit:_UnitToken()
  return self.UnitToken or PET_TOKEN
end

function PetUnit:DeadOrGhost()
  return bool_call("UnitIsDeadOrGhost", self:_UnitToken()) or self.IsDead
end

function PetUnit:GetTarget()
  return Pet.GetTarget()
end

function PetUnit:HasAura(name_or_id)
  if Unit and Unit.HasAura and self.obj_ptr then
    return Unit.HasAura(self, name_or_id)
  end

  local token = self:_UnitToken()
  local check
  if type(name_or_id) == "number" then
    check = "spellId == " .. tostring(name_or_id)
  else
    check = "name == " .. string.format("%q", tostring(name_or_id))
  end

  local expr = [[
(function()
  local unit = ]] .. string.format("%q", token) .. [[
  if not UnitExists(unit) then return false end
  for _, filter in ipairs({"HELPFUL", "HARMFUL"}) do
    for i = 1, 40 do
      local name, _, _, _, _, _, _, _, _, spellId = UnitAura(unit, i, filter)
      if not name then break end
      if ]] .. check .. [[ then return true end
    end
  end
  return false
end)()
]]

  return eval_lua(expr) == true
end

function PetUnit:GetAura(name_or_id)
  if Unit and Unit.GetAura and self.obj_ptr then
    return Unit.GetAura(self, name_or_id)
  end
  return self:HasAura(name_or_id) and { name = name_or_id } or nil
end

local function make_unit(token)
  local info = read_unit_info(token)
  if not info.exists then
    return nil
  end

  local entity = find_entity_for_token(info)
  local unit = nil
  if entity and Unit then
    unit = Unit:New(entity)
  end

  if not unit then
    unit = {
      obj_ptr = entity and entity.obj_ptr or nil,
      cgunit = entity and entity.cgunit or nil,
      Auras = {},
    }
  end

  overlay_unit_fields(unit, info)
  if entity then
    unit.CreatureFamilyId = entity_family(entity)
  end

  if Unit then
    setmetatable(unit, {
      __index = function(_, key)
        return PetUnit[key] or Unit[key]
      end,
    })
  else
    setmetatable(unit, { __index = PetUnit })
  end

  return unit
end

local function action_matches(action, key)
  if not action then return false end
  local tokens = ACTION_TOKENS[key]
  if tokens then
    if tokens[action.name or ""] then return true end
    if tokens[action.subtext or ""] then return true end
  end

  local wanted = norm(key)
  return norm(action.name) == wanted or norm(action.subtext) == wanted
end

local function read_action(slot)
  local name, subtext, texture, is_token, is_active, autocast_allowed, autocast_enabled =
      call_game_lua("GetPetActionInfo", slot)
  if not name then
    return nil
  end

  local start_time, duration, enabled = call_game_lua("GetPetActionCooldown", slot)
  local is_attack = bool_call("IsPetAttackAction", slot)
  local shine_enabled = pet_action_autocast_enabled(slot)
  local parsed_allowed = lua_bool(autocast_allowed) or autocast_enabled ~= nil
  local parsed_enabled = shine_enabled ~= nil and lua_bool(shine_enabled) or lua_bool(autocast_enabled)

  return {
    Slot = slot,
    slot = slot,
    Name = name,
    name = name,
    Subtext = subtext or "",
    subtext = subtext or "",
    Texture = texture,
    texture = texture,
    IsToken = lua_bool(is_token),
    is_token = lua_bool(is_token),
    IsActive = lua_bool(is_active),
    is_active = lua_bool(is_active),
    AutocastAllowed = parsed_allowed,
    autocast_allowed = parsed_allowed,
    AutocastEnabled = parsed_enabled,
    autocast_enabled = parsed_enabled,
    RawAutocastAllowed = autocast_allowed,
    raw_autocast_allowed = autocast_allowed,
    RawAutocastEnabled = autocast_enabled,
    raw_autocast_enabled = autocast_enabled,
    ShineAutocastEnabled = shine_enabled,
    shine_autocast_enabled = shine_enabled,
    CooldownStart = tonumber(start_time) or 0,
    cooldown_start = tonumber(start_time) or 0,
    CooldownDuration = tonumber(duration) or 0,
    cooldown_duration = tonumber(duration) or 0,
    CooldownEnabled = enabled == true or enabled == 1,
    cooldown_enabled = enabled == true or enabled == 1,
    IsAttack = is_attack,
    is_attack = is_attack,
  }
end

local function cast_action_slot(slot)
  slot = tonumber(slot)
  if not slot or slot < 1 or slot > PET_ACTION_SLOTS then
    pet_debug_log({
      spell = "Pet Action",
      action = "invalid_slot",
      slot = slot or 0,
      result = "FAIL",
      reason = "invalid slot",
    })
    return false
  end
  if not wow or type(wow.call_game_lua) ~= "function" then
    pet_debug_log({
      spell = "Pet Action",
      action = "CastPetAction",
      slot = slot,
      result = "FAIL",
      reason = "wow.call_game_lua unavailable",
    })
    return false
  end

  local action = Pet.GetActionInfo(slot)
  local ok, result = pcall(wow.call_game_lua, "CastPetAction", slot)
  if not ok then
    pet_debug_log({
      spell = action and action.name or "Pet Action",
      action = "CastPetAction",
      slot = slot,
      result = "FAIL",
      reason = tostring(result),
      detail = action and string.format("active=%s autocast=%s allowed=%s",
        tostring(action.is_active), tostring(action.autocast_enabled),
        tostring(action.autocast_allowed)) or "",
    })
    return false
  end

  local fired = result ~= nil
  pet_debug_log({
    spell = action and action.name or "Pet Action",
    action = "CastPetAction",
    slot = slot,
    result = fired and "SUCCESS" or "FAIL",
    reason = fired and "queued" or "no result",
    detail = action and string.format("active=%s autocast=%s allowed=%s shine=%s raw_auto=%s/%s raw=%s",
      tostring(action.is_active), tostring(action.autocast_enabled),
      tostring(action.autocast_allowed), raw_label(action.shine_autocast_enabled),
      raw_label(action.raw_autocast_allowed),
      raw_label(action.raw_autocast_enabled), raw_label(result)) or raw_label(result),
  })
  return fired
end

local function cast_action_key(key)
  local action = Pet.FindAction(key)
  if not action then
    pet_debug_log({
      spell = "Pet Action",
      action = tostring(key or ""),
      result = "SKIP",
      reason = "action not found",
    })
    return false
  end
  return cast_action_slot(action.slot)
end

function Pet.InvalidateCache()
  _info_cache = nil
  _actions_cache = nil
  _primary_cache = nil
  _summons_cache = nil
end

function Pet.HasPet()
  return unit_exists(PET_TOKEN)
end

function Pet.Info()
  local tick = tick_key()
  if _info_cache and _info_cache_tick == tick then
    return _info_cache
  end

  _info_cache = read_unit_info(PET_TOKEN)
  _info_cache_tick = tick
  return _info_cache
end

function Pet.Count()
  return Pet.HasPet() and 1 or 0
end

function Pet.PrimaryGuid()
  local info = Pet.Info()
  return info.exists and info.guid or nil
end

function Pet.Name()
  local info = Pet.Info()
  return info.exists and info.name or ""
end

function Pet.Family()
  local info = Pet.Info()
  return info.exists and info.family or ""
end

function Pet.HealthPct()
  local info = Pet.Info()
  return info.exists and info.health_pct or 0
end

function Pet.PowerPct()
  local info = Pet.Info()
  return info.exists and info.power_pct or 0
end

function Pet.IsDead()
  local info = Pet.Info()
  return info.exists and info.is_dead or false
end

function Pet.InCombat()
  local info = Pet.Info()
  return info.exists and info.in_combat or false
end

-- Returns { level, damage_pct, loyalty_rate } or nil when no pet.
function Pet.Happiness()
  local level, dmg_pct, loyalty = call_game_lua("GetPetHappiness")
  level = tonumber(level)
  if not level or level <= 0 then return nil end
  return {
    level        = level,
    damage_pct   = tonumber(dmg_pct) or 0,
    loyalty_rate = tonumber(loyalty) or 0,
  }
end

function Pet.IsHappy()
  local h = Pet.Happiness()
  return h ~= nil and h.damage_pct >= 125
end

-- Feed the pet with a named consumable.

local FEED_PET_AURA_ID    = 1539
local FEED_PET_AURA_NAMES = { "Feed Pet Effect", "Feed Pet" }
local _last_feed_at       = {}
local FEED_THROTTLE_S     = 2.0

local function pet_is_eating()
  local pet = Pet.GetPrimary()
  if not pet or not pet.HasAura then return false end
  if pet:HasAura(FEED_PET_AURA_ID) then return true end
  for _, name in ipairs(FEED_PET_AURA_NAMES) do
    if pet:HasAura(name) then return true end
  end
  return false
end

function Pet.Feed(item_name)
  if type(item_name) ~= "string" or item_name == "" then return false end
  if not Pet.HasPet() then return false end
  if not wow or not wow.run_lua then return false end
  if pet_is_eating() then return false end

  local now = os.clock()
  if now - (_last_feed_at[item_name] or 0) < FEED_THROTTLE_S then
    return false
  end

  local script = "local target = " .. string.format("%q", item_name) .. "\n"
      .. [[
local NumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
local ItemLink = (C_Container and C_Container.GetContainerItemLink) or GetContainerItemLink
local UseItem  = (C_Container and C_Container.UseContainerItem)     or UseContainerItem
if not (NumSlots and ItemLink and UseItem and CastSpellByName) then return end

local found_bag, found_slot
for bag = 0, 4 do
  for slot = 1, (NumSlots(bag) or 0) do
    local link = ItemLink(bag, slot)
    if link and link:find(target, 1, true) then
      found_bag, found_slot = bag, slot
      break
    end
  end
  if found_bag then break end
end
if not found_bag then return end

CastSpellByName("Feed Pet")
UseItem(found_bag, found_slot)
]]

  if not pcall(wow.run_lua, script) then return false end

  _last_feed_at[item_name] = now
  pet_debug_log({
    spell = "Pet Feed",
    action = "feed",
    target = item_name,
    result = "DISPATCHED",
  })
  return true
end

-- Live combobox of bag items with subclassID == 5 (Food & Drink).

local FOOD_REFRESH_S = 3.0
local _food_list = {}
local _food_refreshed_at = 0

local FOOD_SCAN_SCRIPT = [[
local NumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
local ItemLink = (C_Container and C_Container.GetContainerItemLink) or GetContainerItemLink
if not (NumSlots and ItemLink and GetItemInfo) then
  _G.__aegis_pet_food_list = {}
  return
end
local seen, list = {}, {}
for bag = 0, 4 do
  for slot = 1, (NumSlots(bag) or 0) do
    local link = ItemLink(bag, slot)
    if link then
      local name, _, _, _, _, _, _, _, _, _, _, _, subclass = GetItemInfo(link)
      if name and subclass == 5 and not seen[name] then
        seen[name] = true
        list[#list + 1] = name
      end
    end
  end
end
table.sort(list)
_G.__aegis_pet_food_list = list
]]

local function refresh_food_list()
  if not wow or not wow.run_lua or not wow.read_lua_table then return end
  if not pcall(wow.run_lua, FOOD_SCAN_SCRIPT) then return end
  local ok, out = pcall(wow.read_lua_table, "__aegis_pet_food_list", 2)
  if not ok or type(out) ~= "table" then return end
  _food_list = {}
  for i, name in ipairs(out) do _food_list[i] = name end
end

local function ensure_food_list_fresh()
  local now = os.clock()
  if now - _food_refreshed_at >= FOOD_REFRESH_S then
    _food_refreshed_at = now
    refresh_food_list()
  end
end

function Pet.SelectedFood(uid, default)
  local saved = AegisSettings and AegisSettings[uid]
  if type(saved) == "string" and saved ~= "" then return saved end
  return default or ""
end

function Pet.DrawFoodPicker(uid, default, label)
  local imgui = require("imgui")
  ensure_food_list_fresh()

  local saved = Pet.SelectedFood(uid, default)
  local in_bags = false
  for _, name in ipairs(_food_list) do
    if name == saved then
      in_bags = true; break
    end
  end

  local preview = in_bags and saved or (saved .. "  (none in bags)")
  local combo_label = (label or "Pet food") .. "##" .. uid
  if imgui.begin_combo(combo_label, preview) then
    if not in_bags and saved ~= "" then
      if imgui.selectable(saved .. "  (none in bags)##" .. uid .. "_saved", true) then
        AegisSettings[uid] = saved
      end
      imgui.separator()
    end
    if #_food_list == 0 then
      imgui.text_colored(0.6, 0.6, 0.6, 1, "No food in bags")
    else
      for i, name in ipairs(_food_list) do
        local sel = (name == saved)
        if imgui.selectable(name .. "##" .. uid .. "_" .. i, sel) then
          AegisSettings[uid] = name
        end
      end
    end
    imgui.end_combo()
  end
end

function Pet.GetPrimary()
  local tick = tick_key()
  if _primary_cache_tick == tick then
    return _primary_cache
  end

  _primary_cache = make_unit(PET_TOKEN)
  _primary_cache_tick = tick
  return _primary_cache
end

function Pet.GetTarget()
  local pet = Pet.GetPrimary()
  if pet and pet.obj_ptr and game and game.unit_target then
    local ok, target = pcall(game.unit_target, pet.obj_ptr)
    if ok and target and target.obj_ptr then
      local entities = Aegis and Aegis._entity_cache or {}
      for _, entity in ipairs(entities) do
        if entity.obj_ptr == target.obj_ptr then
          return Unit and Unit:New(entity) or target
        end
      end

      return Unit and Unit:New(target) or target
    end
  end

  return make_unit(PET_TARGET_TOKEN)
end

function Pet.GetAll()
  local pet = Pet.GetPrimary()
  if not pet then
    return {}
  end
  return { pet }
end

function Pet.FindByName(pattern)
  local pet = Pet.GetPrimary()
  if not pet or not pattern then
    return nil
  end

  if norm(pet.Name):find(norm(pattern), 1, true) then
    return pet
  end
  return nil
end

function Pet.HasPetNamed(pattern)
  return Pet.FindByName(pattern) ~= nil
end

function Pet.HasPetOfFamily(family)
  local current = Pet.Family()
  if current ~= "" and norm(current) == norm(family) then
    return true
  end

  local pet = Pet.GetPrimary()
  if pet and pet.CreatureFamilyId ~= nil then
    return tostring(pet.CreatureFamilyId) == tostring(family)
  end

  return false
end

function Pet.GetPrimaryFamily()
  return Pet.Family()
end

function Pet.FindByFamily(family)
  if Pet.HasPetOfFamily(family) then
    return Pet.GetPrimary()
  end
  return nil
end

function Pet.IsPermanent()
  return Pet.HasPet()
end

function Pet.TimeRemaining()
  return nil
end

function Pet.GetActions()
  local tick = tick_key()
  if _actions_cache and _actions_cache_tick == tick then
    return _actions_cache
  end

  local actions = {}
  for slot = 1, PET_ACTION_SLOTS do
    local action = read_action(slot)
    if action then
      actions[#actions + 1] = action
    end
  end

  _actions_cache = actions
  _actions_cache_tick = tick
  return actions
end

function Pet.GetActionInfo(slot)
  slot = tonumber(slot)
  if not slot then return nil end

  for _, action in ipairs(Pet.GetActions()) do
    if action.slot == slot then
      return action
    end
  end
  return nil
end

function Pet.FindAction(name_or_token)
  if type(name_or_token) == "number" then
    return Pet.GetActionInfo(name_or_token)
  end

  if not name_or_token then
    return nil
  end

  for _, action in ipairs(Pet.GetActions()) do
    if action_matches(action, name_or_token) then
      return action
    end
  end
  return nil
end

function Pet.IsActionReady(name_or_slot)
  local action = Pet.FindAction(name_or_slot)
  if not action then
    return false
  end

  return action.cooldown_duration <= 0
end

-- Pet spell range check via IsSpellInRange.

local _pet_sb_ids = {}
local _pet_sb_guid = nil

local PET_SPELLBOOK_SCAN = [[
_G.__aegis_pet_sb_ids = {}
local ids = _G.__aegis_pet_sb_ids
if not GetSpellBookItemName or not GetSpellLink then return end
for i = 1, 20 do
  local name = GetSpellBookItemName(i, "pet")
  if not name then break end
  local link = GetSpellLink(i, "pet")
  if link then
    local sid = tonumber(link:match("spell:(%d+)"))
    if sid and sid >= 1 and sid <= 1000000 then
      ids[name] = sid
    end
  end
end
]]

local function refresh_pet_spellbook(pet_guid)
  _pet_sb_ids = {}
  _pet_sb_guid = pet_guid
  if not wow or not wow.run_lua or not wow.read_lua_table then return end
  if not pcall(wow.run_lua, PET_SPELLBOOK_SCAN) then return end
  local ok, ids = pcall(wow.read_lua_table, "__aegis_pet_sb_ids", 2)
  if ok and type(ids) == "table" then
    for k, v in pairs(ids) do _pet_sb_ids[k] = tonumber(v) end
  end
end

local function ensure_pet_spellbook()
  if not Pet.HasPet() then return end
  local pet = Pet.GetPrimary()
  if not pet then return end
  if pet.Guid == _pet_sb_guid and next(_pet_sb_ids) then return end
  refresh_pet_spellbook(pet.Guid)
end

local function decode_in_range(r)
  if r == 1 or r == true then return true end
  if r == 0 or r == false then return false end
  return nil
end

function Pet.IsSpellInRange(spell_name, target)
  ensure_pet_spellbook()
  local id = _pet_sb_ids[spell_name]
  if not id or not wow or not wow.call_game_lua then return nil end

  local function check(token)
    local ok, r = pcall(wow.call_game_lua, "IsSpellInRange", id, token)
    if not ok then return nil end
    return decode_in_range(r)
  end

  if target == nil or target == "target" then return check("target") end
  if target == "player" or target == "pet" or target == "mouseover" then
    return check(target)
  end

  if wow.with_mouseover then
    return wow.with_mouseover(target, check)
  end
  return nil
end

function Pet.CastAction(name_or_slot)
  if type(name_or_slot) == "number" then
    return cast_action_slot(name_or_slot)
  end
  return cast_action_key(name_or_slot)
end

function Pet.CastBarSlot(slot)
  return cast_action_slot(slot)
end

-- Route `target` through the mouseover bridge for PetAttack.
function Pet.Attack(target)
  if not target or not wow or not wow.with_mouseover or not wow.call_game_lua then
    return false
  end
  return wow.with_mouseover(target, function(tok)
    local ok = pcall(wow.call_game_lua, "PetAttack", tok)
    return ok
  end)
end

function Pet.Follow()
  return cast_action_key("follow") or run_pet_script("PetFollow",
    "if PetFollow then PetFollow() end", "fallback PetFollow")
end

function Pet.Stay()
  return cast_action_key("stay") or run_pet_script("PetWait",
    "if PetWait then PetWait() end", "fallback PetWait")
end

function Pet.MoveTo()
  return cast_action_key("move_to")
end

function Pet.Assist()
  return cast_action_key("assist") or run_pet_script("PetAssistMode",
    "if PetAssistMode then PetAssistMode() end", "fallback PetAssistMode")
end

function Pet.Defensive()
  return cast_action_key("defensive") or run_pet_script("PetDefensiveMode",
    "if PetDefensiveMode then PetDefensiveMode() end", "fallback PetDefensiveMode")
end

function Pet.Passive()
  return cast_action_key("passive") or run_pet_script("PetPassiveMode",
    "if PetPassiveMode then PetPassiveMode() end", "fallback PetPassiveMode")
end

function Pet.Aggressive()
  return cast_action_key("aggressive") or run_pet_script("PetAggressiveMode",
    "if PetAggressiveMode then PetAggressiveMode() end", "fallback PetAggressiveMode")
end

function Pet.Dismiss()
  return run_pet_script("PetDismiss", "if PetDismiss then PetDismiss() end",
    "fallback PetDismiss")
end

function Pet.ToggleAutocast(name_or_slot)
  local action = Pet.FindAction(name_or_slot)
  if not action or not action.autocast_allowed then
    pet_debug_log({
      spell = "Pet Autocast",
      action = "TogglePetAutocast",
      slot = type(name_or_slot) == "number" and name_or_slot or 0,
      result = "SKIP",
      reason = action and "autocast not allowed" or "action not found",
    })
    return false
  end

  local result = call_game_lua("TogglePetAutocast", action.slot)
  pet_debug_log({
    spell = action.name or "Pet Autocast",
    action = "TogglePetAutocast",
    slot = action.slot,
    result = result ~= nil and "SUCCESS" or "FAIL",
    reason = result ~= nil and "toggle sent" or "no result",
    detail = string.format("old_autocast=%s shine=%s raw_auto=%s/%s",
      tostring(action.autocast_enabled), raw_label(action.shine_autocast_enabled),
      raw_label(action.raw_autocast_allowed),
      raw_label(action.raw_autocast_enabled)),
  })
  Pet.InvalidateCache()
  return result ~= nil
end

function Pet.SetAutocast(name_or_slot, enabled)
  local action = Pet.FindAction(name_or_slot)
  if not action or not action.autocast_allowed then
    pet_debug_log({
      spell = "Pet Autocast",
      action = "SetAutocast",
      slot = type(name_or_slot) == "number" and name_or_slot or 0,
      result = "SKIP",
      reason = action and "autocast not allowed" or "action not found",
      detail = string.format("desired=%s", tostring(enabled)),
    })
    return false
  end

  if action.autocast_enabled == enabled then
    pet_debug_log({
      spell = action.name or "Pet Autocast",
      action = "SetAutocast",
      slot = action.slot,
      result = "SKIP",
      reason = "already desired state",
      detail = string.format("autocast=%s shine=%s raw_auto=%s/%s",
        tostring(action.autocast_enabled), raw_label(action.shine_autocast_enabled),
        raw_label(action.raw_autocast_allowed),
        raw_label(action.raw_autocast_enabled)),
    })
    return true
  end

  pet_debug_log({
    spell = action.name or "Pet Autocast",
    action = "SetAutocast",
    slot = action.slot,
    result = "SUCCESS",
    reason = "state mismatch",
    detail = string.format("current=%s desired=%s shine=%s raw_auto=%s/%s",
      tostring(action.autocast_enabled), tostring(enabled),
      raw_label(action.shine_autocast_enabled), raw_label(action.raw_autocast_allowed),
      raw_label(action.raw_autocast_enabled)),
  })
  return Pet.ToggleAutocast(action.slot)
end

function Pet.AutocastEnabled(name_or_slot)
  local action = Pet.FindAction(name_or_slot)
  return action and action.autocast_enabled or false
end

function Pet.GetAllSummons()
  local tick = tick_key()
  if _summons_cache and _summons_cache_tick == tick then
    return _summons_cache
  end

  local summons = {}
  local entities = Aegis and Aegis._entity_cache or {}
  for _, entity in ipairs(entities) do
    if owner_matches_player(entity) then
      summons[#summons + 1] = entity
    end
  end

  _summons_cache = summons
  _summons_cache_tick = tick
  return summons
end

function Pet.SummonCount()
  return #Pet.GetAllSummons()
end

function Pet.HasSummonNamed(pattern)
  if not pattern then return false end
  local wanted = norm(pattern)
  for _, entity in ipairs(Pet.GetAllSummons()) do
    if norm(entity_name(entity)):find(wanted, 1, true) then
      return true
    end
  end
  return false
end

function Pet.FindSummonByName(pattern)
  if not pattern then return nil end
  local wanted = norm(pattern)
  for _, entity in ipairs(Pet.GetAllSummons()) do
    if norm(entity_name(entity)):find(wanted, 1, true) then
      return entity
    end
  end
  return nil
end

function Pet.HasSummonOfFamily(family)
  return Pet.FindSummonByFamily(family) ~= nil
end

function Pet.FindSummonByFamily(family)
  for _, entity in ipairs(Pet.GetAllSummons()) do
    local ef = entity_family(entity)
    if ef ~= nil and tostring(ef) == tostring(family) then
      return entity
    end
  end
  return nil
end

function Pet.OwnerOf(unit_or_entity)
  if not unit_or_entity then
    return nil
  end
  local unit = unit_or_entity.unit or unit_or_entity
  return unit_or_entity.charmed_by_guid or unit.charmed_by_guid or
      unit_or_entity.summoned_by_guid or unit.summoned_by_guid or
      unit_or_entity.created_by_guid or unit.created_by_guid
end

function Pet.IsOwnedByPlayer(unit_or_entity)
  return owner_matches_player(unit_or_entity)
end

return Pet
