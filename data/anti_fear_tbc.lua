-- Encounter-aware anti-fear and prevention data for TBC PvE.

local M = {}

local TREMOR = "tremor"
local FEAR_WARD = "fear_ward"
local GROUNDING = "grounding"

M.Actions = {
  Tremor = TREMOR,
  FearWard = FEAR_WARD,
  Grounding = GROUNDING,
}

M.FearMechanics = {
  {
    names = {
      "Bonechewer Beastmaster", "Lieutenant Drake", "Sethekk Prophet",
      "Coilfang Siren", "Fel Overseer", "Sunblade Warlock",
    },
    actions = { TREMOR, FEAR_WARD },
    priority = 80,
    tags = { "dungeon", "trash", "fear" },
    source = "TBC PvE utility matrix fear-break dungeon rows",
  },
  {
    names = {
      "Ambassador Hellmaw", "Blackheart the Inciter", "Talon King Ikiss",
      "Nightbane", "Maiden of Virtue", "Moroes",
    },
    actions = { TREMOR, FEAR_WARD },
    priority = 90,
    guarded = true,
    tags = { "boss", "fear" },
    source = "TBC PvE utility matrix guarded boss fear rows",
  },
  {
    names = {
      "Azgalor", "Archimonde", "Hex Lord Malacrass", "Zul'jin",
    },
    actions = { TREMOR, FEAR_WARD },
    priority = 95,
    guarded = true,
    tags = { "raid", "fear" },
    source = "TBC PvE utility matrix raid fear rows",
  },
}

M.ContextFear = {
  {
    names = {
      "Hellfire Ramparts", "Old Hillsbrad Foothills", "Sethekk Halls",
      "Shadow Labyrinth", "The Steamvault", "Magister's Terrace",
      "Karazhan", "Hyjal Summit", "Zul'Aman",
    },
    actions = { TREMOR, FEAR_WARD },
    priority = 65,
    guarded = true,
    source = "TBC PvE utility matrix repeated-fear instance rows",
  },
}

M.GroundingMechanics = {
  {
    spell_names = {
      "Fear", "Psychic Scream", "Polymorph", "Spell Lock",
      "Fireball", "Frostbolt", "Shadow Bolt", "Pyroblast",
    },
    action = GROUNDING,
    priority = 80,
    tags = { "single_target", "harmful_cast" },
    source = "TBC PvE utility matrix guarded Grounding Totem rows",
  },
}

M.ManualOnly = {
  {
    names = {
      "The Black Stalker", "Shade of Aran", "Netherspite",
      "Archimonde", "Illidan Stormrage",
    },
    reason = "Positioning/assignment mechanics are unsafe for blind automation",
    source = "TBC PvE utility matrix manual-only positioning rows",
  },
}

return M
