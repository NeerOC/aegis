-- TBC 2.5.x class table.

local CLASS_MAP = {
  [1]  = "Warrior",
  [2]  = "Paladin",
  [3]  = "Hunter",
  [4]  = "Rogue",
  [5]  = "Priest",
  [7]  = "Shaman",
  [8]  = "Mage",
  [9]  = "Warlock",
  [11] = "Druid",
}

local SPEC_MAP = {
  warrior = { "Arms", "Fury", "Protection" },
  paladin = { "Holy", "Protection", "Retribution" },
  hunter  = { "Beast Mastery", "Marksmanship", "Survival" },
  rogue   = { "Assassination", "Combat", "Subtlety" },
  priest  = { "Discipline", "Holy", "Shadow" },
  shaman  = { "Elemental", "Enhancement", "Restoration" },
  mage    = { "Arcane", "Fire", "Frost" },
  warlock = { "Affliction", "Demonology", "Destruction" },
  druid   = { "Balance", "Feral", "Restoration" },
}

local function class_key(class_id)
  local name = CLASS_MAP[class_id]
  if not name then return nil end
  return name:gsub("%s+", ""):lower()
end

return {
  CLASS_MAP = CLASS_MAP,
  SPEC_MAP  = SPEC_MAP,
  class_key = class_key,
}
