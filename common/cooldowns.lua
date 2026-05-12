-- Shared cooldown-window helpers for class/spec behavior files.

---@class Cooldowns
---@field Modes table<string, number> Named cooldown-mode constants.
local Cooldowns = {}

local AURAS = {
  Bloodlust = "Bloodlust",
  Exhaustion = "Exhaustion",
  Heroism = "Heroism",
  Sated = "Sated",
}

local MODE_BLOODLUST_BOSSES = 0
local MODE_BOSS_LONG_FIGHTS = 1
local MODE_ON_COOLDOWN = 2
local MODE_MANUAL = 3
local MODE_RAID_BLOODLUST_ELSE_BOSS_LONG = 4

local function bool_default(value, default)
  if value == nil then return default end
  return value
end

local function setting(prefix, key, default)
  local uid = prefix .. key
  local value = AegisSettings and AegisSettings[uid]
  if value == nil then return default end
  return value
end

local function enabled_setting(prefix, default)
  local value = AegisSettings and AegisSettings[prefix .. "UseCooldowns"]
  if value == nil then
    value = AegisSettings and AegisSettings[prefix .. "UseBloodlustCooldowns"]
  end
  return bool_default(value, default)
end

local function is_in_raid()
  if game and game.is_in_raid then
    local ok, result = pcall(game.is_in_raid)
    if ok then return result == true end
  end
  return false
end

local function player_is_casting_or_channeling()
  if not Me then return false end
  if Me.IsCastingOrChanneling then
    local ok, busy = pcall(Me.IsCastingOrChanneling, Me)
    if ok and busy then return true end
  end
  return Me.IsCasting == true or Me.IsChanneling == true
end

local function gcd_active()
  if Spell and Spell.IsGCDActive then
    local ok, active = pcall(Spell.IsGCDActive, Spell)
    if ok then return active == true end
  end
  return false
end

function Cooldowns.HasBloodlust()
  return Me and (Me:HasAura(AURAS.Bloodlust)
    or Me:HasAura(AURAS.Heroism)
    or Me:HasAura(AURAS.Exhaustion)
    or Me:HasAura(AURAS.Sated)) or false
end

function Cooldowns.IsBossTarget(target)
  if not target or target.IsDead then return false end
  if target.IsBoss and target:IsBoss() then return true end
  if target.IsWorldBoss and target:IsWorldBoss() then return true end
  return false
end

function Cooldowns.TargetTTD(target)
  if target and target.TimeToDie then
    local ttd = target:TimeToDie()
    if ttd and ttd > 0 and ttd < 7777 then return ttd end
  end
  return nil
end

function Cooldowns.Mode(prefix, default)
  return setting(prefix, "CooldownMode", default or MODE_RAID_BLOODLUST_ELSE_BOSS_LONG)
end

function Cooldowns.Enabled(prefix, default)
  return enabled_setting(prefix, bool_default(default, true))
end

function Cooldowns.UseRacials(prefix, default)
  return bool_default(setting(prefix, "UseRacialCooldowns", nil), bool_default(default, true))
end

function Cooldowns.UseTrinkets(prefix, default)
  return bool_default(setting(prefix, "UseTrinkets", nil), bool_default(default, true))
end

function Cooldowns.UseClassCooldowns(prefix, default)
  return bool_default(setting(prefix, "UseClassCooldowns", nil), bool_default(default, true))
end

function Cooldowns.WindowOpen(prefix, target, opts)
  opts = opts or {}

  if not Cooldowns.Enabled(prefix, opts.default_enabled) then return false end
  if not target or target.IsDead then return false end
  if opts.require_stationary and Me and Me.IsMoving and Me:IsMoving() then return false end
  if opts.require_not_casting ~= false and player_is_casting_or_channeling() then return false end
  if opts.require_gcd_ready and gcd_active() then return false end

  local mode = Cooldowns.Mode(prefix, opts.default_mode)
  if mode == MODE_MANUAL then return false end
  if mode == MODE_ON_COOLDOWN then return true end
  if mode == MODE_RAID_BLOODLUST_ELSE_BOSS_LONG then
    mode = is_in_raid() and MODE_BLOODLUST_BOSSES or MODE_BOSS_LONG_FIGHTS
  end

  if not Cooldowns.IsBossTarget(target) then return false end
  if mode == MODE_BLOODLUST_BOSSES and not Cooldowns.HasBloodlust() then return false end
  if mode == MODE_BOSS_LONG_FIGHTS then
    local ttd = Cooldowns.TargetTTD(target)
    if not ttd then
      return Cooldowns.IsBossTarget(target)
    end
    if ttd < setting(prefix, "CooldownMinTTD", opts.min_ttd or 45) then
      return false
    end
  end

  return true
end

function Cooldowns.TryCommonOffensives(prefix, target, opts)
  opts = opts or {}
  if not Cooldowns.WindowOpen(prefix, target, opts) then return false end

  if Cooldowns.UseRacials(prefix, opts.use_racials) and Racials and Racials.TryDamageBoost then
    if Racials.TryDamageBoost(target, { cooldownWindow = true }) then return true end
  end

  if Cooldowns.UseTrinkets(prefix, opts.use_trinkets) and Item and Item.TryOffensiveTrinket then
    if Item.TryOffensiveTrinket() then return true end
  end

  return false
end

function Cooldowns.HasReadyOffensiveItem(prefix, target, opts)
  opts = opts or {}
  if not Item or not Item.HasReadyAny or not Item.Data then return false end

  local window_opts = {}
  for key, value in pairs(opts) do window_opts[key] = value end
  if window_opts.default_mode == nil then
    window_opts.default_mode = MODE_RAID_BLOODLUST_ELSE_BOSS_LONG
  end
  if window_opts.require_not_casting == nil then
    window_opts.require_not_casting = false
  end

  if not Cooldowns.WindowOpen(prefix, target, window_opts) then return false end

  if Cooldowns.UseTrinkets(prefix, opts.use_trinkets) and Item:HasReadyAny(Item.Data.OffensiveTrinkets) then
    return true, "offensive_trinket"
  end
  if setting(prefix, "UseHastePotion", opts.use_haste_potion == true) and Item:HasReadyAny(Item.Data.HastePotions) then
    return true, "haste_potion"
  end
  if setting(prefix, "UseDestructionPotion", opts.use_destruction_potion == true) and Item:HasReadyAny(Item.Data.DestructionPotions) then
    return true, "destruction_potion"
  end
  if setting(prefix, "UseFlameCap", opts.use_flame_cap == true) and Item:HasReadyAny(Item.Data.FlameCaps) then
    return true, "flame_cap"
  end

  return false
end

function Cooldowns.TryManaGem(prefix, target, opts)
  opts = opts or {}
  if not setting(prefix, "UseManaGems", opts.use_mana_gems ~= false) then return false end
  if not Cooldowns.WindowOpen(prefix, target, opts) then return false end
  if opts.mana_pct and Me and (Me.PowerPct or 100) > opts.mana_pct then return false end
  if opts.missing_mana and Me and Me.PowerDeficit and (Me:PowerDeficit(0) or 0) < opts.missing_mana then return false end
  return Item and Item.TryManaGem and Item.TryManaGem() or false
end

function Cooldowns.TryManaPotion(prefix, target, opts)
  opts = opts or {}
  if not setting(prefix, "UseManaPotions", setting(prefix, "UseManaPotion", opts.use_mana_potions == true)) then return false end
  if not Cooldowns.IsBossTarget(target) then return false end
  local pct = setting(prefix, "ManaPotionPct", opts.mana_pct or 25)
  if Me and (Me.PowerPct or 100) > pct then return false end
  if opts.missing_mana and Me and Me.PowerDeficit and (Me:PowerDeficit(0) or 0) < opts.missing_mana then return false end
  return Item and Item.TryManaPotion and Item.TryManaPotion() or false
end

function Cooldowns.TryHastePotion(prefix, target, opts)
  opts = opts or {}
  if not setting(prefix, "UseHastePotion", opts.use_haste_potion == true) then return false end
  if not Cooldowns.IsBossTarget(target) then return false end
  if not Cooldowns.WindowOpen(prefix, target, opts) then return false end
  return Item and Item.TryHastePotion and Item.TryHastePotion() or false
end

function Cooldowns.TryDestructionPotion(prefix, target, opts)
  opts = opts or {}
  if not setting(prefix, "UseDestructionPotion", opts.use_destruction_potion == true) then return false end
  if not Cooldowns.IsBossTarget(target) then return false end
  if not Cooldowns.WindowOpen(prefix, target, opts) then return false end
  return Item and Item.TryDestructionPotion and Item.TryDestructionPotion() or false
end

function Cooldowns.TryFlameCap(prefix, target, opts)
  opts = opts or {}
  if not setting(prefix, "UseFlameCap", opts.use_flame_cap == true) then return false end
  if not Cooldowns.IsBossTarget(target) then return false end
  if not Cooldowns.WindowOpen(prefix, target, opts) then return false end
  return Item and Item.TryFlameCap and Item.TryFlameCap() or false
end

function Cooldowns.Widgets(prefix, defaults)
  defaults = defaults or {}
  local enabled_default = AegisSettings and AegisSettings[prefix .. "UseCooldowns"] or nil
  if enabled_default == nil and AegisSettings then
    enabled_default = AegisSettings[prefix .. "UseBloodlustCooldowns"]
  end
  if enabled_default == nil then
    enabled_default = bool_default(defaults.enabled, true)
  end

  local widgets = {
    { type = "text",     text = defaults.header or "=== Cooldowns ===" },
    { type = "checkbox", uid = prefix .. "UseCooldowns",               text = "Use cooldowns", default = enabled_default },
    {
      type = "combobox",
      uid = prefix .. "CooldownMode",
      text = "Cooldown timing",
      default = defaults.mode or MODE_RAID_BLOODLUST_ELSE_BOSS_LONG,
      options = { "Bloodlust on bosses", "Boss/long fights", "On cooldown", "Manual", "Raid Bloodlust, else boss/long fights" }
    },
    { type = "slider",   uid = prefix .. "CooldownMinTTD",     text = "Long fight TTD sec", default = defaults.min_ttd or 45,                      min = 0, max = 180 },
    { type = "checkbox", uid = prefix .. "UseRacialCooldowns", text = "Racial cooldowns",   default = bool_default(defaults.racials, true) },
    { type = "checkbox", uid = prefix .. "UseTrinkets",        text = "Offensive trinkets", default = bool_default(defaults.trinkets, true) },
    { type = "checkbox", uid = prefix .. "UseClassCooldowns",  text = "Class cooldowns",    default = bool_default(defaults.class_cooldowns, true) },
  }

  if defaults.haste_potion ~= nil then
    widgets[#widgets + 1] = {
      type = "checkbox",
      uid = prefix .. "UseHastePotion",
      text = defaults.haste_text or
          "Haste Potion on bosses",
      default = defaults.haste_potion
    }
  end
  if defaults.destruction_potion ~= nil then
    widgets[#widgets + 1] = {
      type = "checkbox",
      uid = prefix .. "UseDestructionPotion",
      text =
      "Destruction Potion on bosses",
      default = defaults.destruction_potion
    }
  end
  if defaults.flame_cap ~= nil then
    widgets[#widgets + 1] = {
      type = "checkbox",
      uid = prefix .. "UseFlameCap",
      text = "Flame Cap on bosses",
      default =
          defaults.flame_cap
    }
  end

  return widgets
end

Cooldowns.Modes = {
  BloodlustBosses = MODE_BLOODLUST_BOSSES,
  BossLongFights = MODE_BOSS_LONG_FIGHTS,
  OnCooldown = MODE_ON_COOLDOWN,
  Manual = MODE_MANUAL,
  RaidBloodlustElseBossLong = MODE_RAID_BLOODLUST_ELSE_BOSS_LONG,
  Default = MODE_RAID_BLOODLUST_ELSE_BOSS_LONG,
}

return Cooldowns
