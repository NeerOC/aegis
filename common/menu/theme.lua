-- Aegis UI theme — dark graphite base, cyan accent.
-- Push at the top of Menu:Draw(), pop with the matching count before end_window.

local imgui = require("imgui")

-- ── ImGui enum constants (no host stub provides these) ─────────────
local ImGuiStyleVar_WindowPadding     = 2
local ImGuiStyleVar_WindowRounding    = 3
local ImGuiStyleVar_WindowBorderSize  = 4
local ImGuiStyleVar_ChildRounding     = 7
local ImGuiStyleVar_ChildBorderSize   = 8
local ImGuiStyleVar_PopupRounding     = 9
local ImGuiStyleVar_FramePadding      = 11
local ImGuiStyleVar_FrameRounding     = 12
local ImGuiStyleVar_FrameBorderSize   = 13
local ImGuiStyleVar_ItemSpacing       = 14
local ImGuiStyleVar_ItemInnerSpacing  = 15
local ImGuiStyleVar_ScrollbarSize     = 18
local ImGuiStyleVar_ScrollbarRounding = 19
local ImGuiStyleVar_GrabRounding      = 21
local ImGuiStyleVar_TabRounding       = 22

local ImGuiCol_Text                  = 0
local ImGuiCol_TextDisabled          = 1
local ImGuiCol_WindowBg              = 2
local ImGuiCol_ChildBg               = 3
local ImGuiCol_PopupBg               = 4
local ImGuiCol_Border                = 5
local ImGuiCol_FrameBg               = 7
local ImGuiCol_FrameBgHovered        = 8
local ImGuiCol_FrameBgActive         = 9
local ImGuiCol_TitleBg               = 10
local ImGuiCol_TitleBgActive         = 11
local ImGuiCol_ScrollbarBg           = 14
local ImGuiCol_ScrollbarGrab         = 15
local ImGuiCol_ScrollbarGrabHovered  = 16
local ImGuiCol_ScrollbarGrabActive   = 17
local ImGuiCol_CheckMark             = 18
local ImGuiCol_SliderGrab            = 19
local ImGuiCol_SliderGrabActive      = 20
local ImGuiCol_Button                = 21
local ImGuiCol_ButtonHovered         = 22
local ImGuiCol_ButtonActive          = 23
local ImGuiCol_Header                = 24
local ImGuiCol_HeaderHovered         = 25
local ImGuiCol_HeaderActive          = 26
local ImGuiCol_Separator             = 27
local ImGuiCol_Tab                   = 33
local ImGuiCol_TabHovered            = 34
local ImGuiCol_TabActive             = 35

-- ── Palette (RGBA 0-1) ────────────────────────────────────────────
local C = {
  bg_window      = { 0.07, 0.08, 0.10, 0.96 },
  bg_panel       = { 0.10, 0.11, 0.14, 1.00 },
  bg_panel_alt   = { 0.13, 0.14, 0.17, 1.00 },
  bg_field       = { 0.16, 0.17, 0.21, 1.00 },
  bg_field_hov   = { 0.20, 0.22, 0.27, 1.00 },
  bg_field_act   = { 0.24, 0.26, 0.32, 1.00 },
  accent         = { 0.30, 0.78, 0.95, 1.00 },
  accent_hov     = { 0.42, 0.86, 1.00, 1.00 },
  accent_dim     = { 0.30, 0.78, 0.95, 0.25 },
  accent_2       = { 0.62, 0.45, 0.95, 1.00 },
  success        = { 0.30, 0.85, 0.50, 1.00 },
  warn           = { 1.00, 0.78, 0.30, 1.00 },
  error_col      = { 0.95, 0.35, 0.40, 1.00 },
  text_primary   = { 0.90, 0.92, 0.95, 1.00 },
  text_secondary = { 0.55, 0.58, 0.65, 1.00 },
  border         = { 0.20, 0.22, 0.27, 1.00 },
}

local Theme = { C = C }

-- ── Push order matters for pop-count tracking ─────────────────────
local STYLE_VARS = {
  { ImGuiStyleVar_WindowRounding,    8 },
  { ImGuiStyleVar_ChildRounding,     6 },
  { ImGuiStyleVar_FrameRounding,     4 },
  { ImGuiStyleVar_GrabRounding,      4 },
  { ImGuiStyleVar_PopupRounding,     6 },
  { ImGuiStyleVar_TabRounding,       4 },
  { ImGuiStyleVar_ScrollbarRounding, 6 },
  { ImGuiStyleVar_WindowBorderSize,  0 },
  { ImGuiStyleVar_FrameBorderSize,   0 },
  { ImGuiStyleVar_ChildBorderSize,   0 },
  { ImGuiStyleVar_ScrollbarSize,     10 },
}

local STYLE_VARS_VEC2 = {
  { ImGuiStyleVar_WindowPadding,    12, 10 },
  { ImGuiStyleVar_FramePadding,     8,  5  },
  { ImGuiStyleVar_ItemSpacing,      8,  6  },
  { ImGuiStyleVar_ItemInnerSpacing, 6,  4  },
}

local STYLE_COLORS = {
  { ImGuiCol_WindowBg,             C.bg_window },
  { ImGuiCol_ChildBg,              C.bg_panel },
  { ImGuiCol_PopupBg,              C.bg_panel },
  { ImGuiCol_Border,               C.border },
  { ImGuiCol_FrameBg,              C.bg_field },
  { ImGuiCol_FrameBgHovered,       C.bg_field_hov },
  { ImGuiCol_FrameBgActive,        C.bg_field_act },
  { ImGuiCol_Button,               C.bg_field },
  { ImGuiCol_ButtonHovered,        C.bg_field_hov },
  { ImGuiCol_ButtonActive,         C.accent },
  { ImGuiCol_Header,               C.accent_dim },
  { ImGuiCol_HeaderHovered,        C.bg_field_hov },
  { ImGuiCol_HeaderActive,         C.accent_dim },
  { ImGuiCol_Tab,                  C.bg_panel },
  { ImGuiCol_TabHovered,           C.bg_field_hov },
  { ImGuiCol_TabActive,            C.accent_dim },
  { ImGuiCol_Separator,            C.border },
  { ImGuiCol_Text,                 C.text_primary },
  { ImGuiCol_TextDisabled,         C.text_secondary },
  { ImGuiCol_CheckMark,            C.accent },
  { ImGuiCol_SliderGrab,           C.accent },
  { ImGuiCol_SliderGrabActive,     C.accent_hov },
  { ImGuiCol_ScrollbarBg,          C.bg_panel },
  { ImGuiCol_ScrollbarGrab,        C.bg_field_act },
  { ImGuiCol_ScrollbarGrabHovered, C.accent_dim },
  { ImGuiCol_ScrollbarGrabActive,  C.accent },
  { ImGuiCol_TitleBg,              C.bg_panel },
  { ImGuiCol_TitleBgActive,        C.bg_panel_alt },
}

function Theme.Push()
  for _, v in ipairs(STYLE_VARS) do
    imgui.push_style_var(v[1], v[2])
  end
  for _, v in ipairs(STYLE_VARS_VEC2) do
    imgui.push_style_var_vec2(v[1], v[2], v[3])
  end
  for _, c in ipairs(STYLE_COLORS) do
    local col = c[2]
    imgui.push_style_color(c[1], col[1], col[2], col[3], col[4])
  end
end

function Theme.Pop()
  imgui.pop_style_color(#STYLE_COLORS)
  imgui.pop_style_var(#STYLE_VARS + #STYLE_VARS_VEC2)
end

-- ── Window flags ──────────────────────────────────────────────────
-- NoTitleBar(1) | NoCollapse(32) | NoScrollbar(8) | NoScrollWithMouse(16)
--   | AlwaysAutoResize(64)
-- AlwaysAutoResize makes the window pack to its content — no clipping,
-- no scroll, no manual drag-resize. Width may jiggle slightly on tab
-- switches because each tab's column has a different intrinsic height.
Theme.WindowFlags = 1 + 32 + 8 + 16 + 64

Theme.CondFirstUseEver = 4

-- ── Layout constants ──────────────────────────────────────────────
-- The cards column uses an explicit width so the auto-resizing window
-- has a stable horizontal target (otherwise it would jiggle per card).
Theme.SIDEBAR_W  = 130
Theme.CONTENT_W  = 480

return Theme
