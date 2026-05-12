local options = {
    Name = "Warlock (Affli)",

    Widgets = {

    },
}
-- Count of live entries in Combat.Targets, plus lowest-Health one.
local function ScanCombatTargets()
    if not Combat or not Combat.Targets then return 0, nil end
    local count, best, best_hp = 0, nil, nil
    for _, u in ipairs(Combat.Targets) do
        local hp = u and u.Health or 0
        if u and not u.IsDead and hp > 0 then
            count = count + 1
            if not best_hp or hp < best_hp then
                best, best_hp = u, hp
            end
        end
    end
    return count, best
end

-- Send the pet at `target` only when it isn't already on it.
local function CommandPet(target)
    if not target or not Pet.HasPet() or Pet:IsDead() then return end
    local pet = Pet.GetPrimary()
    if pet and pet.IsCastingOrChanneling then
        local ok, busy = pcall(pet.IsCastingOrChanneling, pet)
        if ok and busy then return end
    end
    local current = Pet.GetTarget()
    local stale = not current or current.Guid == "" or current.Guid ~= target.Guid
        or current.IsDead or (current.Health or 0) <= 0
    if stale then Pet.Attack(target) end
end

local function DoCombat()
    if Spell:IsGCDActive() or Me:IsEatingOrDrinking() or Me:IsCastingOrChanneling() then return end

    if not Me:HasAura("Demon Skin") and Spell.DemonSkin:CastEx(Me) then return end

    local target = Combat.BestTarget
    if not target then return end

    local count, lowest = ScanCombatTargets()
    CommandPet(count > 1 and lowest or target)

    for _, enemy in pairs(Combat.Targets) do
        if Spell.Corruption:Apply(enemy, 70) then return end
    end

    if not Me:IsAutoWanding() and Me:StartWanding(target) then return end
end


local behaviors = {
    [BehaviorType.Combat] = DoCombat,
}

return { Options = options, Behaviors = behaviors }
