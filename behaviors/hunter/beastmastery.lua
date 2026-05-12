local PET_FOOD_UID         = "HunterPetFood"
local PET_FOOD_DEFAULT     = "Haunch of Meat"
local CLAW_POWER_THRESHOLD = 40

local options              = {
    Name = "Hunter (Beastmastery)",
    Widgets = {
        {
            type = "custom",
            draw = function() Pet.DrawFoodPicker(PET_FOOD_UID, PET_FOOD_DEFAULT, "Pet food") end
        },
    },
}

-- Find enemy in Combat.Targets currently targeting the player.
local function FindPeelTarget()
    if not Me or not Me.Guid or not Combat or not Combat.Targets then return nil end
    local me_guid = Me.Guid
    local pet = Pet.GetPrimary()
    local best, best_dist
    for _, enemy in pairs(Combat.Targets) do
        local t = enemy and enemy.GetTarget and enemy:GetTarget()
        if t and t.Guid == me_guid then
            if not pet or not pet.GetDistance then return enemy end
            local d = pet:GetDistance(enemy)
            if not best_dist or d < best_dist then
                best, best_dist = enemy, d
            end
        end
    end
    return best
end

local function ChoosePetTarget(peel)
    return peel or Combat.BestTarget
end

-- Send the pet at `desired` only when it isn't already on it.
local function CommandPet(desired)
    if not desired or not Pet.HasPet() or Pet:IsDead() then return end
    local current = Pet.GetTarget()
    local stale = not current or current.Guid == "" or current.Guid ~= desired.Guid
        or current.IsDead or (current.Health or 0) <= 0
    if stale then Pet.Attack(desired) end
end

local function HandlePetActions(target, peel)
    if not Pet:HasPet() or Pet:IsDead() or not target then return end

    local pet = Pet.GetPrimary()
    if not pet or not pet.InMeleeRange or not pet:InMeleeRange(target) then return end

    if peel and Pet.IsActionReady("Growl") then
        Pet.CastAction("Growl")
        return
    end

    local power = (pet.Powers and pet.Powers[0]) or 0
    if power >= CLAW_POWER_THRESHOLD and Pet.IsActionReady("Claw") then
        Pet.CastAction("Claw")
    end
end

-- Out-of-combat upkeep: feed the pet when happiness drops below 125%.
local function DoRest()
    if not Me or Me.InCombat then return end
    if not Pet:HasPet() or Pet:IsDead() then return end
    local h = Pet.Happiness()
    if not h or h.damage_pct >= 125 then return end
    Pet.Feed(Pet.SelectedFood(PET_FOOD_UID, PET_FOOD_DEFAULT))
end

local function DoCombat()
    if not Me:HasAura("Aspect of the Hawk") then
        if Spell.AspectOfTheHawk:CastEx(Me) then return end
    end

    local petAlive = not Pet:IsDead()
    local hasPet = petAlive and Pet:HasPet()
    local thePet = Pet.GetPrimary()

    if not petAlive and not Me.InCombat then
        if Spell.RevivePet:CastEx() then return end
    end

    if not hasPet then
        if Spell.CallPet:CastEx() then return end
    end

    if thePet and Pet:InCombat() and thePet.HealthPct < 90 and not thePet:HasAura("Mend Pet") then
        if Spell.MendPet:CastEx() then return end
    end

    local target = Combat.BestTarget
    if not target then return end

    local peel = FindPeelTarget()
    CommandPet(ChoosePetTarget(peel))

    HandlePetActions(target, peel)

    if Spell:IsGCDActive() then return end

    if not Me:InMeleeRange(target) then
        if not target:HasAura("Hunter's Mark") and Spell.HuntersMark:CastEx(target) then return end
    end

    if Me:InMeleeRange(target) then
        if Spell.RaptorStrike:CastEx(target) then return end
        if not Me:IsAutoAttacking() and Me:StartAttack(target) then return end
    else
        if not Me:IsAutoRanging() and Me:StartRanging(target) then return end
        if target:GetTarget() and target:GetTarget().Guid == Me.Guid and Spell.ConcussiveShot:CastEx(target) then return end
    end
end

local behaviors = {
    [BehaviorType.Combat] = DoCombat,
    [BehaviorType.Rest]   = DoRest,
}

return { Options = options, Behaviors = behaviors }
