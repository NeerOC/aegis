local options = {
    Name = "Warlock (Affliction)",
    Widgets = {
        { type = "text", text = "Pet & crowd control" },
        { type = "checkbox", text = "Auto pet target (peel / lowest HP)",
          uid = "AffliPetAutoTarget", default = true },
        { type = "checkbox", text = "Voidwalker Torment on threat target",
          uid = "AffliPetTorment", default = true },
        { type = "checkbox", text = "Fear off-target adds",
          uid = "AffliFearAdds", default = true },
    },
}

-- Voidwalker priority: an enemy targeting Me first (tank/peel), else the
-- lowest-HP enemy in combat so the pet helps finish kills. Second return
-- is true when the chosen target is actively attacking Me.
local function PickPetTarget(fallback)
    if not Me or not Combat or not Combat.Targets then return fallback, false end
    local lowest, lowest_hp = nil, nil
    for _, u in ipairs(Combat.Targets) do
        if u and not u.IsDead and (u.Health or 0) > 0 then
            local t = u:GetTarget()
            if t and t.Guid == Me.Guid then
                return u, true
            end
            if not lowest_hp or u.Health < lowest_hp then
                lowest, lowest_hp = u, u.Health
            end
        end
    end
    return lowest or fallback, false
end

-- True when both wrappers reference the same in-game entity. Compares
-- obj_ptr first (stable across Guid formats); only falls back to Guid
-- when one side has no obj_ptr (e.g., a mob that just left the snapshot).
local function SameUnit(a, b)
    if not a or not b then return false end
    if a.obj_ptr and b.obj_ptr then return a.obj_ptr == b.obj_ptr end
    return a.Guid and b.Guid and a.Guid == b.Guid or false
end

-- Off-target crowd control: pick a live enemy that isn't BestTarget for
-- Fear. Fear only sticks on one mob at a time, so if any off-target
-- already has Fear from us we leave the rest alone.
local function PickFearTarget(best)
    if not Combat or not Combat.Targets or #Combat.Targets < 2 then return nil end
    local best_guid = best and best.Guid or ""
    local candidate = nil
    for _, u in ipairs(Combat.Targets) do
        if u and not u.IsDead and (u.Health or 0) > 0 and u.Guid ~= best_guid then
            if u:HasDebuffByMe("Fear") then return nil end
            if not candidate then candidate = u end
        end
    end
    return candidate
end

-- Send the pet at `target` only when it isn't already on it.
local function CommandPet(target)
    if not target or not Pet.HasPet() or Pet:IsDead() then return end
    local pet = Pet.GetPrimary()
    if pet and pet.IsCastingOrChanneling then
        local ok, busy = pcall(pet.IsCastingOrChanneling, pet)
        if ok and busy then return end
    end
    local current = Pet:GetTarget()
    if not SameUnit(current, target) then
        Pet.Attack(target)
    end
end

local function DoCombat()
    local target = Combat.BestTarget

    -- Pet handling runs independent of the player's cast/GCD state.
    if target and AegisSettings.AffliPetAutoTarget ~= false then
        local pet_target, attacking_me = PickPetTarget(target)
        CommandPet(pet_target)

        if attacking_me and AegisSettings.AffliPetTorment ~= false
            and Pet.IsActionReady("Torment") then
            local pet = Pet.GetPrimary()
            if pet and pet:InMeleeRange(pet_target) then
                Pet.CastAction("Torment")
            end
        end
    end

    if Spell:IsGCDActive() or Me:IsEatingOrDrinking() or Me:IsCastingOrChanneling() then return end

    local wanding = Me:IsAutoWanding()
    local want_cast = false

    local function Cast(spell, ...)
        want_cast = true
        if wanding then return false end
        return spell:CastEx(...)
    end

    local function ApplyDot(spell, dot_target, min_pct)
        -- Mirror Spell:Apply's gates so want_cast only fires when Apply
        -- would actually try to cast. Otherwise a below-threshold DoT
        -- (e.g. mob HP too low for the landing % requirement) would mark
        -- want_cast and leave us neither casting nor wanding.
        if not dot_target or dot_target.IsDead then return false end
        if dot_target:HasDebuffByMe(spell.Name) then return false end
        local hp = dot_target.Health or 0
        if hp <= 0 then return false end
        if min_pct and min_pct > 0 then
            local total = spell:DotTotal()
            if total and total > 0 then
                local landing_pct = (math.min(hp, total) / total) * 100
                if landing_pct < min_pct then return false end
            end
        end
        want_cast = true
        if wanding then return false end
        return spell:Apply(dot_target, min_pct)
    end

    if not Me:HasAura("Demon Skin") and Cast(Spell.DemonSkin, Me) then return end

    if target then
        if AegisSettings.AffliFearAdds ~= false then
            local fear_tgt = PickFearTarget(target)
            if fear_tgt and Cast(Spell.Fear, fear_tgt, { skipFacing = true }) then return end
        end

        for _, enemy in pairs(Combat.Targets) do
            if not enemy:HasDebuffByMe("Fear")
                and ApplyDot(Spell.Corruption, enemy, 70) then return end
        end
    end

    if want_cast then
        if wanding then Me:StopCasting() end
        return
    end

    if target and not wanding then
        Me:StartWanding(target)
    end
end


local behaviors = {
    [BehaviorType.Combat] = DoCombat,
}

return { Options = options, Behaviors = behaviors }
