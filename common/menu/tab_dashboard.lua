-- Dashboard tab — live state: character, target, activity, engine, quick toggles.

local imgui = require("imgui")
local Theme = include and include("common/menu/theme.lua")
    or require("common.menu.theme")
local Widgets = include and include("common/menu/widgets.lua")
    or require("common.menu.widgets")

local C = Theme.C
local Dashboard = {}

local function fade_alpha(age, window)
  if age >= window then return 0 end
  return 1.0 - (age / window)
end

function Dashboard.Draw()
  local p_char     = { text = 1 }
  local p_combat   = { text = 2 }
  local p_activity = { text = 2 }
  local p_engine   = { text = 2 }
  local p_quick    = { checkbox = 1 }
  local total_h    = Widgets.tab_height({ p_char, p_combat, p_activity, p_engine, p_quick })
  imgui.begin_child("aegis_dash", Theme.CONTENT_W, total_h, false, 24)

  -- ── Character card ─────────────────────────────────────────────
  Widgets.card("dash_char", "CHARACTER", 0, Widgets.card_height(p_char), function()
    if not Me then
      imgui.text_colored(C.text_secondary[1], C.text_secondary[2], C.text_secondary[3], 1.0, "Not logged in")
      return
    end
    local class_name = Me.ClassName or Me._class_name or "Unknown"
    local spec_name
    if AegisSettings.AegisSpecManualOverride then
      spec_name = AegisSettings.AegisSpecName or "?"
    else
      spec_name = Me.SpecName
      if not spec_name or spec_name == "" then
        spec_name = AegisSettings.AegisSpecName or "?"
      end
    end
    imgui.text_colored(C.accent[1], C.accent[2], C.accent[3], 1.0,
      class_name .. " — " .. spec_name)
    if AegisSettings.AegisSpecManualOverride then
      imgui.same_line(0, 8)
      Widgets.status_pill("OVERRIDE", C.accent_2)
    end
  end)

  -- ── Combat card ────────────────────────────────────────────────
  Widgets.card("dash_combat", "COMBAT", 0, Widgets.card_height(p_combat), function()
    if Combat and Combat.BestTarget then
      local bt = Combat.BestTarget
      imgui.text("Target")
      imgui.same_line(0, 12)
      imgui.text_colored(C.text_primary[1], C.text_primary[2], C.text_primary[3], 1.0, bt.Name or "?")
      imgui.same_line(0, 12)
      Widgets.hp_bar((bt.HealthPct or 0) / 100, 0,
        string.format("%.0f%%", bt.HealthPct or 0))
      local enemies = Combat.Enemies or 0
      imgui.text_colored(C.text_secondary[1], C.text_secondary[2], C.text_secondary[3], 1.0,
        string.format("Enemies in range: %d", enemies))
      if enemies > 0 then
        imgui.same_line(0, 8)
        Widgets.status_pill("LIVE", C.success)
      end
    else
      imgui.text_colored(C.text_secondary[1], C.text_secondary[2], C.text_secondary[3], 1.0,
        "No target")
    end
  end)

  -- ── Activity card ──────────────────────────────────────────────
  Widgets.card("dash_activity", "ACTIVITY", 0, Widgets.card_height(p_activity), function()
    local now = os.clock()
    local last = Aegis._last_cast
    if last and last ~= "" then
      local age = now - (Aegis._last_cast_time or 0)
      local a = fade_alpha(age, 5)
      if a > 0 then
        imgui.text_colored(C.success[1], C.success[2], C.success[3], a,
          string.format("Cast: %s -> %s  (%.0fms ago)", last, Aegis._last_cast_tgt or "", age * 1000))
      end
    end
    local fail = Aegis._last_fail
    if fail and fail ~= "" then
      local age = now - (Aegis._last_fail_time or 0)
      local a = fade_alpha(age, 3)
      if a > 0 then
        imgui.text_colored(C.error_col[1], C.error_col[2], C.error_col[3], a,
          string.format("FAIL: %s  (%.1fs ago)", fail, age))
      end
    end
  end)

  -- ── Engine card ────────────────────────────────────────────────
  -- 2 text lines ("Now doing X", "Tick load Y/50ms" inline with progress_bar).
  Widgets.card("dash_engine", "ENGINE", 0, Widgets.card_height(p_engine), function()
    imgui.text("Now doing")
    imgui.same_line(0, 12)
    local action = Aegis._current_action or "IDLE"
    local color = C.text_primary
    if action == "IDLE" then color = C.text_secondary end
    imgui.text_colored(color[1], color[2], color[3], 1.0, action)

    local load_ms = Aegis._tick_load_ms or 0
    local frac = math.min(1.0, load_ms / 50.0)
    imgui.text(string.format("Tick load: %.1f / 50 ms", load_ms))
    imgui.same_line(0, 8)
    -- progress_bar has no width arg; wrap it in a fixed-width child so it
    -- doesn't spill past the card edge.
    imgui.begin_child("dash_eng_bar", 180, 22, false, 8)
    imgui.progress_bar(frac, "")
    imgui.end_child()
  end)

  -- ── Quick toggles ──────────────────────────────────────────────
  -- 4 checkboxes on one row counts as 1 checkbox-row tall.
  Widgets.card("dash_quick", "QUICK TOGGLES", 0, Widgets.card_height(p_quick), function()
    local ch, v
    ch, v = imgui.checkbox("Master##q_en", AegisSettings.AegisEnabled or false)
    if ch then AegisSettings.AegisEnabled = v end
    imgui.same_line(0, 16)
    ch, v = imgui.checkbox("Auto-target##q_at", AegisSettings.AegisAutoTarget or false)
    if ch then AegisSettings.AegisAutoTarget = v end
    imgui.same_line(0, 16)
    ch, v = imgui.checkbox("Attack target##q_attk", AegisSettings.AegisAttackTarget or false)
    if ch then AegisSettings.AegisAttackTarget = v end
    imgui.same_line(0, 16)
    ch, v = imgui.checkbox("OOC##q_ooc", AegisSettings.AegisAttackOOC or false)
    if ch then AegisSettings.AegisAttackOOC = v end
  end)

  imgui.end_child()
end

return Dashboard
