---@meta

-- Player wrapper — extends Unit with player-specific functionality.

---@class Player : Unit
local Player = {}
Player.__index = Player
setmetatable(Player, { __index = Unit })

function Player:New(entity)
  local unit = Unit:New(entity)
  if not unit then
    return nil
  end

  setmetatable(unit, Player)

  return unit
end

---@return boolean - true if the player is auto-attacking, false otherwise
function Player:IsAutoAttacking()
  return game.IsCurrentSpell(6603)
end

---@return boolean - true if the player is auto-ranging, false otherwise
function Player:IsAutoRanging()
  return game.IsAutoRepeatSpell(75)
end

---@return boolean - true if the player is auto-wanding, false otherwise
function Player:IsAutoWanding()
  return game.IsAutoRepeatSpell(5019)
end

function Player:StopCasting()
  game.stop_casting()
end

---@param target Unit - The unit to target
---@return boolean - true if the target was set successfully
function Player:SetTarget(target)
  if not target or not target.obj_ptr then
    return false
  end
  local ok, result = pcall(game.set_target, target.obj_ptr)
  return ok and result or false
end

function Player:ClearTarget()
  pcall(game.clear_target)
end

---@return Unit|nil - Focus-frame unit, or nil if no focus set
function Player:GetFocus()
  local ok, t = pcall(game.focus)
  if not ok or not t or not t.obj_ptr then
    return nil
  end
  local entities = Aegis and Aegis._entity_cache or {}
  for _, e in ipairs(entities) do
    if e.obj_ptr == t.obj_ptr then
      return Unit:New(e)
    end
  end
  return Unit:New(t)
end

---@param target Unit - The target to attack
---@return boolean - true if the attack was started, false otherwise
function Player:StartAttack(target)
  return Spell.Attack:CastEx(target)
end

---@param target Unit - The target to range
---@return boolean - true if the range was started, false otherwise
function Player:StartRanging(target)
  if os.clock() < (Aegis._autorepeat_suppress_until or 0) then return false end
  return Spell.AutoShot:CastEx(target)
end

---@param target Unit - The target to wand
---@return boolean - true if the wanding was started, false otherwise
function Player:StartWanding(target)
  if os.clock() < (Aegis._autorepeat_suppress_until or 0) then return false end
  return not Me:IsMoving() and Spell.Shoot:CastEx(target)
end

---@return boolean - true if the player is eating or drinking, false otherwise
function Player:IsEatingOrDrinking()
  return Me:HasAura("Drink") or Me:HasAura("Food")
      or Me:HasAura("Food & Drink")
end

function Player:InGroup()
  local ok_grp, in_group = pcall(game.is_in_group)
  if ok_grp and in_group then
    return true
  end
end

function Player:IsInOurPartyOrRaid()
  local ok, roster = pcall(game.group_members)
  if ok and roster then
    for _, m in ipairs(roster) do
      if m.guid_lo == self.Guid then
        return true
      end
    end
  end
end

return Player
