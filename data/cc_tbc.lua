-- Encounter-aware crowd-control and add-priority data for TBC PvE.

local M = {}

local POLYMORPH = "polymorph"
local SAP = "sap"
local FREEZING_TRAP = "freezing_trap"
local BANISH = "banish"
local FEAR = "fear"
local SEDUCE = "seduce"
local SHACKLE = "shackle"
local HIBERNATE = "hibernate"
local TURN_EVIL = "turn_evil"

M.Actions = {
  Polymorph = POLYMORPH,
  Sap = SAP,
  FreezingTrap = FREEZING_TRAP,
  Banish = BANISH,
  Fear = FEAR,
  Seduce = SEDUCE,
  Shackle = SHACKLE,
  Hibernate = HIBERNATE,
  TurnEvil = TURN_EVIL,
}

M.CreatureTypes = {
  Beast = 1,
  Dragonkin = 2,
  Demon = 3,
  Elemental = 4,
  Giant = 5,
  Undead = 6,
  Humanoid = 7,
  Critter = 8,
  Mechanical = 9,
  Totem = 11,
}

M.Candidates = {
  {
    names = {
      "Hellfire Watcher", "Bleeding Hollow Darkcaster",
      "Shadowmoon Summoner", "Shadowmoon Technician",
      "Ethereal Priest", "Ethereal Sorcerer", "Ethereal Spellbinder",
      "Auchenai Soulpriest", "Auchenai Vindicator",
      "Durnholde Rifleman", "Durnholde Warden", "Durnholde Mage",
      "Sethekk Oracle", "Sethekk Prophet", "Sethekk Ravenguard",
      "Cabal Acolyte", "Cabal Summoner", "Cabal Spellbinder",
      "Bloodwarder Mender", "Sunseeker Channeler",
      "Sunseeker Astromage", "Bloodwarder Slayer",
      "Shattered Hand Legionnaire", "Shattered Hand Sharpshooter", "Shadowmoon Acolyte",
      "Coilfang Siren", "Coilfang Oracle",
      "Sunblade Mage Guard", "Sunblade Blood Knight", "Sunblade Warlock",
      "Amani'shi Medicine Man", "Amani'shi Flame Caster",
    },
    actions = { POLYMORPH, SAP, FREEZING_TRAP, FEAR, SEDUCE },
    creature_types = { M.CreatureTypes.Humanoid },
    priority = 70,
    tags = { "dungeon", "trash", "humanoid", "interrupt", "cc" },
    source = "TBC PvE utility matrix humanoid caster/trash CC rows",
  },
  {
    names = {
      "Unbound Devastator", "Burning Abyssal", "Hellfire Channeler",
      "Illidari Battle-Mage", "Shadowsword Fury Mage",
    },
    actions = { BANISH, FEAR, SEDUCE },
    creature_types = { M.CreatureTypes.Demon, M.CreatureTypes.Elemental },
    priority = 85,
    tags = { "demon", "elemental", "raid", "guarded", "cc" },
    guarded = true,
    source = "Arcatraz, Magtheridon, Black Temple, and Sunwell matrix rows",
  },
  {
    names = {
      "Phantom Valet", "Spectral Retainer", "Ghoul", "Crypt Fiend",
      "Necromancer", "Shadowfiend",
    },
    actions = { SHACKLE, TURN_EVIL },
    creature_types = { M.CreatureTypes.Undead },
    priority = 80,
    tags = { "undead", "raid", "trash", "cc" },
    guarded = true,
    source = "Karazhan, Hyjal, and Black Temple matrix rows",
  },
  {
    names = { "Amani Bear", "Bonechewer Beastmaster", "Coilfang Champion" },
    actions = { HIBERNATE, FREEZING_TRAP, FEAR, SEDUCE },
    creature_types = { M.CreatureTypes.Beast, M.CreatureTypes.Humanoid },
    priority = 60,
    tags = { "beast", "dungeon", "guarded", "cc" },
    guarded = true,
    source = "Zul'Aman and dungeon trash CC rows",
  },
}

M.Blocked = {
  {
    names = {
      "High King Maulgar", "Kiggler the Crazed", "Blindeye the Seer",
      "Olm the Summoner", "Krosh Firehand", "Priestess Delrissa",
    },
    reason = "Boss/council/PvP-style assignments are manual-sensitive",
    source = "Gruul's Lair and Magister's Terrace matrix rows",
  },
}

M.AddPriority = {
  {
    names = {
      "Mennu's Healing Ward", "Ethereal Beacon", "Phantasmal Possessor",
      "Rift Lord", "Rift Keeper", "Frayer Protector", "Pure Energy",
      "Fiendish Imp", "Burning Abyssal", "Tainted Elemental",
      "Coilfang Strider", "Phoenix-Hawk Hatchling", "Dark Fiend",
      "Void Sentinel",
    },
    priority = 90,
    tags = { "add_priority", "wipe" },
    source = "TBC PvE utility matrix add-priority rows",
  },
  {
    names = {
      "Shattered Hand Legionnaire", "Amani'shi Scout", "Ghoul",
      "Crypt Fiend", "Frost Wyrm",
    },
    priority = 75,
    tags = { "add_priority", "wave" },
    source = "Shattered Halls, Zul'Aman, and Hyjal add/wave rows",
  },
}

return M
