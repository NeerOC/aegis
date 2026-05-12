---@class Defensive
local Defensive = {}

local include_file = (Aegis and Aegis.include) or include
local DATA = include_file and include_file("data/defensive_tbc.lua") or {}

local _danger_names, _threat_names, _manual_names = nil, nil, nil
local _last_cast_at = {}

local CLASS_SPELLS = {
  [1] = {
    emergency = {
      { key = "LastStand", ids = { 12975 } },
      { key = "ShieldWall", ids = { 871 } },
    },
    pull = { { key = "Taunt", ids = { 355 }, target = "enemy" } },
  },
  [2] = {
    emergency = { { key = "DivineShield", ids = { 642, 1020 } } },
    pull = {
      { key = "RighteousDefense", ids = { 31789 }, target = "threat_friend" },
      { key = "BlessingOfProtection", ids = { 10278, 5599, 1022 }, target = "threat_friend", non_tank_only = true },
    },
  },
  [3] = {
    threat = { { key = "FeignDeath", ids = { 5384 } } },
    pull = { { key = "Misdirection", ids = { 34477 }, target = "tank" } },
  },
  [4] = {
    emergency = {
      { key = "CloakOfShadows", ids = { 31224 } },
      { key = "Vanish", ids = { 26889, 1857, 1856 } },
    },
    threat = { { key = "Vanish", ids = { 26889, 1857, 1856 } } },
  },
  [5] = { threat = { { key = "Fade", ids = { 25429, 10942, 10941, 586 } } } },
  [8] = { emergency = { { key = "IceBlock", ids = { 45438 } } } },
  [9] = { threat = { { key = "Soulshatter", ids = { 29858 } } } },
  [11] = {
    emergency = { { key = "Barkskin", ids = { 22812 } } },
    pull = { { key = "Growl", ids = { 6795 }, target = "enemy" } },
  },
}

local function normalize_name(name)
  name = tostring(name or ""):lower()
  name = name:gsub("[%s%p]+", " ")
  name = name:gsub("^%s+", ""):gsub("%s+$", "")
  return name
end

local function add_names(index, record)
  for _, name in ipairs(record and record.names or {}) do
    local key = normalize_name(name)
    if key ~= "" then index[key] = record end
  end
end

local function ensure_indexes()
  if _danger_names then return end
  _danger_names, _threat_names, _manual_names = {}, {}, {}
  for _, record in ipairs(DATA.DangerousSources or {}) do add_names(_danger_names, record) end
  for _, record in ipairs(DATA.ThreatSensitive or {}) do add_names(_threat_names, record) end
  for _, record in ipairs(DATA.ManualOnly or {}) do add_names(_manual_names, record) end
end

local function manual_blocked(name, allow_manual)
  if allow_manual then return false end
  ensure_indexes()
  return _manual_names[normalize_name(name)] ~= nil
end

local function record_allowed(record, options)
  if not record then return false end
  if record.guarded and not (options and options.allow_guarded) then return false end
  return true
end

local function unit_name(unit)
  return unit and (unit.Name or unit.name) or ""
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

local function targets(options)
  local out, seen = {}, {}
  options = options or {}
  add_target(out, seen, options.target)
  add_target(out, seen, Me and Me.Target)
  add_target(out, seen, Me and Me.Focus)
  add_target(out, seen, Combat and Combat.BestTarget)
  add_target(out, seen, Tank and Tank.BestTarget)
  for _, unit in ipairs(Combat and Combat.Targets or {}) do add_target(out, seen, unit) end
  return out
end

local function lookup(index, options)
  ensure_indexes()
  options = options or {}
  for _, unit in ipairs(targets(options)) do
    local name = unit_name(unit)
    if not manual_blocked(name, options.allow_manual) then
      local record = index[normalize_name(name)]
      if record_allowed(record, options) then return record, unit end
    end
  end
  local entry = Encounter and Encounter.CurrentContext and select(1, Encounter.CurrentContext()) or nil
  if entry and not manual_blocked(entry.name, options.allow_manual) then
    local names = { entry.name, entry.instance }
    for _, name in ipairs(names) do
      local record = index[normalize_name(name)]
      if record_allowed(record, options) then return record, nil end
    end
  end
  return nil, nil
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

local function throttle_ready(prefix, suffix, interval)
  local key = tostring(prefix or "Defensive") .. suffix
  local now = os.clock()
  if _last_cast_at[key] and now - _last_cast_at[key] < (interval or 2.0) then return false end
  return true
end

local function remember(prefix, suffix)
  _last_cast_at[tostring(prefix or "Defensive") .. suffix] = os.clock()
end

local function health_pct()
  return tonumber(Me and Me.HealthPct) or 100
end

local function is_tanking_any()
  if not Me or not Me.IsTanking then return false end
  for _, target in ipairs(targets({})) do
    local ok, tanking = pcall(Me.IsTanking, Me, target)
    if ok and tanking then return true end
  end
  return false
end

local function threat_high()
  if is_tanking_any() then return false end
  if not Me or not Me.ThreatSituation then return false end
  for _, target in ipairs(targets({})) do
    local ok, status = pcall(Me.ThreatSituation, Me, target)
    if ok and tonumber(status) and tonumber(status) >= 2 then return true end
  end
  return false
end

local function contains_guid(list, guid)
  if not guid then return false end
  for _, unit in ipairs(list or {}) do
    if unit_guid(unit) == guid then return true end
  end
  return false
end

local function friend_threat_target(non_tank_only)
  if not Heal or not Heal.Friends then return nil end
  local tanks = Heal.Friends.Tanks or {}
  for _, friend in ipairs(Heal.Friends.All or {}) do
    repeat
      if not friend or friend.IsDead then break end
      local guid = unit_guid(friend)
      if non_tank_only and contains_guid(tanks, guid) then break end
      if Me and guid == unit_guid(Me) then break end
      for _, enemy in ipairs(targets({})) do
        local tanking = false
        if friend.IsTanking then
          local ok, result = pcall(friend.IsTanking, friend, enemy)
          tanking = ok and result == true
        end
        local status = 0
        if friend.ThreatSituation then
          local ok, result = pcall(friend.ThreatSituation, friend, enemy)
          status = ok and tonumber(result) or 0
        end
        if tanking or status >= 2 then return friend end
      end
    until true
  end
  return nil
end

local function tank_target()
  local tanks = Heal and Heal.Friends and Heal.Friends.Tanks or {}
  for _, unit in ipairs(tanks) do
    if unit and not unit.IsDead then return unit end
  end
  return Me
end

local function enemy_target(options)
  options = options or {}
  if options.target and not options.target.IsDead then return options.target end
  if Combat and Combat.BestTarget and not Combat.BestTarget.IsDead then return Combat.BestTarget end
  if Tank and Tank.BestTarget and not Tank.BestTarget.IsDead then return Tank.BestTarget end
  return Me and Me.Target or nil
end

local function cast_spec(prefix, spec, options)
  local spell = spell_ready(spec)
  if not spell or not spell.CastEx then return false end
  local target = Me
  if spec.target == "tank" then
    target = tank_target()
  elseif spec.target == "enemy" then
    target = enemy_target(options)
  elseif spec.target == "threat_friend" then
    target = friend_threat_target(spec.non_tank_only)
  end
  if not target or target.IsDead then return false end
  if spell:CastEx(target, { skipUsable = true, skipFacing = true }) then
    remember(prefix, spec.key or "spell")
    return true
  end
  return false
end

local function class_specs(kind)
  local class_id = tonumber(Me and Me.ClassId) or 0
  local cfg = CLASS_SPELLS[class_id] or {}
  return cfg[kind] or {}
end

function Defensive.HasDanger(options)
  return lookup(_danger_names, options)
end

function Defensive.HasThreatSensitiveContext(options)
  return lookup(_threat_names, options)
end

function Defensive.TryEmergency(prefix, options)
  options = options or {}
  if not AegisSettings or not AegisSettings[(prefix or "") .. "UseDefensives"] then return false end
  if not Me or Me.IsDead then return false end
  if Spell and Spell.IsGCDActive and Spell:IsGCDActive() and not options.allow_gcd then return false end

  local hp_trigger = health_pct() <= (AegisSettings[(prefix or "") .. "DefensivePct"] or 25)
  local encounter_trigger = false
  if AegisSettings[(prefix or "") .. "UseEncounterDefensives"] then
    encounter_trigger = lookup(_danger_names, options) ~= nil
      and health_pct() <= (AegisSettings[(prefix or "") .. "EncounterDefensivePct"] or 70)
  end
  if not hp_trigger and not encounter_trigger then return false end
  if not throttle_ready(prefix, "emergency", 2.0) then return false end

  for _, spec in ipairs(class_specs("emergency")) do
    if cast_spec(prefix, spec, options) then return true end
  end
  if Item and Item.TryDefensiveTrinket and Item.TryDefensiveTrinket() then
    remember(prefix, "emergency")
    return true
  end
  return false
end

function Defensive.TryThreat(prefix, options)
  options = options or {}
  if not AegisSettings or not AegisSettings[(prefix or "") .. "UseThreatDrop"] then return false end
  if not Me or Me.IsDead then return false end
  if is_tanking_any() then return false end
  local contextual = AegisSettings[(prefix or "") .. "UseThreatUtility"] and lookup(_threat_names, options) ~= nil
  if not threat_high() and not contextual then return false end
  if not throttle_ready(prefix, "threat", 2.0) then return false end
  for _, spec in ipairs(class_specs("threat")) do
    if cast_spec(prefix, spec, options) then return true end
  end
  return false
end

function Defensive.TryPull(prefix, options)
  options = options or {}
  if not AegisSettings or not AegisSettings[(prefix or "") .. "UseThreatUtility"] then return false end
  if not lookup(_threat_names, options) and not friend_threat_target(false) then return false end
  if not throttle_ready(prefix, "pull", 2.0) then return false end
  for _, spec in ipairs(class_specs("pull")) do
    if cast_spec(prefix, spec, options) then return true end
  end
  return false
end

function Defensive.Widgets(prefix, defaults)
  defaults = defaults or {}
  return {
    { type = "checkbox", uid = prefix .. "UseDefensives", text = "Emergency defensives", default = defaults.defensives == true },
    { type = "slider", uid = prefix .. "DefensivePct", text = "Defensive below HP %", default = defaults.defensive_pct or 25, min = 0, max = 80 },
    { type = "checkbox", uid = prefix .. "UseEncounterDefensives", text = "Encounter defensives", default = false },
    { type = "slider", uid = prefix .. "EncounterDefensivePct", text = "Encounter defensive below HP %", default = defaults.encounter_pct or 70, min = 0, max = 100 },
    { type = "checkbox", uid = prefix .. "UseThreatDrop", text = "Threat drop", default = defaults.threat_drop == true },
    { type = "checkbox", uid = prefix .. "UseThreatUtility", text = "Threat / pull utility", default = false },
  }
end

return Defensive
