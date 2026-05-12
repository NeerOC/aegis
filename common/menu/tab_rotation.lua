-- Rotation tab — engine toggles, pacing sliders, hotkey binding.

local imgui = require("imgui")
local Theme = include and include("common/menu/theme.lua")
    or require("common.menu.theme")
local Widgets = include and include("common/menu/widgets.lua")
    or require("common.menu.widgets")

local C = Theme.C
local Rotation = {}

local function checkbox_setting(label, key)
  local cur = AegisSettings[key]
  if cur == nil then cur = false end
  local ch, v = imgui.checkbox(label, cur)
  if ch then AegisSettings[key] = v end
end

local function slider_setting(label, key, lo, hi, default)
  if AegisSettings[key] == nil then AegisSettings[key] = default or lo end
  local ch, v = imgui.slider_int(label, AegisSettings[key], lo, hi)
  if ch then AegisSettings[key] = v end
end

function Rotation.Draw()
  local p_engine = { checkbox = 4 }
  local p_pacing = { slider = 3 }
  local p_hotkey = { text = 2, button = 1 }
  local total_h  = Widgets.tab_height({ p_engine, p_pacing, p_hotkey })
  imgui.begin_child("aegis_rotation", Theme.CONTENT_W, total_h, false, 24)

  Widgets.card("rot_engine", "ENGINE", 0, Widgets.card_height(p_engine), function()
    checkbox_setting("Master enable##rot_en", "AegisEnabled")
    checkbox_setting("Auto-target##rot_at", "AegisAutoTarget")
    checkbox_setting("Always attack current target##rot_att", "AegisAttackTarget")
    checkbox_setting("Attack out of combat##rot_ooc", "AegisAttackOOC")
  end)

  Widgets.card("rot_pacing", "PACING", 0, Widgets.card_height(p_pacing), function()
    slider_setting("Cast throttle (ms)##rot_ct", "AegisCastSuccessThrottleMs", 0, 1000, 30)
    if imgui.is_item_hovered() then
      imgui.set_tooltip("Per-spell-ID delay after a successful cast")
    end
    slider_setting("Spell queue window (ms)##rot_sqw", "AegisSpellQueueWindowMs", 0, 1000, 400)
    if imgui.is_item_hovered() then
      imgui.set_tooltip("How long after a cast the next queued spell waits")
    end
    slider_setting("Spell queue slack (ms)##rot_sqs", "AegisSpellQueueSlackMs", 0, 500, 75)
  end)

  -- BehaviorToggle.DrawOptions: "Toggle key" text + button row + status text.
  Widgets.card("rot_hotkey", "HOTKEY", 0, Widgets.card_height(p_hotkey), function()
    if BehaviorToggle and BehaviorToggle.DrawOptions then
      pcall(BehaviorToggle.DrawOptions)
    else
      imgui.text_colored(C.text_secondary[1], C.text_secondary[2], C.text_secondary[3], 1.0,
        "BehaviorToggle module not loaded")
    end
  end)

  imgui.end_child()
end

return Rotation
