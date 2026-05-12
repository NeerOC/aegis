-- Aegis Core — PvE behavior framework for jmrTBC.

local Plugin                     = {}
Plugin.name                      = "Aegis Core"
Plugin.description               = "Aegis-style behavior framework (combat, heal, tank)"
Plugin.author                    = "community"

local settings_mod               = require("settings")

Aegis                            = Aegis or {}
Aegis._entity_cache              = {}
Aegis._last_cast                 = ""
Aegis._last_cast_time            = 0
Aegis._last_cast_tgt             = ""
Aegis._last_cast_code            = 0
Aegis._last_cast_desc            = ""
Aegis._last_fail                 = ""
Aegis._last_fail_time            = 0
Aegis._last_fail_code            = 0
Aegis._last_fail_desc            = ""
Aegis._tick_throttled            = false
Aegis._autorepeat_suppress_until = 0
Aegis._current_action            = "IDLE"
Aegis._tick_load_ms              = 0
Aegis._interrupt_log             = {}
Aegis._interrupt_log_idx         = 0


local BASE_DIR = (SCRIPTS_DIR or game.SCRIPTS_DIR or ".") .. "\\Aegis"

local function include(rel_path)
  local full = BASE_DIR .. "\\" .. rel_path:gsub("/", "\\")
  local chunk, err = loadfile(full)
  if not chunk then
    console.warn("[Aegis] load failed: " .. rel_path .. " — " .. tostring(err))
    return nil
  end
  local ok, result = pcall(chunk)
  if not ok then
    console.error("[Aegis] error in " .. rel_path .. " — " .. tostring(result))
    return nil
  end
  return result
end

Aegis.include = include
_G.include = include


AegisSettings = AegisSettings or {}

local SETTINGS_KEY = "Aegis"

local CORE_DEFAULTS = {
  AegisEnabled               = true,
  AegisAutoTarget            = false,
  AegisAttackOOC             = false,
  AegisAttackTarget          = true,
  AegisSpecIdx               = 0,
  AegisSpecName              = "",
  AegisSpecManualOverride    = false,
  AegisInterruptMode         = 0,
  AegisInterruptTiming       = false,
  AegisInterruptPercentage   = 80,
  AegisToggleKey             = 0,

  AegisSpellQueueWindowMs    = 400,
  AegisSpellQueueSlackMs     = 75,

  AegisCastSuccessThrottleMs = 30,
}

local function load_settings()
  local saved = settings_mod.load(SETTINGS_KEY) or {}
  for k, v in pairs(CORE_DEFAULTS) do
    if saved[k] == nil then saved[k] = v end
  end
  AegisSettings = saved
end

local function save_settings()
  settings_mod.save(SETTINGS_KEY, AegisSettings)
end

local save_cooldown = 0


local function load_modules()
  include("common/targeting.lua")

  local UnitMod = include("common/unit.lua")
  if UnitMod then Unit = UnitMod end

  local PlayerMod = include("common/player.lua")
  if PlayerMod then Player = PlayerMod end

  local PetMod = include("common/pet.lua")
  if PetMod then Pet = PetMod end

  include("common/spell.lua")
  include("common/menu.lua")

  local BehaviorToggleMod = include("common/behavior_toggle.lua")
  if BehaviorToggleMod then BehaviorToggle = BehaviorToggleMod end

  local RangeTargetMod = include("common/range_target.lua")
  if RangeTargetMod then RangeTarget = RangeTargetMod end

  local ClassData = include("data/classes.lua")
  Aegis._class_data = ClassData

  include("system/behavior.lua")
  include("system/combat.lua")
  include("system/heal.lua")
  include("system/tank.lua")
end


local function refresh_me()
  local ok, player = pcall(game.local_player)
  if not ok or not player then
    Me = nil
    return
  end

  Me = Player:New(player)
  if not Me then return end

  local cd = Aegis._class_data
  if cd then
    local key        = cd.class_key(Me.ClassId)
    Me._class_key    = key
    Me._class_name   = cd.CLASS_MAP[Me.ClassId] or "Unknown"
    Me.ClassName     = Me._class_name
    Me._spec_options = key and cd.SPEC_MAP[key] or {}
  end

  if not AegisSettings.AegisSpecManualOverride and Me.SpecName ~= "" then
    AegisSettings.AegisSpecName = Me.SpecName
    if Me._spec_options then
      for i, name in ipairs(Me._spec_options) do
        if name == Me.SpecName then
          AegisSettings.AegisSpecIdx = i - 1
          break
        end
      end
    end
  end

  Me.Target = Me:GetTarget()
  Me.Focus  = Me:GetFocus()
end


local function refresh_entities()
  local ok, list = pcall(game.objects)
  Aegis._entity_cache = (ok and list) or {}
end


local initialized = false

local function initialize()
  if initialized then return end

  load_settings()
  load_modules()

  if not Unit then
    console.error("[Aegis] Unit module failed to load — aborting")
    return
  end

  refresh_entities()
  refresh_me()

  if Me then
    Menu:Initialize()
    Spell:UpdateCache()
    Behavior:Initialize()
  end

  initialized = true
  print("[Aegis] Core initialized")
end

local ImGuiKey_Insert = 521


function Plugin.onEnable()
  local shim_path = BASE_DIR .. "\\shim.lua"
  local shim, shim_err = loadfile(shim_path)
  if shim then
    local ok, err = pcall(shim)
    if not ok then console.warn("[Aegis] shim load failed: " .. tostring(err)) end
  else
    console.error("[Aegis] shim missing at " .. shim_path .. ": " .. tostring(shim_err))
    return
  end

  initialized = false
  initialize()
  console.log("[Aegis] Enabled")
end

function Plugin.onDisable()
  save_settings()
  Me = nil
  initialized = false
  console.log("[Aegis] Disabled")
end

local TICK_RATE = 0.05
local last_tick = 0

function Plugin.onTick()
  if not initialized then
    initialize()
    if not initialized then return end
  end

  if imgui.is_key_pressed(ImGuiKey_Insert) then
    if Menu then
      Menu.Open = not Menu.Open
    end
  end

  if BehaviorToggle then pcall(BehaviorToggle.Tick) end

  if not AegisSettings.AegisEnabled then return end

  local now = os.clock()
  if now - last_tick < TICK_RATE then return end
  last_tick = now

  Aegis._tick_throttled = false
  Aegis._spell_debug_tick = (Aegis._spell_debug_tick or 0) + 1

  refresh_entities()
  refresh_me()
  if not Me then return end

  if cleu and cleu.poll and Spell and Spell.ProcessCleuEvents then
    pcall(Spell.ProcessCleuEvents, Spell, cleu.poll())
  end

  if Me.IsDead or Me:HasAura(8326) or Me.IsMounted then return end

  local live_spec
  if AegisSettings.AegisSpecManualOverride then
    live_spec = AegisSettings.AegisSpecName or ""
  else
    live_spec = Me.SpecName
    if not live_spec or live_spec == "" then
      live_spec = AegisSettings.AegisSpecName or ""
    end
  end
  if live_spec ~= "" and live_spec ~= Behavior.LoadedSpec then
    if wow and wow.talent_tabs then
      local ok, tabs = pcall(wow.talent_tabs)
      if ok and tabs then
        local parts = {}
        for _, t in ipairs(tabs) do
          parts[#parts + 1] = string.format("tab=%d id=%d pts=%d",
            t.tab or -1, t.tab_id or 0, t.points or 0)
        end
        print(string.format("[Aegis] Spec change: detected=%q override=%s tabs=[%s]",
          Me.SpecName or "", tostring(AegisSettings.AegisSpecManualOverride),
          table.concat(parts, ", ")))
      end
    end
    Menu:Initialize()
    Behavior:Initialize()
  end

  if Spell.CacheCount == 0 then
    Spell:UpdateCache()
  end


  Aegis._current_action = "IDLE"

  local _t0 = os.clock()
  Combat:Update()
  Heal:Update()
  Tank:Update()

  Behavior:Update()
  Aegis._tick_load_ms = (os.clock() - _t0) * 1000

  if now - save_cooldown > 5 then
    save_settings()
    save_cooldown = now
  end
end

function Plugin.onDraw()
  if not initialized then return end

  -- Top-center "PAUSED" banner — drawn before the Me guard so it survives
  -- even when the player object isn't resolved yet (loading, etc.). The
  -- master gate is AegisSettings.AegisEnabled, toggled by BehaviorToggle's
  -- keybind (configure in the Rotation tab).
  if AegisSettings and not AegisSettings.AegisEnabled
      and imgui.draw_text and imgui.get_display_size then
    local sw, _sh = imgui.get_display_size()
    local label   = "PAUSED"
    -- Default ImGui font ~7px per glyph; pad a bit so the backing rect
    -- doesn't crowd the letters.
    local text_w  = #label * 8
    local text_h  = 16
    local px      = math.floor((sw - text_w) * 0.5)
    local py      = 24
    local red     = imgui.color_u32(1.0, 0.20, 0.20, 1.0)
    local bg      = imgui.color_u32(0.0, 0.0, 0.0, 0.70)
    local border  = imgui.color_u32(1.0, 0.20, 0.20, 0.85)
    imgui.draw_rect_filled(px - 14, py - 8, px + text_w + 14, py + text_h + 8, bg, 4)
    imgui.draw_rect(px - 14, py - 8, px + text_w + 14, py + text_h + 8, border, 4, 2)
    imgui.draw_text(px, py, red, label)
  end

  if not Me then return end
  Menu:Draw()
  if Spell and Spell.DrawDebugWindow then
    pcall(Spell.DrawDebugWindow, Spell)
  end
end

return Plugin
