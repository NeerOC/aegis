---@class Racials
---@field Catalog table<string, table> Racial spell catalog keyed by short name.
---@field DamageAuras string[] Aura names that count as a "damage window".
local Racials = {}

local DAMAGE_AURAS = {
  "Bloodlust",
  "Heroism",
  "Rapid Fire",
  "Bestial Wrath",
  "Death Wish",
  "Recklessness",
  "Sweeping Strikes",
  "Blade Flurry",
  "Adrenaline Rush",
  "Icy Veins",
  "Arcane Power",
  "Combustion",
  "Power Infusion",
  "Avenging Wrath",
  "Elemental Mastery",
}

local CATALOG = {
  BloodFury = {
    name = "Blood Fury",
    ids = { 20572, 33697, 33702 },
    kind = "damage",
  },
  Berserking = {
    name = "Berserking",
    ids = { 26297 },
    kind = "damage",
  },
  WarStomp = {
    name = "War Stomp",
    ids = { 20549 },
    kind = "interrupt",
    range = 8,
  },
  ArcaneTorrent = {
    name = "Arcane Torrent",
    ids = { 28730, 25046 },
    kind = "interrupt",
    range = 8,
  },
  GiftOfTheNaaru = {
    name = "Gift of the Naaru",
    ids = { 28880 },
    kind = "survival",
  },
  Stoneform = {
    name = "Stoneform",
    ids = { 20594 },
    kind = "utility",
  },
  EscapeArtist = {
    name = "Escape Artist",
    ids = { 20589 },
    kind = "utility",
  },
  WillOfTheForsaken = {
    name = "Will of the Forsaken",
    ids = { 7744 },
    kind = "utility",
  },
  Perception = {
    name = "Perception",
    ids = { 20600 },
    kind = "utility",
  },
  Shadowmeld = {
    name = "Shadowmeld",
    ids = { 20580 },
    kind = "utility",
  },
}

local _cache = {}
local _damage_window_until = 0

function Racials.Reset()
  _cache = {}
  _damage_window_until = 0
end

local function spell_known(spell)
  return spell and spell.Id and spell.Id > 0 and spell.IsKnown
end

local function by_name(name)
  if not Spell or not Spell.ByName then return nil end
  local ok, spell = pcall(Spell.ByName, Spell, name)
  return ok and spell_known(spell) and spell or nil
end

local function by_ids(ids)
  if not Spell or not Spell.ById then return nil end
  for _, id in ipairs(ids or {}) do
    local ok, spell = pcall(Spell.ById, Spell, id)
    if ok and spell_known(spell) then return spell end
  end
  return nil
end

function Racials.Spell(key)
  if _cache[key] and spell_known(_cache[key]) then return _cache[key] end
  local entry = CATALOG[key]
  if not entry then return nil end
  local spell = by_name(entry.name) or by_ids(entry.ids)
  _cache[key] = spell
  return spell
end

local function target_ok(target)
  return target and not target.IsDead and Me and Me.InCombat
end

local function has_damage_aura()
  if not Me or not Me.HasAura then return false end
  for i = 1, #DAMAGE_AURAS do
    if Me:HasAura(DAMAGE_AURAS[i]) then return true end
  end
  return false
end

function Racials.MarkDamageWindow(seconds)
  _damage_window_until = math.max(_damage_window_until, os.clock() + (seconds or 1.5))
end

local function damage_window_open(opts)
  opts = opts or {}
  if opts.forceWindow then return true end
  if opts.cooldownWindow then return true end
  if os.clock() < _damage_window_until then return true end
  return has_damage_aura()
end

function Racials.TryDamageBoost(target, opts)
  if not target_ok(target) then return false end
  local mode = AegisSettings and AegisSettings.AegisRacialDamageMode or 0
  if mode == 0 then return false end
  if mode == 1 and not damage_window_open(opts) then return false end
  if mode == 2 and not (opts and opts.cooldownWindow) and os.clock() >= _damage_window_until then return false end

  local blood_fury = Racials.Spell("BloodFury")
  if blood_fury and blood_fury:IsReady() and blood_fury:CastEx(Me, { skipUsable = true, skipFacing = true }) then
    return true
  end

  local berserking = Racials.Spell("Berserking")
  if berserking and berserking:IsReady() and berserking:CastEx(Me, { skipUsable = true, skipFacing = true }) then
    return true
  end

  return false
end

function Racials.TryInterrupt(opts)
  if not AegisSettings or not AegisSettings.AegisRacialInterrupts then return false end
  if not Me or not Me.InCombat then return false end
  if not Interrupts then return false end

  local stomp = Racials.Spell("WarStomp")
  if stomp and Interrupts.CastAoE(stomp, { range = 8 }) then return true end

  local torrent = Racials.Spell("ArcaneTorrent")
  if torrent and Interrupts.CastAoE(torrent, { range = 8 }) then return true end

  return false
end

local function lowest_friend_below(pct)
  local best = nil
  if Heal and Heal.GetLowestMember then
    local ok, lowest = pcall(Heal.GetLowestMember, Heal)
    if ok and lowest and not lowest.IsDead and (lowest.HealthPct or 100) <= pct then
      best = lowest
    end
  end
  if not best and Me and not Me.IsDead and (Me.HealthPct or 100) <= pct then
    best = Me
  end
  return best
end

function Racials.TrySurvival(opts)
  if not AegisSettings or AegisSettings.AegisRacialGiftEnabled == false then return false end
  local gift = Racials.Spell("GiftOfTheNaaru")
  if not gift or not gift.IsReady or not gift:IsReady() then return false end

  opts = opts or {}
  local pct = opts.healthPct or AegisSettings.AegisRacialGiftPct or 45
  local target = opts.target
  if not target or target.IsDead or (target.HealthPct or 100) > pct then
    target = lowest_friend_below(pct)
  end
  if not target then return false end
  return gift:CastEx(target, { skipUsable = false, skipFacing = true })
end

Racials.Catalog = CATALOG
Racials.DamageAuras = DAMAGE_AURAS

return Racials
