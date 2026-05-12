-- Encounter-aware friendly dispel data for TBC PvE.

local MAGIC = 1
local CURSE = 2
local DISEASE = 3
local POISON = 4

return {
  DispelTypes = {
    Magic = MAGIC,
    Curse = CURSE,
    Disease = DISEASE,
    Poison = POISON,
  },

  FriendlyDispels = {
    {
      names = { "Holy Fire" },
      types = { MAGIC },
      priority = 90,
      tags = { "karazhan", "raid", "high_damage" },
      source = "Karazhan / Maiden matrix row",
    },
    {
      names = { "Polymorph", "Greater Polymorph" },
      types = { MAGIC },
      priority = 95,
      tags = { "sethekk_halls", "magisters_terrace", "cc" },
      source = "Sethekk Halls and Magister's Terrace matrix rows",
    },
    {
      names = { "Slow" },
      types = { MAGIC },
      priority = 75,
      tags = { "sethekk_halls", "mobility" },
      source = "Sethekk Halls matrix row",
    },
    {
      names = { "Arcane Shock" },
      types = { MAGIC },
      priority = 85,
      tags = { "magisters_terrace", "damage" },
      source = "Magister's Terrace matrix row",
    },
    {
      names = { "Static Charge" },
      types = { MAGIC },
      priority = 70,
      tags = { "underbog", "damage" },
      source = "Underbog matrix row",
    },
    {
      names = { "Shadow Word: Pain" },
      types = { MAGIC },
      priority = 65,
      tags = { "raid", "damage" },
      source = "Tempest Keep / Sunwell caster debuff matrix rows",
    },
    {
      names = { "Doom" },
      types = { MAGIC },
      priority = 100,
      tags = { "hyjal", "wipe" },
      source = "Hyjal Summit Archimonde/Azgalor matrix row",
    },
    {
      names = { "Frostbolt", "Frost Shock" },
      types = { MAGIC },
      priority = 60,
      tags = { "trash", "movement" },
      source = "Dungeon caster trash rows",
    },
    {
      names = { "Curse of Tongues" },
      types = { CURSE },
      priority = 85,
      tags = { "caster", "healer" },
      source = "TBC caster trash utility taxonomy",
    },
    {
      names = { "Curse of Doom" },
      types = { CURSE },
      priority = 95,
      tags = { "raid", "high_damage" },
      source = "TBC raid curse utility taxonomy",
    },
    {
      names = { "Curse of the Violet Tower" },
      types = { CURSE },
      priority = 80,
      tags = { "karazhan", "damage" },
      source = "Karazhan matrix row",
    },
    {
      names = { "Curse of Mending" },
      types = { CURSE },
      priority = 75,
      tags = { "dungeon", "healing_reduction" },
      source = "TBC dungeon curse utility taxonomy",
    },
    {
      names = { "Poison Bolt Volley" },
      types = { POISON },
      priority = 90,
      tags = { "slave_pens", "serpentshrine_cavern", "aoe" },
      source = "Slave Pens / SSC matrix rows",
    },
    {
      names = { "Acid Spray" },
      types = { POISON },
      priority = 85,
      tags = { "slave_pens", "armor_reduction" },
      source = "Slave Pens matrix row",
    },
    {
      names = { "Allergic Reaction" },
      types = { POISON },
      priority = 70,
      tags = { "botanica", "damage" },
      source = "Botanica matrix row",
    },
    {
      names = { "Deadly Poison", "Crippling Poison", "Mind-numbing Poison", "Tainted Poison" },
      types = { POISON },
      priority = 65,
      tags = { "dungeon", "trash" },
      source = "Dungeon poison utility taxonomy",
    },
    {
      names = { "Disease Cloud", "Putrid Bite", "Fevered Disease", "Diseased Shot" },
      types = { DISEASE },
      priority = 75,
      tags = { "steamvault", "dungeon" },
      source = "Steamvault / dungeon disease matrix rows",
    },
  },

  BlockedDispels = {
    {
      names = { "Unstable Affliction" },
      types = { MAGIC },
      reason = "dispelling punishes the dispeller",
      source = "Warlock-style hostile debuff safety rule",
    },
    {
      names = { "Burn" },
      types = { MAGIC },
      reason = "Brutallus Burn is assignment/positioning sensitive",
      source = "Sunwell Brutallus matrix row",
    },
    {
      names = { "Conflagration" },
      types = { MAGIC },
      reason = "Eredar Twins Conflagration is positioning/strategy sensitive",
      source = "Sunwell Eredar Twins matrix row",
    },
    {
      names = { "Flame Touched", "Dark Touched" },
      types = { MAGIC },
      reason = "Eredar Twins touch stacks are strategy dependent",
      source = "Sunwell Eredar Twins matrix row",
    },
  },
}
