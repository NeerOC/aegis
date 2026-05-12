-- Combat targeting system (mirrors Aegis system/combat.lua).

---@class Combat : Targeting
---@field BestTarget Unit|nil Highest priority enemy this tick.
---@field EnemiesInMeleeRange number Count of enemies currently in melee range.
---@field Enemies number Total count of enemies considered this tick.
Combat                     = Combat or Targeting:New()

Combat.BestTarget          = nil
Combat.EnemiesInMeleeRange = 0
Combat.Enemies             = 0

local TTD_WINDOW_S         = 5.0
local TTD_STALE_S          = 30.0
local TTD_GC_S             = 10.0

Combat._ttd_samples        = Combat._ttd_samples or {}
Combat._ttd_last_seen      = Combat._ttd_last_seen or {}
Combat._ttd_gc_at          = Combat._ttd_gc_at or 0

function Combat:RefreshTTD()
  local now       = os.clock()
  local samples   = self._ttd_samples
  local last_seen = self._ttd_last_seen
  local cutoff    = now - TTD_WINDOW_S

  for _, u in ipairs(self.Targets) do
    local guid = u and u.Guid
    if guid and guid ~= "" then
      local hp = u.Health or 0
      if hp > 0 then
        local buf = samples[guid]
        local prev = buf and buf[#buf]
        if not buf or (prev and hp > prev[2]) then
          buf = {}
          samples[guid] = buf
        end
        buf[#buf + 1] = { now, hp }
        while buf[1] and buf[1][1] < cutoff do
          table.remove(buf, 1)
        end
        last_seen[guid] = now
      end
    end
  end

  if now >= self._ttd_gc_at then
    self._ttd_gc_at = now + TTD_GC_S
    local stale_before = now - TTD_STALE_S
    for guid, t in pairs(last_seen) do
      if t < stale_before then
        samples[guid]   = nil
        last_seen[guid] = nil
      end
    end
  end
end

-- Seconds until this GUID dies at the current observed DPS.
function Combat:TimeToDeath(guid)
  if not guid or guid == "" then return math.huge end
  local buf = self._ttd_samples[guid]
  if not buf or #buf < 2 then return math.huge end
  local first, last = buf[1], buf[#buf]
  local dt          = last[1] - first[1]
  local dhp         = first[2] - last[2]
  if dt <= 0 or dhp <= 0 then return math.huge end
  return last[2] / (dhp / dt)
end

function Combat:Update()
  Targeting.Update(self)
  self:RefreshTTD()
end

function Combat:Reset()
  self.BestTarget          = nil
  self.EnemiesInMeleeRange = 0
  self.Enemies             = 0
  self.Targets             = {}
end

function Combat:WantToRun()
  if not Behavior:HasBehavior(BehaviorType.Combat) then return false end
  if not Me then return false end
  if Me.IsMounted then return false end
  return AegisSettings.AegisAttackOOC or Me.InCombat
end

function Combat:CollectTargets()
  if not Me.InCombat and AegisSettings.AegisAttackOOC then
    local tgt = Me.Target
    if tgt and tgt:validTarget() then
      self.Targets[#self.Targets + 1] = tgt
    end

    return
  end

  local entities = Aegis._entity_cache or {}
  local mx, my, mz
  if Me.Position then
    mx, my, mz = Me.Position.x, Me.Position.y, Me.Position.z
  end

  for _, e in ipairs(entities) do
    local cls = e.class
    if cls ~= "Unit" and cls ~= "Player" then goto skip end

    local eu = e.unit
    if not eu then goto skip end
    if eu.is_dead then goto skip end
    if eu.health and eu.health <= 0 then goto skip end
    if not eu.in_combat then
      local is_current_target = Me.Target and Me.Target.Guid == eu.guid
      if not (AegisSettings.AegisAttackOOC and is_current_target) then
        goto skip
      end
    end
    if not game.unit_can_attack(e.obj_ptr) then goto skip end

    if mx and e.position then
      local dx = mx - e.position.x
      local dy = my - e.position.y
      local dz = mz - e.position.z
      if dx * dx + dy * dy + dz * dz > 1600 then goto skip end
    end

    self.Targets[#self.Targets + 1] = Unit:New(e)

    ::skip::
  end
end

function Combat:ExclusionFilter()
  local my_tgt_guid = Me.Target and Me.Target.Guid or ""
  local me_guid     = Me and Me.Guid or ""
  local pet_guid    = (Pet and Pet.PrimaryGuid and Pet.PrimaryGuid()) or ""
  local keep        = {}
  for _, u in ipairs(self.Targets) do
    if not u or not u:validTarget() then goto skip_ex end

    if not u:IsAttackable() then goto skip_ex end
    if u:DeadOrGhost() or u.Health <= 1 then goto skip_ex end
    if Me:GetDistance(u) >= 40 then goto skip_ex end

    if u.Guid == my_tgt_guid and AegisSettings.AegisAttackOOC then
      keep[#keep + 1] = u
      goto skip_ex
    end

    if not u:isUnitInCombatWithPartyOrMe() then
      goto skip_ex
    end

    if u:IsTapDenied() then
      local et = u:GetTarget()
      local etg = et and et.Guid or ""
      if etg ~= me_guid and (pet_guid == "" or etg ~= pet_guid) then
        goto skip_ex
      end
    end

    keep[#keep + 1] = u
    ::skip_ex::
  end
  self.Targets = keep
end

function Combat:InclusionFilter()
  if not AegisSettings.AegisAttackTarget then return end

  if not Me.InCombat and AegisSettings.AegisAttackOOC then return end

  local tgt = Me.Target
  if not tgt then return end

  for _, u in ipairs(self.Targets) do
    if u.Guid == tgt.Guid then return end
  end

  if not tgt:validTarget() then return end
  self.Targets[#self.Targets + 1] = tgt
end

function Combat:WeighFilter()
  local priority_list = {}
  local tgt_guid = Me.Target and Me.Target.Guid or ""
  for _, u in ipairs(self.Targets) do
    local priority = 0
    self.Enemies = self.Enemies + 1

    if Me:InMeleeRange(u) then
      self.EnemiesInMeleeRange = self.EnemiesInMeleeRange + 1
    end

    if tgt_guid == u.Guid then
      priority = priority + 50
    end

    priority_list[#priority_list + 1] = { Unit = u, Priority = priority }
  end

  table.sort(priority_list, function(a, b) return a.Priority > b.Priority end)
  if #priority_list == 0 then return end

  self.BestTarget = priority_list[1].Unit
end

function Combat:GetEnemiesWithinDistance(dist)
  local count = 0
  for _, u in ipairs(self.Targets) do
    if Me:GetDistance(u) <= dist then count = count + 1 end
  end
  return count
end

function Combat:GetTargetsAround(unit, distance)
  local count = 0
  for _, u in ipairs(self.Targets) do
    if unit:GetDistance(u) <= distance then count = count + 1 end
  end
  return count
end

return Combat
