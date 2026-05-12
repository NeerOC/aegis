-- Encounter-aware hostile dispel data for TBC PvE.

local PURGE = "purge"
local DISPEL = "dispel"
local SPELLSTEAL = "spellsteal"

return {
  Actions = {
    Purge = PURGE,
    Dispel = DISPEL,
    Spellsteal = SPELLSTEAL,
  },

  HostileDispels = {
    {
      names = { "Krosh's Fire Ward", "Fire Ward" },
      actions = { SPELLSTEAL },
      priority = 100,
      tags = { "gruuls_lair", "maulgar", "spellsteal_only", "wipe" },
      source = "Gruul's Lair High King Maulgar matrix row",
    },
    {
      names = { "Spell Fury" },
      actions = { SPELLSTEAL, PURGE, DISPEL },
      priority = 100,
      tags = { "sunwell", "muru", "wipe", "caster_damage" },
      source = "Sunwell M'uru matrix row",
    },
    {
      names = { "Magic Shield", "Damage Shield", "Protective Bubble" },
      actions = { SPELLSTEAL, PURGE, DISPEL },
      priority = 90,
      tags = { "mechanar", "trash", "shield" },
      source = "Mechanar matrix row",
    },
    {
      names = { "Haste", "Time Lapse", "Time Step" },
      actions = { PURGE, DISPEL },
      priority = 85,
      tags = { "black_morass", "boss", "tank_damage" },
      source = "Black Morass Temporus/Aeonus matrix row",
    },
    {
      names = { "Enrage", "Frenzy" },
      actions = { PURGE, DISPEL },
      priority = 85,
      tags = { "dungeon", "boss", "tank_damage" },
      source = "Mechanar / Steamvault matrix rows",
    },
    {
      names = { "Power Word: Shield", "Renew", "Prayer of Mending" },
      actions = { PURGE, DISPEL, SPELLSTEAL },
      priority = 80,
      tags = { "pvp_style", "healer", "magisters_terrace" },
      source = "Magister's Terrace Delrissa matrix row",
    },
    {
      names = { "Blessing of Protection", "Blessing of Freedom", "Blessing of Might", "Blessing of Wisdom", "Blessing of Kings" },
      actions = { PURGE, DISPEL, SPELLSTEAL },
      priority = 75,
      tags = { "pvp_style", "magisters_terrace" },
      source = "Magister's Terrace Delrissa matrix row",
    },
    {
      names = { "Fel Infusion", "Fel Strength", "Shadow Infusion", "Arcane Infusion" },
      actions = { PURGE, DISPEL, SPELLSTEAL },
      priority = 75,
      tags = { "dungeon", "trash", "damage_buff" },
      source = "TBC dungeon caster trash utility taxonomy",
    },
    {
      names = { "Bloodlust", "Heroism" },
      actions = { PURGE, DISPEL, SPELLSTEAL },
      priority = 80,
      tags = { "pvp_style", "zulaman", "magisters_terrace" },
      source = "Zul'Aman / Magister's Terrace matrix rows",
    },
  },

  BlockedDispels = {
    {
      names = { "Polarity Shift", "Positive Charge", "Negative Charge" },
      reason = "Mechanic is positioning/assignment-sensitive, not a dispel target",
      source = "Mechanar Capacitus matrix row",
    },
    {
      names = { "Pyroblast Shield", "Nether Vapor" },
      reason = "Kael'thas legendary weapon and strategy mechanics are manual-sensitive",
      source = "Tempest Keep Kael'thas matrix row",
    },
  },
}
