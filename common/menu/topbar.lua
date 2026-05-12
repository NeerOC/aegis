-- Persistent top status strip — always visible, regardless of tab.

local imgui = require("imgui")
local Theme = include and include("common/menu/theme.lua")
    or require("common.menu.theme")
local Widgets = include and include("common/menu/widgets.lua")
    or require("common.menu.widgets")

local C = Theme.C
local TopBar = {}

-- Bound-key label resolver (light dependency on BehaviorToggle if present).
local function bound_key_label()
  if BehaviorToggle and BehaviorToggle.GetKeyLabel then
    local ok, label = pcall(BehaviorToggle.GetKeyLabel)
    if ok and label and label ~= "" then return label end
  end
  local k = AegisSettings and AegisSettings.AegisToggleKey or 0
  if k > 0 then return "key " .. k end
  return "unbound"
end

---@param close_clicked_ref { value: boolean } Set true if X clicked.
function TopBar.Draw(close_clicked_ref)
  imgui.push_style_color(3, C.bg_panel[1], C.bg_panel[2], C.bg_panel[3], C.bg_panel[4])
  -- Match the width of the sidebar + content column below so the X glyph
  -- sits at the right edge of the auto-resized window.
  local Theme_ref = include and include("common/menu/theme.lua")
      or require("common.menu.theme")
  local total_w = (Theme_ref.SIDEBAR_W or 130) + (Theme_ref.CONTENT_W or 480) + 8
  imgui.begin_child("aegis_topbar", total_w, 40, false, 0)

  -- Brand
  imgui.dummy(0, 4)
  imgui.same_line(0, 0)
  imgui.dummy(8, 0)
  imgui.same_line(0, 0)
  imgui.text_colored(C.accent[1], C.accent[2], C.accent[3], 1.0, "AEGIS")
  imgui.same_line(0, 6)
  imgui.text_colored(C.text_secondary[1], C.text_secondary[2], C.text_secondary[3], 1.0, "v0.1")

  -- Rotation pill
  imgui.same_line(0, 16)
  local enabled = AegisSettings and AegisSettings.AegisEnabled
  if enabled then
    Widgets.status_pill("ROTATION: ON", C.success)
  else
    Widgets.status_pill("ROTATION: PAUSED", C.error_col)
  end

  imgui.same_line(0, 8)
  imgui.text_colored(C.text_secondary[1], C.text_secondary[2], C.text_secondary[3], 1.0,
    bound_key_label() .. " to toggle")

  -- Right side: FPS + close. Approximate width budget — push to the right
  -- by using same_line with a large offset (display_size minus est width).
  local dw = imgui.get_display_size()
  local fps_text = string.format("FPS %.0f", imgui.get_framerate())
  local close_x_offset = (dw and 0 or 0) -- placeholder; we just stack right-side
  imgui.same_line(0, 32)
  imgui.text_colored(C.text_secondary[1], C.text_secondary[2], C.text_secondary[3], 1.0, fps_text)

  imgui.same_line(0, 16)
  if imgui.small_button("X##aegis_close") then
    close_clicked_ref.value = true
  end

  imgui.end_child()
  imgui.pop_style_color(1)

  imgui.separator()
end

return TopBar
