-- Vertical tab sidebar — 130px rail of selectable nav entries.

local imgui = require("imgui")
local Theme = include and include("common/menu/theme.lua")
    or require("common.menu.theme")

local C = Theme.C
local Sidebar = {}

Sidebar.TABS = {
  "Dashboard",
  "Rotation",
  "Interrupts",
  "Spec",
  "Class Opts",
  "Advanced",
}

local SIDEBAR_W = 130
local ROW_H = 32
-- Inter-button vertical spacing (matches ItemSpacing.y from theme.lua).
local ROW_SPACING = 6

---@param current number 1-based current selection.
---@return number new_selection
function Sidebar.Draw(current)
  current = current or 1
  -- Explicit height — counting buttons + spacing + child padding. With
  -- h=0 the sidebar would "fill remaining" of the AlwaysAutoResize window,
  -- which locks the window to its previous height when switching to a
  -- shorter tab (sidebar.h carries over and dominates max(sidebar, tab)).
  local n             = #Sidebar.TABS
  local sidebar_h     = n * ROW_H + (n - 1) * ROW_SPACING + 16
  imgui.push_style_color(3, C.bg_panel[1], C.bg_panel[2], C.bg_panel[3], C.bg_panel[4])
  imgui.begin_child("aegis_sidebar", SIDEBAR_W, sidebar_h, false, 0)

  local new_sel = current
  for i, label in ipairs(Sidebar.TABS) do
    local active = (i == current)
    if active then
      imgui.push_style_color(21, C.accent_dim[1], C.accent_dim[2], C.accent_dim[3], C.accent_dim[4])
      imgui.push_style_color(22, C.accent_dim[1], C.accent_dim[2], C.accent_dim[3], 0.45)
      imgui.push_style_color(23, C.accent_dim[1], C.accent_dim[2], C.accent_dim[3], 0.55)
      imgui.push_style_color(0,  C.accent[1], C.accent[2], C.accent[3], 1.0)
    else
      imgui.push_style_color(21, 0.0, 0.0, 0.0, 0.0)
      imgui.push_style_color(22, C.bg_field_hov[1], C.bg_field_hov[2], C.bg_field_hov[3], 1.0)
      imgui.push_style_color(23, C.bg_field_act[1], C.bg_field_act[2], C.bg_field_act[3], 1.0)
      imgui.push_style_color(0,  C.text_primary[1], C.text_primary[2], C.text_primary[3], 1.0)
    end

    if imgui.button(label .. "##aegis_tab" .. i, SIDEBAR_W - 16, ROW_H) then
      new_sel = i
    end
    imgui.pop_style_color(4)
  end

  imgui.end_child()
  imgui.pop_style_color(1)

  imgui.same_line(0, 8)

  return new_sel
end

return Sidebar
