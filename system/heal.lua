-- Heal targeting system (mirrors Aegis system/heal.lua).

---@class HealFriends
---@field Tanks Unit[]
---@field DPS Unit[]
---@field Healers Unit[]
---@field All Unit[]

---@class Heal : Targeting
---@field PriorityList table[] Sorted list of `{ Unit, Priority }` heal candidates.
---@field Friends HealFriends Friendly units grouped by role.
Heal = Heal or Targeting:New()

Heal.PriorityList = {}
Heal.Friends = {
  Tanks   = {},
  DPS     = {},
  Healers = {},
  All     = {},
}

function Heal:Update()
  Targeting.Update(self)
end

function Heal:Reset()
  self.PriorityList = {}
  self.HealTargets  = {}
  self.Friends = {
    Tanks   = {},
    DPS     = {},
    Healers = {},
    All     = {},
  }
end

function Heal:WantToRun()
  if not Behavior:HasBehavior(BehaviorType.Heal) then return false end
  if not Me then return false end
  if Me.IsMounted then return false end
  return true
end

function Heal:CollectTargets()
  local entities = Aegis._entity_cache or {}

  local heal_set = {}
  if Me and Me.guid_lo and Me.guid_lo ~= 0 then
    heal_set[Me.guid_lo] = true
  end
  local ok_grp, in_group = pcall(game.is_in_group)
  if ok_grp and in_group then
    local ok, roster = pcall(game.group_members)
    if ok and roster then
      for _, m in ipairs(roster) do
        if m.guid_lo and m.guid_lo ~= 0 then
          heal_set[m.guid_lo] = true
        end
      end
    end
  end

  local mx, my, mz
  if Me.Position then
    mx, my, mz = Me.Position.x, Me.Position.y, Me.Position.z
  end

  for _, e in ipairs(entities) do
    local lo = e.guid_lo or 0
    if lo == 0 or not heal_set[lo] then goto skip end

    local eu = e.unit
    if not eu then goto skip end
    if eu.is_dead then goto skip end
    if eu.health and eu.health <= 1 then goto skip end

    if mx and e.position then
      local dx = mx - e.position.x
      local dy = my - e.position.y
      local dz = mz - e.position.z
      if dx*dx + dy*dy + dz*dz > 1600 then goto skip end
    end

    self.HealTargets[#self.HealTargets + 1] = Unit:New(e)
    ::skip::
  end
end

function Heal:ExclusionFilter()
  local keep = {}
  for _, u in ipairs(self.HealTargets) do
    if u and not Me:CanAttack(u) then
      keep[#keep + 1] = u
    end
  end
  self.HealTargets = keep
end

function Heal:InclusionFilter() end

function Heal:WeighFilter()
  local mana_multi = 30
  local ok_grp, in_group = pcall(game.is_in_group)
  in_group = ok_grp and in_group or false
  local members_set = {}

  if in_group then
    local ok, roster = pcall(game.group_members)
    if ok and roster then
      for _, m in ipairs(roster) do
        if m.guid_lo then members_set[m.guid_lo] = m end
      end
    end
  end

  for _, u in ipairs(self.HealTargets) do
    local priority = 0
    local is_tank, is_dps, is_heal = false, false, false

    local member = members_set[u.guid_lo]
    if not member and u.Guid ~= (Me and Me.Guid or "") then goto continue end

    if u:IsTank()   then priority = priority + 20; is_tank = true end
    if u:IsHealer() then priority = priority + 10; is_heal = true end
    if u:IsDPS()    then priority = priority + 5;  is_dps  = true end

    priority = priority + (100 - u.HealthPct)
    priority = priority - ((100 - Me.PowerPct) * (mana_multi / 100))

    if priority > 0 or u.InCombat then
      self.PriorityList[#self.PriorityList + 1] = { Unit = u, Priority = priority }
    end

    if is_tank then
      self.Friends.Tanks[#self.Friends.Tanks + 1] = u
    elseif is_dps then
      self.Friends.DPS[#self.Friends.DPS + 1] = u
    elseif is_heal then
      self.Friends.Healers[#self.Friends.Healers + 1] = u
    end
    self.Friends.All[#self.Friends.All + 1] = u

    ::continue::
  end

  table.sort(self.PriorityList, function(a, b) return a.Priority > b.Priority end)
end

function Heal:GetLowestMember()
  local lowest = nil
  for _, v in ipairs(self.PriorityList) do
    if not lowest or lowest.HealthPct > v.Unit.HealthPct then
      lowest = v.Unit
    end
  end
  return lowest
end

function Heal:GetMembersBelow(pct)
  local members = {}
  for _, v in ipairs(self.PriorityList) do
    if v.Unit.HealthPct < pct then
      members[#members + 1] = v.Unit
    end
  end
  return members, #members
end

function Heal:GetMembersAround(friend, dist, threshold)
  threshold = threshold or 100
  local members = {}
  for _, v in ipairs(self.PriorityList) do
    if friend:GetDistance(v.Unit) <= dist and v.Unit.HealthPct < threshold then
      members[#members + 1] = v.Unit
    end
  end
  return #members, members
end

return Heal
