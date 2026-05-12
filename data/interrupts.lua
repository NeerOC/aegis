local interrupts = {
  118,
  116,
  133,
  11366,
  12051,
  339,
  2637,
  29166,
  5176,
  2912,
  635,
  19750,
  2060,
  2050,
  8092,
  605,
  8129,
  403,
  421,
  8004,
  331,
  686,
  348,
  1949,
  710,
  5782,
  30451,
  30108,
  27243,

  EncounterInterrupts = {
    -- Dungeon casts from the TBC PvE utility matrix. Prefer ids when verified;
    -- names are intentionally present as fallbacks because creature spell IDs
    -- vary by rank/version more often than names do.
    { ids = { 30528 }, names = { "Dark Mending" }, tags = { "heal", "wipe" }, priority = 100, source = "Wowhead TBC spell 30528; Magtheridon Hellfire Channelers" },
    { ids = { 36275 }, names = { "Shadow Bolt Volley", "Shadow Volley" }, tags = { "aoe" }, priority = 80, source = "Wowhead TBC spell 36275; Magtheridon Hellfire Channelers" },
    { ids = { 33502 }, names = { "Brain Wash" }, tags = { "mind_control", "wipe" }, priority = 100, source = "Wowhead TBC spell 33502; Shadow Labyrinth Cabal Spellbinder" },

    { names = { "Heal", "Greater Heal", "Lesser Heal", "Flash Heal", "Dark Heal", "Dark Mending" }, tags = { "heal" }, priority = 90, source = "TBC dungeon/raid matrix healer mobs" },
    { names = { "Prayer of Healing", "Circle of Healing", "Holy Light" }, tags = { "heal", "aoe" }, priority = 95, source = "TBC dungeon/raid matrix healer mobs" },
    { names = { "Renew", "Rejuvenation" }, tags = { "heal" }, priority = 55, source = "TBC dungeon/raid matrix healer mobs" },

    { names = { "Summon Abyssal", "Summon Imp", "Summon Voidwalker", "Summon Felhunter", "Summon Succubus", "Summon Demon" }, tags = { "summon", "add_priority" }, priority = 80, source = "Magtheridon and dungeon summoner rows" },
    { names = { "Mind Control", "Domination", "Seduction", "Charm", "Possess" }, tags = { "mind_control", "cc" }, priority = 100, source = "Shadow Labyrinth, Mechanar, Tempest Keep rows" },
    { names = { "Mana Burn", "Arcane Shock", "Spell Shock", "Earth Shock" }, tags = { "caster", "interrupt" }, priority = 75, source = "Mana-Tombs, Magister's Terrace, Shadow Labyrinth rows" },

    { names = { "Shadow Bolt", "Shadow Bolt Volley", "Shadow Volley", "Shadow Nova" }, tags = { "aoe", "caster" }, priority = 70, source = "Magtheridon, Shadow Labyrinth, Black Temple rows" },
    { names = { "Fireball", "Pyroblast", "Flamestrike", "Rain of Fire", "Fel Fireball" }, tags = { "aoe", "caster" }, priority = 70, source = "Karazhan, Tempest Keep, Magister's Terrace, Sunwell rows" },
    { names = { "Frostbolt", "Blizzard", "Chain Lightning", "Lightning Bolt" }, tags = { "aoe", "caster" }, priority = 65, source = "Sethekk, Steamvault, Karazhan, Zul'Aman rows" },
    { names = { "Tranquility" }, tags = { "heal", "channel" }, priority = 90, source = "Botanica High Botanist Freywinn row" },
    { names = { "Drain Life", "Drain Mana", "Drain Soul" }, tags = { "drain", "caster" }, priority = 70, source = "Magister's Terrace and caster trash rows" },

    -- Raid-specific high-value names. These are name fallbacks until IDs are
    -- verified from logs or Wowhead spell pages during later data hardening.
    { names = { "Holy Fire" }, tags = { "dot", "caster" }, priority = 80, source = "Karazhan Maiden row" },
    { names = { "Greater Polymorph", "Polymorph" }, tags = { "cc" }, priority = 80, source = "Magister's Terrace and PvE mage rows" },
    { names = { "Blood Heal", "Fel Rage", "Deadly Poison", "Poison Bolt Volley" }, tags = { "heal", "poison", "caster" }, priority = 70, source = "Dungeon and raid utility matrix" },
    { names = { "Shadow Word: Pain", "Mind Blast", "Smite", "Holy Smite" }, tags = { "caster" }, priority = 60, source = "Priest-style trash rows" },
  },

  RacialInterrupts = {
    WarStomp = {
      ids = { 20549 },
      range = 8,
      aoe = true,
    },
    ArcaneTorrent = {
      ids = { 28730, 25046 },
      range = 8,
      aoe = true,
    },
  },
}

return interrupts
