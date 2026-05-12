-- Spec tab — detection, override, talent tabs.

local imgui = require("imgui")
local Theme = include and include("common/menu/theme.lua")
    or require("common.menu.theme")
local Widgets = include and include("common/menu/widgets.lua")
    or require("common.menu.widgets")

local C = Theme.C
local Spec = {}

function Spec.Draw()
  -- Early-out variant: just one "not logged in" card.
  if not Me or not Me._spec_options then
    local p_none  = { text = 1 }
    local total_h = Widgets.tab_height({ p_none })
    imgui.begin_child("aegis_spec", Theme.CONTENT_W, total_h, false, 24)
    Widgets.card("spec_none", "SPECIALIZATION", 0, Widgets.card_height(p_none), function()
      imgui.text_colored(C.text_secondary[1], C.text_secondary[2], C.text_secondary[3], 1.0,
        "Not logged in or spec options not loaded")
    end)
    imgui.end_child()
    return
  end

  -- Status card grows with override state; pick-spec card grows with spec
  -- count; talent table grows with how many tabs were returned.
  local p_status = { text = 1 }
  if AegisSettings.AegisSpecManualOverride then
    p_status.text = 2
  end

  local n_specs = Me._spec_options and #Me._spec_options or 0
  local p_pick  = { text = 1, radio = n_specs }

  local talent_rows = 4
  if wow and wow.talent_tabs then
    local ok, tabs = pcall(wow.talent_tabs)
    if ok and tabs then talent_rows = 1 + math.max(1, #tabs) end
  end
  local p_talents = { table = talent_rows }

  local total_h = Widgets.tab_height({ p_status, p_pick, p_talents })
  imgui.begin_child("aegis_spec", Theme.CONTENT_W, total_h, false, 24)

  Widgets.card("spec_status", "STATUS", 0, Widgets.card_height(p_status), function()
    local detected = Me.SpecName or ""
    if detected ~= "" then
      imgui.text("Detected:")
      imgui.same_line(0, 8)
      imgui.text_colored(C.success[1], C.success[2], C.success[3], 1.0, detected)
    else
      imgui.text_colored(C.text_secondary[1], C.text_secondary[2], C.text_secondary[3], 1.0,
        "No spec detected (not enough talent points?)")
    end

    if AegisSettings.AegisSpecManualOverride then
      imgui.text("Override:")
      imgui.same_line(0, 8)
      imgui.text_colored(C.accent_2[1], C.accent_2[2], C.accent_2[3], 1.0,
        AegisSettings.AegisSpecName or "?")
      imgui.same_line(0, 12)
      if imgui.small_button("Reset##spec_reset") then
        AegisSettings.AegisSpecManualOverride = false
        if detected ~= "" then
          AegisSettings.AegisSpecName = detected
          for i, name in ipairs(Me._spec_options) do
            if name == detected then
              AegisSettings.AegisSpecIdx = i - 1
              break
            end
          end
        end
      end
    end
  end)

  Widgets.card("spec_pick", "PICK SPEC", 0, Widgets.card_height(p_pick), function()
    imgui.text_colored(C.text_secondary[1], C.text_secondary[2], C.text_secondary[3], 1.0,
      "Override below if detection is wrong:")
    imgui.spacing()
    local cur = AegisSettings.AegisSpecIdx or 0
    for i, name in ipairs(Me._spec_options) do
      local idx = i - 1
      if imgui.radio_button(name .. "##spec_r" .. i, idx == cur) then
        AegisSettings.AegisSpecIdx = idx
        AegisSettings.AegisSpecName = name
        if name ~= (Me.SpecName or "") then
          AegisSettings.AegisSpecManualOverride = true
        else
          AegisSettings.AegisSpecManualOverride = false
        end
      end
    end
  end)

  Widgets.card("spec_talents", "TALENT TABS", 0, Widgets.card_height(p_talents), function()
    if not (wow and wow.talent_tabs) then
      imgui.text_colored(C.text_secondary[1], C.text_secondary[2], C.text_secondary[3], 1.0,
        "wow.talent_tabs unavailable")
      return
    end
    local ok, tabs = pcall(wow.talent_tabs)
    if not (ok and tabs and #tabs > 0) then
      imgui.text_colored(C.text_secondary[1], C.text_secondary[2], C.text_secondary[3], 1.0,
        "No talent data")
      return
    end
    -- SizingFixedFit (1<<13 = 8192) — required to pass explicit column widths.
    if imgui.begin_table("spec_talents_tbl", 3, 8192) then
      imgui.table_setup_column("Tab", 0, 60)
      imgui.table_setup_column("ID", 0, 80)
      imgui.table_setup_column("Points", 0, 80)
      imgui.table_headers_row()
      for _, t in ipairs(tabs) do
        imgui.table_next_row()
        imgui.table_next_column()
        imgui.text(tostring(t.tab or -1))
        imgui.table_next_column()
        imgui.text(tostring(t.tab_id or 0))
        imgui.table_next_column()
        imgui.text(tostring(t.points or 0))
      end
      imgui.end_table()
    end
  end)

  imgui.end_child()
end

return Spec
