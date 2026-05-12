-- Range-aware target picker (mirrors MoP's MeleeTarget/RangedTarget).

---@class RangeTarget
local RangeTarget = {}

local function sq_dist_to_me(u)
  if not u or u.IsDead or not u.Position or not Me or not Me.Position then
    return math.huge
  end
  local dx = Me.Position.x - u.Position.x
  local dy = Me.Position.y - u.Position.y
  local dz = Me.Position.z - u.Position.z
  return dx * dx + dy * dy + dz * dz
end

-- Returns the best unit within `range_yd` yards.
function RangeTarget.Find(range_yd, preferred)
  if not Me or not Me.Position then return nil end
  local range_sq = range_yd * range_yd

  if preferred and not preferred.IsDead then
    if sq_dist_to_me(preferred) <= range_sq then return preferred end
  end

  local targets = Combat and Combat.Targets or {}
  for _, t in ipairs(targets) do
    if t and not t.IsDead and sq_dist_to_me(t) <= range_sq then
      return t
    end
  end
  return nil
end

-- Melee variant via Me:InMeleeRange.
function RangeTarget.FindMelee(preferred)
  if not Me then return nil end

  if preferred and not preferred.IsDead and Me:InMeleeRange(preferred) then
    return preferred
  end

  local targets = Combat and Combat.Targets or {}
  for _, t in ipairs(targets) do
    if t and not t.IsDead and Me:InMeleeRange(t) then
      return t
    end
  end
  return nil
end

return RangeTarget
