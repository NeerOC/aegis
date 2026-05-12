-- Guarded defensive and threat utility data for TBC PvE.

local M = {}

M.DangerousSources = {
  {
    names = {
      "Keli'dan the Breaker", "Quagmirran", "Exarch Maladaar",
      "Temporus", "Aeonus", "Felguard Annihilator", "Death Watcher",
      "Priestess Delrissa", "Kael'thas Sunstrider",
    },
    priority = 80,
    guarded = true,
    tags = { "dungeon", "defensive" },
    source = "TBC PvE utility matrix guarded dungeon defensive rows",
  },
  {
    names = {
      "Azgalor", "Archimonde", "Illidan Stormrage", "Hex Lord Malacrass",
      "Zul'jin", "Kalecgos", "Felmyst", "Grand Warlock Alythess",
      "Lady Sacrolash",
    },
    priority = 90,
    guarded = true,
    tags = { "raid", "defensive" },
    source = "TBC PvE utility matrix guarded raid defensive rows",
  },
}

M.ThreatSensitive = {
  {
    names = {
      "Rift Lord", "Rift Keeper", "Shattered Hand Legionnaire",
      "Necromancer", "Frost Wyrm",
    },
    priority = 75,
    guarded = true,
    tags = { "threat", "pull" },
    source = "TBC PvE utility matrix threat/pull rows",
  },
}

M.ManualOnly = {
  {
    names = {
      "The Black Stalker", "Gruul the Dragonkiller", "Magtheridon",
      "Hydross the Unstable", "The Lurker Below", "Leotheras the Blind",
      "Naj'entus", "Supremus", "Brutallus",
    },
    reason = "Positioning, assignment, or tank-swap mechanics are manual-sensitive",
    source = "TBC PvE utility matrix manual-only defensive rows",
  },
}

return M
