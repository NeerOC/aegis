-- Group role constants (mirrors Aegis common/group.lua)

GroupRole = {
  None   = 0x0,
  Tank   = 0x2,
  Healer = 0x4,
  Damage = 0x8,
}

UnitReaction = {
  Hated      = 1,
  Hostile    = 2,
  Unfriendly = 3,
  Neutral    = 4,
  Friendly   = 5,
  Honored    = 6,
  Revered    = 7,
  Exalted    = 8,
}

return GroupRole
