-- Shared UI building blocks: pills, segmented buttons, HP bars, cards,
-- and the legacy OptionMenu widget renderer (kept verbatim from the
-- old menu.lua so per-class plugins continue to work).

local imgui = require("imgui")
local Theme = include and include("common/menu/theme.lua")
    or require("common.menu.theme")

local C = Theme.C
local M = {}

-- ── Status pill: rounded rect with colored text, drawn as a button-like badge ──
-- Renders inline. Use after a same_line() if you want it on the same row.
---@param label string
---@param color number[]  RGBA 0-1
function M.status_pill(label, color)
  imgui.push_style_color(21, 0.0, 0.0, 0.0, 0.0)   -- Button = transparent
  imgui.push_style_color(22, 0.0, 0.0, 0.0, 0.0)   -- ButtonHovered
  imgui.push_style_color(23, 0.0, 0.0, 0.0, 0.0)   -- ButtonActive
  imgui.push_style_color(0,  color[1], color[2], color[3], color[4]) -- Text
  imgui.push_style_color(5,  color[1], color[2], color[3], 0.55)     -- Border
  imgui.push_style_var(13, 1)                       -- FrameBorderSize = 1
  imgui.small_button(" " .. label .. " ")
  imgui.pop_style_var(1)
  imgui.pop_style_color(5)
end

-- ── Segmented buttons (radio-style pick from a small set) ────────
-- Returns the new selected index (0-based) — same as the input if unchanged.
---@param id string Unique id for the group (used in widget ids).
---@param options string[]
---@param current number 0-based current selection.
---@return number new_selection
function M.segmented(id, options, current)
  local sel = current or 0
  for i, opt in ipairs(options) do
    if i > 1 then imgui.same_line(0, 4) end
    local idx = i - 1
    local active = (idx == sel)
    if active then
      imgui.push_style_color(21, C.accent[1], C.accent[2], C.accent[3], C.accent[4])
      imgui.push_style_color(22, C.accent_hov[1], C.accent_hov[2], C.accent_hov[3], 1.0)
      imgui.push_style_color(23, C.accent[1], C.accent[2], C.accent[3], 1.0)
      imgui.push_style_color(0,  0.05, 0.07, 0.10, 1.0)
    end
    if imgui.button(opt .. "##" .. id .. idx) then
      sel = idx
    end
    if active then imgui.pop_style_color(4) end
  end
  return sel
end

-- ── HP/Power bar (color-graded fill) ──────────────────────────────
---@param fraction number 0..1
---@param width number Pixels.
---@param overlay? string Optional text shown on top (e.g. "78%").
function M.hp_bar(fraction, width, overlay)
  fraction = math.max(0, math.min(1, fraction or 0))
  -- Color shifts: green > 60%, amber 30-60%, red < 30%.
  local r, g, b
  if fraction > 0.6 then
    r, g, b = C.success[1], C.success[2], C.success[3]
  elseif fraction > 0.3 then
    r, g, b = C.warn[1], C.warn[2], C.warn[3]
  else
    r, g, b = C.error_col[1], C.error_col[2], C.error_col[3]
  end
  imgui.push_style_color(40, r, g, b, 1.0) -- PlotHistogram (used by progress_bar fill)
  imgui.push_style_color(7,  C.bg_field[1], C.bg_field[2], C.bg_field[3], 1.0)
  -- progress_bar(fraction, overlay) — width passed via... actually progress_bar
  -- uses item-width; clamp by push_item_width if needed. Plain call here.
  imgui.progress_bar(fraction, overlay or string.format("%.0f%%", fraction * 100))
  imgui.pop_style_color(2)
end

-- ── Card height calculator ───────────────────────────────────────
-- height = 0 in ImGui's begin_child means "fill the rest of the parent",
-- NOT "auto-fit to content". So heights must be explicit. Use this helper
-- to size cards from a content manifest instead of eyeballing pixels.
--
-- parts table fields (all optional, all numbers):
--   text     = lines of text or text_colored
--   checkbox = imgui.checkbox rows
--   slider   = imgui.slider_int/slider_float rows
--   radio    = imgui.radio_button rows
--   button   = imgui.button / small_button rows (incl. on its own line)
--   table    = rows in an imgui.begin_table (header counts as 1)
--   sep      = imgui.separator + spacing within the card body
local CARD_HEADER     = 44  -- top dummy(4) + title text + separator + spacing
local CARD_TAIL       = 18  -- breathing room at the bottom
local LINE_TEXT       = 24
local LINE_CHECKBOX   = 28
local LINE_SLIDER     = 30
local LINE_RADIO      = 26
local LINE_BUTTON     = 30
local LINE_TABLE_ROW  = 24
local LINE_SEPARATOR  = 12

---@param parts table  Content manifest (see comment above).
---@return number height_px
function M.card_height(parts)
  parts = parts or {}
  local h = CARD_HEADER + CARD_TAIL
  h = h + (parts.text     or 0) * LINE_TEXT
  h = h + (parts.checkbox or 0) * LINE_CHECKBOX
  h = h + (parts.slider   or 0) * LINE_SLIDER
  h = h + (parts.radio    or 0) * LINE_RADIO
  h = h + (parts.button   or 0) * LINE_BUTTON
  h = h + (parts.table    or 0) * LINE_TABLE_ROW
  h = h + (parts.sep      or 0) * LINE_SEPARATOR
  return h
end

-- ItemSpacing.y from theme.lua → vertical gap ImGui inserts between
-- sibling widgets/children. Keep these in sync with theme.lua.
local TAB_INTERCARD_SPACING = 8

---Sum card heights + inter-card spacing for use as the explicit height of a
---tab's outer begin_child wrapper. The window's AlwaysAutoResize flag picks
---up that explicit height and packs the window around it.
---@param parts_list table[]  Array of content manifests, one per card.
---@return number height_px
function M.tab_height(parts_list)
  local h = 0
  for i, parts in ipairs(parts_list or {}) do
    h = h + M.card_height(parts)
    if i < #parts_list then h = h + TAB_INTERCARD_SPACING end
  end
  return h
end

-- ── Card: titled child panel with a body callback ────────────────
-- Width = 0 means "fill remaining horizontal space" (matches ImGui's
-- begin_child behavior). Pass height from M.card_height() — see above.
-- NoScrollbar is set so content over-tall for the box gets clipped rather
-- than producing a scroll handle.
---@param id string Unique child-window id.
---@param title string Visible title text.
---@param width number Pixels (0 = fill remaining width).
---@param height number Pixels. Required (>0). Use a value that comfortably fits the body.
---@param body fun() Render callback for the body.
-- Extra padding applied inside each card so title + body don't touch the
-- card border. WindowPadding via push_style_var doesn't propagate to
-- begin_child in this binding, so we apply it manually with indent() (left
-- padding) and dummy() (top padding). The host's WindowPadding still
-- provides the right + bottom padding inside the child.
local CARD_INDENT  = 6
local CARD_TOP_PAD = 4

-- Bump card_height() above to account for the extra top dummy; ensures
-- the explicit height we pass to begin_child still fits the content.

function M.card(id, title, width, height, body)
  imgui.push_style_color(3, C.bg_panel_alt[1], C.bg_panel_alt[2], C.bg_panel_alt[3], C.bg_panel_alt[4])
  imgui.begin_child(id, width or 0, height or 80, true, 8) -- 8 = NoScrollbar
  imgui.dummy(0, CARD_TOP_PAD)
  imgui.indent(CARD_INDENT)
  if title and title ~= "" then
    imgui.text_colored(C.text_secondary[1], C.text_secondary[2], C.text_secondary[3], 1.0, title)
    imgui.separator()
    imgui.spacing()
  end
  if body then pcall(body) end
  imgui.unindent(CARD_INDENT)
  imgui.end_child()
  imgui.pop_style_color(1)
end

-- ── Vertical air helper ──────────────────────────────────────────
function M.vspace(h)
  imgui.dummy(0, h or 6)
end

-- ── Section heading (small, faded, all-caps style via the text itself) ──
---@param text string
function M.section_heading(text)
  imgui.text_colored(C.text_secondary[1], C.text_secondary[2], C.text_secondary[3], 1.0, text)
end

-- ── Legacy widget renderer (unchanged contract for Menu.OptionMenus) ──
-- Each widget table: { type, text, uid, default, min, max, options, draw }
function M.draw_legacy_widget(w)
  if not w or not w.type then return end

  local safe_uid = w.uid and w.uid:gsub("%s+", "") or nil
  local label = w.text or ""
  if safe_uid then
    label = string.format("%s##%s", w.text, safe_uid)
  end

  if w.type == "text" then
    imgui.text(w.text or "")
    return
  end
  if w.type == "custom" and type(w.draw) == "function" then
    pcall(w.draw)
    return
  end
  if not safe_uid then return end

  if AegisSettings[safe_uid] == nil and w.default ~= nil then
    AegisSettings[safe_uid] = w.default
  end

  if w.type == "checkbox" then
    local changed, val = imgui.checkbox(label, AegisSettings[safe_uid] or false)
    if changed then AegisSettings[safe_uid] = val end
  elseif w.type == "slider" then
    local lo = w.min or 0
    local hi = w.max or 100
    local cur = AegisSettings[safe_uid] or w.default or lo
    local changed, val = imgui.slider_int(label, cur, lo, hi)
    if changed then AegisSettings[safe_uid] = val end
  elseif w.type == "combobox" then
    if not w.options or type(w.options) ~= "table" then return end
    local cur_idx = AegisSettings[safe_uid] or 0
    local preview = w.options[cur_idx + 1] or "(none)"
    if imgui.begin_combo(label, preview) then
      for i, opt in ipairs(w.options) do
        local sel = (i - 1 == cur_idx)
        if imgui.selectable(opt .. "##" .. safe_uid .. i, sel) then
          AegisSettings[safe_uid] = i - 1
        end
      end
      imgui.end_combo()
    end
  end
end

return M
