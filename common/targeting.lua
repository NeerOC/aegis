-- Abstract targeting pipeline (mirrors Aegis common/targeting.lua).

---@class Targeting
---@field Targets Unit[] Current set of enemy targets after filtering.
---@field HealTargets Unit[] Current set of allied units considered for healing.
Targeting = {}
Targeting.__index = Targeting

function Targeting:New(o)
  o             = o or {}
  o.Targets     = {}
  o.HealTargets = {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function Targeting:WantToRun()
  return true
end

function Targeting:Update()
  self:Reset()
  if not self:WantToRun() then return end
  self:CollectTargets()
  self:ExclusionFilter()
  self:InclusionFilter()
  self:WeighFilter()
end

function Targeting:Reset()
  self.Targets     = {}
  self.HealTargets = {}
end

function Targeting:CollectTargets() end

function Targeting:ExclusionFilter() end

function Targeting:InclusionFilter() end

function Targeting:WeighFilter() end

return Targeting
