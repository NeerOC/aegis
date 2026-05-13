local options = {
    Name = "Warlock (Affliction)",
    Widgets = {
        { type = "text", text = "Pet & crowd control" },
        {
            type = "checkbox",
            text = "Auto pet target (peel / lowest HP)",
            uid = "AffliPetAutoTarget",
            default = true
        },
        {
            type = "checkbox",
            text = "Voidwalker Torment on threat target",
            uid = "AffliPetTorment",
            default = true
        },
        {
            type = "checkbox",
            text = "Fear off-target adds",
            uid = "AffliFearAdds",
            default = true
        },
        { type = "text", text = "Drain Soul" },
        {
            type = "checkbox",
            text = "Drain Soul on <15% HP target",
            uid = "AffliDrainSoul",
            default = true
        },
        {
            type = "slider",
            text = "Top up when shards <",
            uid = "AffliDrainSoulMaxShards",
            min = 0,
            max = 32,
            default = 5
        },
    },
}

-- Item id 6265 = Soul Shard. Cached briefly so we don't pay the WoW Lua
-- bridge cost every tick — shard count only changes on kill or spell cast.
local SOUL_SHARD_ITEM_ID = 6265
local _shard_cache = { count = 0, at = 0 }
local function SoulShardCount()
    local now = os.clock()
    if now - _shard_cache.at < 0.5 then return _shard_cache.count end
    _shard_cache.at = now
    if not wow or not wow.eval_lua then return _shard_cache.count end
    local ok, v = pcall(wow.eval_lua, "GetItemCount(" .. SOUL_SHARD_ITEM_ID .. ")")
    _shard_cache.count = (ok and tonumber(v)) or 0
    return _shard_cache.count
end

local function PickPetTarget(fallback)
    if not Me or not Combat or not Combat.Targets then return fallback, false end
    local lowest, lowest_hp = nil, nil
    for _, u in ipairs(Combat.Targets) do
        if u and not u.IsDead and (u.Health or 0) > 0 then
            if u:IsTanking() then
                return u, true
            end
            if not lowest_hp or u.Health < lowest_hp then
                lowest, lowest_hp = u, u.Health
            end
        end
    end
    return lowest or fallback, false
end

local function SameUnit(a, b)
    if not a or not b then return false end
    if a.obj_ptr and b.obj_ptr then return a.obj_ptr == b.obj_ptr end
    return a.Guid and b.Guid and a.Guid == b.Guid or false
end

-- Off-target crowd control: pick a live enemy that isn't BestTarget for
-- Fear. Fear only sticks on one mob at a time, so if any off-target
-- already has Fear from us we leave the rest alone.
local function PickFearTarget(best)
    if not Me or not Combat or not Combat.Targets or #Combat.Targets < 2 then return nil end
    local best_guid = best and best.Guid or ""
    local candidate = nil
    for _, u in ipairs(Combat.Targets) do
        if u and not u.IsDead and (u.Health or 0) > 0 and u.Guid ~= best_guid then
            if u:HasDebuffByMe("Fear") then return nil end
            if not candidate and Spell.Fear:InRange(u) then
                candidate = u
            end
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
    elseif not target and AegisSettings.AffliPetAutoTarget ~= false
        and Pet.HasPet() and not Pet:IsDead() then
        -- No combat target but pet is still chasing something — recall it.
        -- Once pet starts following, its target goes nil and this is a no-op
        -- on subsequent ticks, so no spam.
        local pet_target = Pet:GetTarget()
        if pet_target and not pet_target.IsDead then
            Pet.Follow()
        end
    end

    if Spell:IsGCDActive() or Me:IsEatingOrDrinking() or Me:IsCastingOrChanneling() then return end

    local wanding = Me:IsAutoWanding()
    local want_cast = false

    local function Cast(spell, cast_target, ...)
        if cast_target and not spell:InRange(cast_target) then return false end
        want_cast = true
        if wanding then return false end
        return spell:CastEx(cast_target, ...)
    end

    local function ApplyDot(spell, dot_target, min_pct)
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
        if not spell:InRange(dot_target) then return false end
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
                and ApplyDot(Spell.Corruption, enemy, 70) then
                return
            end
        end

        if AegisSettings.AffliDrainSoul ~= false
            and target.HealthPct < 15
            and SoulShardCount() < (AegisSettings.AffliDrainSoulMaxShards or 5)
            and Cast(Spell.DrainSoul, target) then
            return
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
