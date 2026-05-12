---@class AntiFear
local AntiFear = {}

local include_file = (Aegis and Aegis.include) or include
local DATA = include_file and include_file("data/anti_fear_tbc.lua") or {}
local ACTIONS = DATA.Actions or {
  Tremor = "tremor",
  FearWard = "fear_ward",
  Grounding = "grounding",
}

local _fear_names, _context_names, _grounding_names, _manual_names = nil, nil, nil, nil
local _last_cast_at = {}

local function normalize_name(name)
  name = tostring(name or ""):lower()
  name = name:gsub("[%s%p]+", " ")
  name = name:gsub("^%s+", ""):gsub("%s+$", "")
  return name
end

local function add_names(index, record, field)
  for _, name in ipairs(record and record[field or "names"] or {}) do
    local key = normalize_name(name)
    if key ~= "" then index[key] = record end
  end
end

local function ensure_indexes()
  if _fear_names then return end
  _fear_names, _context_names, _grounding_names, _manual_names = {}, {}, {}, {}
  for _, record in ipairs(DATA.FearMechanics or {}) do add_names(_fear_names, record, "names") end
  for _, record in ipairs(DATA.ContextFear or {}) do add_names(_context_names, record, "names") end
  for _, record in ipairs(DATA.GroundingMechanics or {}) do add_names(_grounding_names, record, "spell_names") end
  for _, record in ipairs(DATA.ManualOnly or {}) do add_names(_manual_names, record, "names") end
end

local function unit_guid(unit)
  return unit and (unit.Guid or unit.guid or unit.GUID) or nil
end

local function unit_name(unit)
  return unit and (unit.Name or unit.name) or ""
end

local function target_distance(unit)
  if not Me or not Me.GetDistance or not unit then return math.huge end
  local ok, dist = pcall(Me.GetDistance, Me, unit)
  return ok and (tonumber(dist) or math.huge) or math.huge
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
  for _, unit in ipairs(options.targets or {}) do add_target(out, seen, unit) end
  add_target(out, seen, options.target)
  add_target(out, seen, Me and Me.Target)
  add_target(out, seen, Me and Me.Focus)
  add_target(out, seen, Combat and Combat.BestTarget)
  for _, unit in ipairs(Combat and Combat.Targets or {}) do add_target(out, seen, unit) end
  return out
end

local function record_allows_action(record, action)
  for _, candidate in ipairs(record and record.actions or {}) do
    if candidate == action then return true end
  end
  return false
end

local function manual_blocked(name, allow_manual)
  if allow_manual then return false end
  ensure_indexes()
  return _manual_names[normalize_name(name)] ~= nil
end

local function record_allowed(record, options)
  if not record then return false end
  options = options or {}
  if record.manual_only and not options.allow_manual then return false end
  if record.guarded and not options.allow_guarded then return false end
  return true
end

local function find_fear(action, options)
  ensure_indexes()
  options = options or {}
  local best = nil
  local max_range = tonumber(options.range or options.max_range) or 40

  for _, unit in ipairs(targets(options)) do
    repeat
      if manual_blocked(unit_name(unit), options.allow_manual) then break end
      if target_distance(unit) > max_range then break end
      local record = _fear_names[normalize_name(unit_name(unit))]
      if not record_allowed(record, options) then break end
      if not record_allows_action(record, action) then break end
      local score = tonumber(record.priority) or 50
      if not best or score > best.score then
        best = { unit = unit, record = record, score = score, source = "unit" }
      end
    until true
  end

  local entry = Encounter and Encounter.CurrentContext and select(1, Encounter.CurrentContext()) or nil
  if entry and not manual_blocked(entry.name, options.allow_manual) then
    local context_names = { entry.name, entry.instance }
    for _, context_name in ipairs(context_names) do
      local record = _context_names[normalize_name(context_name)]
      if record_allowed(record, options) and record_allows_action(record, action) then
        local score = tonumber(record.priority) or 50
        if not best or score > best.score then
          best = { context = entry, record = record, score = score, source = "context" }
        end
      end
    end
  end

  return best
end

local function spell_ready(key, ids)
  if Spell and Spell.ById then
    for _, id in ipairs(ids or {}) do
      local s = Spell:ById(id)
      if s and s.IsKnown and (not s.IsReady or s:IsReady()) then return s end
    end
  end
  local fallback = Spell and key and Spell[key] or nil
  if fallback and fallback.IsKnown and (not fallback.IsReady or fallback:IsReady()) then return fallback end
  return nil
end

local function aura_remains(unit, name)
  if not unit then return 0 end
  local aura = unit.GetAura and unit:GetAura(name) or nil
  if not aura then return 0 end
  if aura.remains then return tonumber(aura.remains) or 0 end
  if aura.remaining then
    local remaining = tonumber(aura.remaining) or 0
    return remaining > 100 and remaining / 1000 or remaining
  end
  return 9999
end

local function fear_ward_target()
  local tanks = Heal and Heal.Friends and Heal.Friends.Tanks or {}
  for _, unit in ipairs(tanks) do
    if unit and not unit.IsDead then return unit end
  end
  return Me
end

local function throttle_ready(key, interval)
  interval = interval or 3.0
  local now = os.clock()
  return not _last_cast_at[key] or now - _last_cast_at[key] >= interval
end

function AntiFear.ShouldTremor(prefix, options)
  if not AegisSettings or not AegisSettings[(prefix or "") .. "UseAntiFear"] then return nil end
  if tonumber(Me and Me.ClassId) ~= 7 then return nil end
  return find_fear(ACTIONS.Tremor, options)
end

function AntiFear.ShouldFearWard(prefix, options)
  if not AegisSettings or not AegisSettings[(prefix or "") .. "UseFearWard"] then return nil end
  if tonumber(Me and Me.ClassId) ~= 5 then return nil end
  return find_fear(ACTIONS.FearWard, options)
end

function AntiFear.TryFearWard(prefix, options)
  if not AntiFear.ShouldFearWard(prefix, options) then return false end
  local target = fear_ward_target()
  if not target or target.IsDead or aura_remains(target, "Fear Ward") > 15 then return false end
  local spell = spell_ready("FearWard", { 6346 })
  if not spell or not spell.CastEx then return false end
  local key = (prefix or "Priest") .. "FearWard"
  if not throttle_ready(key, 2.0) then return false end
  if spell:CastEx(target) then
    _last_cast_at[key] = os.clock()
    return true
  end
  return false
end

local function casting_spell_name(unit)
  if not unit then return "" end
  if unit.CastingInfo then
    local ok, cast, channel = pcall(unit.CastingInfo, unit)
    if ok then
      return (cast and cast.spell_name) or (channel and channel.spell_name) or ""
    end
  end
  return unit.CastingSpellName or unit.ChannelingSpellName or ""
end

function AntiFear.FindGroundingTarget(options)
  ensure_indexes()
  options = options or {}
  local max_range = tonumber(options.range or options.max_range) or 30
  local best = nil

  for _, unit in ipairs(targets(options)) do
    repeat
      if manual_blocked(unit_name(unit), options.allow_manual) then break end
      if target_distance(unit) > max_range then break end
      local spell_name = casting_spell_name(unit)
      local record = _grounding_names[normalize_name(spell_name)]
      if not record_allowed(record, options) then break end
      local score = tonumber(record.priority) or 50
      if not best or score > best.score then
        best = { unit = unit, record = record, spell_name = spell_name, score = score }
      end
    until true
  end

  return best
end

function AntiFear.ShouldGrounding(prefix, target, options)
  if not AegisSettings or not AegisSettings[(prefix or "") .. "GroundingTotem"] then return nil end
  if tonumber(Me and Me.ClassId) ~= 7 then return nil end
  options = options or {}
  options.target = options.target or target
  return AntiFear.FindGroundingTarget(options)
end

AntiFear.Actions = ACTIONS

return AntiFear
