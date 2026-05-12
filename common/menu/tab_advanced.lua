-- Advanced tab — debug toggles, raw counters, dump-state.

local imgui = require("imgui")
local Theme = include and include("common/menu/theme.lua")
    or require("common.menu.theme")
local Widgets = include and include("common/menu/widgets.lua")
    or require("common.menu.widgets")

local C = Theme.C
local Advanced = {}

function Advanced.Draw()
  local p_debug = { checkbox = 1, text = 1 }
  local p_state = { text = 6 }
  local p_info  = { text = 2, button = 1, sep = 1 }
  local total_h = Widgets.tab_height({ p_debug, p_state, p_info })
  imgui.begin_child("aegis_advanced", Theme.CONTENT_W, total_h, false, 24)

  Widgets.card("adv_debug", "DEBUG", 0, Widgets.card_height(p_debug), function()
    if AegisSettings.AegisSpellDebug == nil then AegisSettings.AegisSpellDebug = false end
    local ch, v = imgui.checkbox("Spell debug window##adv_sd", AegisSettings.AegisSpellDebug)
    if ch then AegisSettings.AegisSpellDebug = v end
    imgui.text_colored(C.text_secondary[1], C.text_secondary[2], C.text_secondary[3], 1.0,
      "Pops a separate window with per-cast diagnostics")
  end)

  Widgets.card("adv_state", "RAW STATE", 0, Widgets.card_height(p_state), function()
    imgui.text(string.format("Last cast:   %s", Aegis._last_cast or ""))
    imgui.text(string.format("  -> target: %s", Aegis._last_cast_tgt or ""))
    imgui.text(string.format("  code:      %s", tostring(Aegis._last_cast_code or 0)))
    imgui.text(string.format("  desc:      %s", Aegis._last_cast_desc or ""))
    imgui.text(string.format("Last fail:   %s", Aegis._last_fail or ""))
    imgui.text(string.format("  desc:      %s", Aegis._last_fail_desc or ""))
  end)

  Widgets.card("adv_info", "INFO", 0, Widgets.card_height(p_info), function()
    imgui.text("Aegis — PvE behavior framework for jmrTBC")
    imgui.text_colored(C.text_secondary[1], C.text_secondary[2], C.text_secondary[3], 1.0,
      "github.com/NeerOC/aegis")
    imgui.spacing()
    if imgui.button("Dump state to console##adv_dump") then
      console.log(string.format(
        "[Aegis] state: enabled=%s spec=%s override=%s tick_load=%.1fms",
        tostring(AegisSettings.AegisEnabled),
        tostring(AegisSettings.AegisSpecName),
        tostring(AegisSettings.AegisSpecManualOverride),
        Aegis._tick_load_ms or 0))
    end
  end)

  imgui.end_child()
end

return Advanced
