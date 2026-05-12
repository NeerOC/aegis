-- TBC Classic 2.5.x reference table for snares, CCs, dispel categories.

local M          = {}

-- 0=None, 1=Magic, 2=Curse, 3=Disease, 4=Poison, 9=Enrage
M.DISPEL_NONE    = 0
M.DISPEL_MAGIC   = 1
M.DISPEL_CURSE   = 2
M.DISPEL_DISEASE = 3
M.DISPEL_POISON  = 4
M.DISPEL_ENRAGE  = 9

-- What each class can remove from a friendly target.
-- Druid (Remove Curse / Cure Poison / Abolish Poison):     Curse, Poison
-- Mage (Remove Lesser Curse / Spellsteal-Magic-from-self): Curse
-- Paladin (Cleanse / Purify):                              Magic, Poison, Disease
-- Priest (Dispel Magic / Cure Disease / Abolish Disease):  Magic, Disease
-- Shaman (Cure Poison / Cure Disease / Poison Cleansing
--   Totem / Disease Cleansing Totem):                      Poison, Disease
-- Hunter (Tranquilizing Shot — only enrage):               Enrage
-- Warlock Felhunter Devour Magic / Imp Spell Lock — Magic
M.CLASS_DISPELS  = {
  DRUID   = { [M.DISPEL_CURSE] = true, [M.DISPEL_POISON] = true },
  MAGE    = { [M.DISPEL_CURSE] = true },
  PALADIN = { [M.DISPEL_MAGIC] = true, [M.DISPEL_POISON] = true, [M.DISPEL_DISEASE] = true },
  PRIEST  = { [M.DISPEL_MAGIC] = true, [M.DISPEL_DISEASE] = true },
  SHAMAN  = { [M.DISPEL_POISON] = true, [M.DISPEL_DISEASE] = true },
  HUNTER  = { [M.DISPEL_ENRAGE] = true },
  WARLOCK = { [M.DISPEL_MAGIC] = true },
}

-- All ranks listed because rank-aware behavior gating is sometimes
-- needed (e.g. PvP duration scaling). Categorize as both ROOT and
-- SNARE so a single "do I have a snare on me" check catches them.
M.ROOTS          = {
  -- Frost Nova (Mage)
  [122]   = "Frost Nova",
  [865]   = "Frost Nova",
  [6131]  = "Frost Nova",
  [10230] = "Frost Nova",
  [27088] = "Frost Nova",
  -- Frostbite (Mage talent root proc)
  [12494] = "Frostbite",
  -- Entangling Roots (Druid)
  [339]   = "Entangling Roots",
  [1062]  = "Entangling Roots",
  [5195]  = "Entangling Roots",
  [5196]  = "Entangling Roots",
  [9852]  = "Entangling Roots",
  [9853]  = "Entangling Roots",
  [26989] = "Entangling Roots",
  -- Improved Hamstring (Warrior talent root proc)
  [23694] = "Improved Hamstring",
  -- Freezing Trap effect (Hunter) — incapacitate, behaves as root
  [3355]  = "Freezing Trap Effect",
  [14308] = "Freezing Trap Effect",
  [14309] = "Freezing Trap Effect",
  -- Frost Trap aura (Hunter) — slow, but listed here for completeness
  -- (its effect is a slow not a root; categorized under SLOWS below)
  -- Entrapment (Hunter talent root proc on Frost/Snake/Immo Trap)
  [19185] = "Entrapment",
  [64803] = "Entrapment",
  -- Earthgrab (Earthbind Totem root via T2 talent / shaman)
  -- Earthbind itself is a slow — see SLOWS
  -- Death Coil horrify is a fear, not root — see FEARS
  -- Shockwave / Bash etc. are stuns — see STUNS
}

M.SLOWS          = {
  -- Hamstring (Warrior)
  [1715]  = "Hamstring",
  [7372]  = "Hamstring",
  [7373]  = "Hamstring",
  [27584] = "Hamstring",
  -- Piercing Howl (Warrior Fury talent)
  [12323] = "Piercing Howl",
  -- Wing Clip (Hunter)
  [2974]  = "Wing Clip",
  [14267] = "Wing Clip",
  [14268] = "Wing Clip",
  -- Concussive Shot (Hunter)
  [5116]  = "Concussive Shot",
  -- Frost Trap aura (Hunter) — ground-effect slow
  [13810] = "Frost Trap Aura",
  -- Crippling Poison applied debuff (Rogue) — NOT the weapon enchant
  [3409]  = "Crippling Poison",
  [11201] = "Crippling Poison",
  -- Mind-Numbing Poison applied debuff (Rogue) — cast slow, kept for
  -- completeness even though it's not movement-impair
  -- (handled separately under CAST_SLOWS below)
  -- Frostbolt (Mage) chill — applied as "Chilled" aura, see Chilled
  -- Cone of Cold (Mage) — also applies "Chilled"
  -- Blizzard (Mage) — applies "Chilled" via Improved Blizzard talent
  -- All three roll into the Chilled debuff name; including the proc
  -- ids as well so they catch on direct-debuff servers.
  [116]   = "Frostbolt",
  [205]   = "Frostbolt",
  [837]   = "Frostbolt",
  [7322]  = "Frostbolt",
  [8406]  = "Frostbolt",
  [8407]  = "Frostbolt",
  [8408]  = "Frostbolt",
  [10179] = "Frostbolt",
  [10180] = "Frostbolt",
  [10181] = "Frostbolt",
  [25304] = "Frostbolt",
  [27071] = "Frostbolt",
  [27072] = "Frostbolt",
  -- Cone of Cold (Mage)
  [120]   = "Cone of Cold",
  [8492]  = "Cone of Cold",
  [10159] = "Cone of Cold",
  [10160] = "Cone of Cold",
  [10161] = "Cone of Cold",
  [27087] = "Cone of Cold",
  -- Chilled (proc/talent debuff applied by Frost armor / Frostbolt /
  -- Frost Ward / Improved Blizzard). The aura on the target is named
  -- "Chilled" with one of these IDs:
  [6136]  = "Chilled",
  [7321]  = "Chilled",
  [12484] = "Chilled",
  [12485] = "Chilled",
  [12486] = "Chilled",
  -- Frost Shock (Shaman)
  [8056]  = "Frost Shock",
  [8058]  = "Frost Shock",
  [10472] = "Frost Shock",
  [10473] = "Frost Shock",
  [25464] = "Frost Shock",
  -- Earthbind Totem aura (Shaman)
  [3600]  = "Earthbind",
  -- Curse of Exhaustion (Warlock)
  [18223] = "Curse of Exhaustion",
  -- Mind Flay (Priest) — channel slow
  [15407] = "Mind Flay",
  [17311] = "Mind Flay",
  [17312] = "Mind Flay",
  [17313] = "Mind Flay",
  [17314] = "Mind Flay",
  [18807] = "Mind Flay",
  [25387] = "Mind Flay",
  -- Slow (Mage Arcane talent ability, TBC)
  [31589] = "Slow",
  -- Dazed (NPC daze effect from melee back-attacks)
  [1604]  = "Dazed",
  -- Improved Wing Clip already a root (talent), see ROOTS
  -- Aspect of the Cheetah daze (self-applied when struck while in cheetah)
  [5118]  = "Aspect of the Cheetah",
}

M.STUNS          = {
  -- Hammer of Justice (Paladin)
  [853]   = "Hammer of Justice",
  [5588]  = "Hammer of Justice",
  [5589]  = "Hammer of Justice",
  [10308] = "Hammer of Justice",
  -- Cheap Shot (Rogue)
  [1833]  = "Cheap Shot",
  -- Kidney Shot (Rogue)
  [408]   = "Kidney Shot",
  [8643]  = "Kidney Shot",
  -- Pummel (Warrior — silence-like, but it's a stun-flagged interrupt
  -- on cast). Actually Pummel just interrupts; not a stun. Removed.
  -- Concussion Blow (Warrior Prot talent stun)
  [12809] = "Concussion Blow",
  -- Charge stun (Warrior)
  [7922]  = "Charge Stun",
  -- Intercept stun (Warrior)
  [20253] = "Intercept Stun",
  [20614] = "Intercept Stun",
  [20615] = "Intercept Stun",
  -- Bash (Druid bear)
  [5211]  = "Bash",
  [6798]  = "Bash",
  [8983]  = "Bash",
  -- Pounce (Druid cat opener)
  [9005]  = "Pounce",
  [9823]  = "Pounce",
  [9827]  = "Pounce",
  [27006] = "Pounce",
  -- Maim (Druid cat — TBC)
  [22570] = "Maim",
  -- Stunning Blow / War Stomp (Tauren racial)
  [20549] = "War Stomp",
  -- Mace specialization stun (proc-based, name varies)
  [5530]  = "Mace Stun Effect",
  -- Shadowfury (Warlock — TBC)
  [30283] = "Shadowfury",
  [30413] = "Shadowfury",
  [30414] = "Shadowfury",
  -- Death Coil horrify-stun (it's actually a horrify, see FEARS)
  -- Blackout (Priest Shadow talent, proc stun)
  [15269] = "Blackout",
  -- Improved Concussive Shot (Hunter talent stun)
  [22915] = "Improved Concussive Shot",
}

M.INCAPACITATES  = {
  -- Polymorph (Mage) — Sheep
  [118]   = "Polymorph",
  [12824] = "Polymorph",
  [12825] = "Polymorph",
  [12826] = "Polymorph",
  -- Polymorph variants (TBC quest/profession-trained)
  [28271] = "Polymorph: Turtle",
  [28272] = "Polymorph: Pig",
  -- Repentance (Paladin Ret talent)
  [20066] = "Repentance",
  -- Sap (Rogue)
  [6770]  = "Sap",
  [2070]  = "Sap",
  [11297] = "Sap",
  -- Gouge (Rogue)
  [1776]  = "Gouge",
  [1777]  = "Gouge",
  [8629]  = "Gouge",
  [11285] = "Gouge",
  [11286] = "Gouge",
  [38764] = "Gouge",
  -- Freezing Trap is listed under ROOTS (incapacitate that immobilizes)
  -- Wyvern Sting (Hunter Survival talent — sleep-poison hybrid)
  -- See SLEEPS for the secondary aura.
  [19386] = "Wyvern Sting",
  [24132] = "Wyvern Sting",
  [24133] = "Wyvern Sting",
  [27068] = "Wyvern Sting",
  -- Scatter Shot (Hunter)
  [19503] = "Scatter Shot",
  -- Blind (Rogue)
  [2094]  = "Blind",
  -- Hibernate (Druid) — Beast/Dragon sleep
  [2637]  = "Hibernate",
  [18657] = "Hibernate",
  [18658] = "Hibernate",
  -- Mind Control (Priest)
  [605]   = "Mind Control",
  [10911] = "Mind Control",
  [10912] = "Mind Control",
  -- Seduction (Warlock Succubus pet)
  [6358]  = "Seduction",
  -- Banish (Warlock — Demon/Elemental only)
  [710]   = "Banish",
  [18647] = "Banish",
}

M.FEARS          = {
  -- Fear (Warlock)
  [5782]  = "Fear",
  [6213]  = "Fear",
  [6215]  = "Fear",
  -- Howl of Terror (Warlock)
  [5484]  = "Howl of Terror",
  [17928] = "Howl of Terror",
  -- Death Coil (Warlock — horrify variant, ~3s)
  [6789]  = "Death Coil",
  [17925] = "Death Coil",
  [17926] = "Death Coil",
  [27223] = "Death Coil",
  -- Psychic Scream (Priest)
  [8122]  = "Psychic Scream",
  [8124]  = "Psychic Scream",
  [10888] = "Psychic Scream",
  [10890] = "Psychic Scream",
  -- Intimidating Shout (Warrior)
  [5246]  = "Intimidating Shout",
  -- Scare Beast (Hunter)
  [1513]  = "Scare Beast",
  [14326] = "Scare Beast",
  [14327] = "Scare Beast",
  -- Turn Evil / Turn Undead (Paladin) — fear vs Undead/Demon only
  [2878]  = "Turn Undead",
  [5627]  = "Turn Undead",
  [10326] = "Turn Evil",
}

M.SILENCES       = {
  -- Silence (Priest Shadow talent)
  [15487] = "Silence",
  -- Counterspell (Mage)
  [2139]  = "Counterspell",
  -- Pummel (Warrior) — actually an interrupt, not a silence aura
  -- Kick (Rogue) — ditto, no aura applied
  -- Spell Lock (Warlock Felhunter)
  [24259] = "Spell Lock",
  -- Garrote silence component (Rogue Sub talent — Improved Garrote)
  [1330]  = "Garrote - Silence",
  -- Strangulate (NPC, but rare — keeping out for player-only context)
  -- Arcane Torrent (Blood Elf racial silence)
  [28730] = "Arcane Torrent",
}

M.DISARMS        = {
  [676]   = "Disarm",
  [51722] = "Dismantle",
}
M.DISARMS[51722] = nil

-- ─────────────────────────────────────────────────────────────────────
-- Composite categories (build once at module load).
-- SNARES = ROOTS + SLOWS         "anything that impairs movement"
-- HARD_CC = STUNS + INCAPACITATES + FEARS  "you can't act"
-- ALL_CC  = HARD_CC + ROOTS + SILENCES + DISARMS
-- ─────────────────────────────────────────────────────────────────────

local function merge(into, src)
  for k, v in pairs(src) do into[k] = v end
end

M.SNARES = {}
merge(M.SNARES, M.ROOTS)
merge(M.SNARES, M.SLOWS)

M.HARD_CC = {}
merge(M.HARD_CC, M.STUNS)
merge(M.HARD_CC, M.INCAPACITATES)
merge(M.HARD_CC, M.FEARS)

M.ALL_CC = {}
merge(M.ALL_CC, M.HARD_CC)
merge(M.ALL_CC, M.ROOTS)
merge(M.ALL_CC, M.SILENCES)
merge(M.ALL_CC, M.DISARMS)

-- ─────────────────────────────────────────────────────────────────────
-- Predicate helpers — pass a spell ID, get a bool.
-- ─────────────────────────────────────────────────────────────────────

function M.IsRoot(id) return id and M.ROOTS[id] ~= nil end

function M.IsSlow(id) return id and M.SLOWS[id] ~= nil end

function M.IsSnare(id) return id and M.SNARES[id] ~= nil end

function M.IsStun(id) return id and M.STUNS[id] ~= nil end

function M.IsIncapacitate(id) return id and M.INCAPACITATES[id] ~= nil end

function M.IsFear(id) return id and M.FEARS[id] ~= nil end

function M.IsSilence(id) return id and M.SILENCES[id] ~= nil end

function M.IsDisarm(id) return id and M.DISARMS[id] ~= nil end

function M.IsHardCC(id) return id and M.HARD_CC[id] ~= nil end

function M.IsCC(id) return id and M.ALL_CC[id] ~= nil end

-- Returns the human-readable name for a known classified spell ID, or
-- nil if the ID isn't in any of our category tables. Useful for logging.
function M.GetName(id)
  if not id then return nil end
  return M.SNARES[id] or M.HARD_CC[id] or M.SILENCES[id] or M.DISARMS[id]
end

-- ─────────────────────────────────────────────────────────────────────
-- Unit helpers — scan a Aegis Unit's aura array directly.
-- These are the primary API behaviors should consume.
-- ─────────────────────────────────────────────────────────────────────

local function scan(unit, predicate)
  if not unit or not unit.Auras then return false, nil end
  local auras = unit.Auras
  for i = 1, #auras do
    local a = auras[i]
    if a and a.is_harmful and a.spell_id and predicate(a.spell_id) then
      return true, a
    end
  end
  return false, nil
end

function M.UnitHasSnare(unit)
  local has = scan(unit, M.IsSnare); return has
end

function M.UnitHasRoot(unit)
  local has = scan(unit, M.IsRoot); return has
end

function M.UnitHasSlow(unit)
  local has = scan(unit, M.IsSlow); return has
end

function M.UnitHasStun(unit)
  local has = scan(unit, M.IsStun); return has
end

function M.UnitHasIncapacitate(unit)
  local has = scan(unit, M.IsIncapacitate); return has
end

function M.UnitHasFear(unit)
  local has = scan(unit, M.IsFear); return has
end

function M.UnitHasSilence(unit)
  local has = scan(unit, M.IsSilence); return has
end

function M.UnitHasDisarm(unit)
  local has = scan(unit, M.IsDisarm); return has
end

function M.UnitHasHardCC(unit)
  local has = scan(unit, M.IsHardCC); return has
end

function M.UnitHasAnyCC(unit)
  local has = scan(unit, M.IsCC); return has
end

-- "Has snare AND it's of a dispel type the given class can remove."
-- Used by behaviors to decide between "cleanse the slow" vs "freedom
-- through it." classKey is the uppercase token: "PALADIN", "DRUID", etc.
function M.UnitHasCleanseableSnare(unit, classKey)
  if not unit or not unit.Auras then return false end
  local removable = M.CLASS_DISPELS[classKey]
  if not removable then return false end
  for _, a in ipairs(unit.Auras) do
    if a.is_harmful and a.spell_id and M.IsSnare(a.spell_id) then
      local dt = a.dispel_type
      if (not dt) and game and game.spell_dispel_type then
        local ok, v = pcall(game.spell_dispel_type, a.spell_id)
        if ok then dt = v end
      end
      if dt and removable[dt] then return true end
    end
  end
  return false
end

return M
