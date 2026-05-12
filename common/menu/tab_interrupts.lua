-- Interrupts tab — mode, timing, live log.

local imgui = require("imgui")
local Theme = include and include("common/menu/theme.lua")
    or require("common.menu.theme")
local Widgets = include and include("common/menu/widgets.lua")
    or require("common.menu.widgets")

local C = Theme.C
local Interrupts = {}

local MODE_OPTIONS = { "All", "Whitelist", "None" }

function Interrupts.Draw()
  -- TIMING card has variable height based on the toggle.
  local p_mode   = { button = 1 }
  local p_timing = { checkbox = 1 }
  if AegisSettings.AegisInterruptTiming then
    p_timing.slider = 1
    p_timing.text = 2
  end
  -- RECENT card sized to the current log count (1 line minimum).
  local log = Aegis._interrupt_log
  local rows = (log and #log > 0) and #log or 1
  local p_log = { text = rows }

  local total_h = Widgets.tab_height({ p_mode, p_timing, p_log })
  imgui.begin_child("aegis_interrupts", Theme.CONTENT_W, total_h, false, 24)

  Widgets.card("int_mode", "MODE", 0, Widgets.card_height(p_mode), function()
    local cur = AegisSettings.AegisInterruptMode or 0
    local new_sel = Widgets.segmented("int_mode_seg", MODE_OPTIONS, cur)
    if new_sel ~= cur then AegisSettings.AegisInterruptMode = new_sel end
  end)

  Widgets.card("int_timing", "TIMING", 0, Widgets.card_height(p_timing), function()
    local cur = AegisSettings.AegisInterruptTiming
    if cur == nil then cur = false end
    local ch, v = imgui.checkbox("Advanced timing##int_t", cur)
    if ch then AegisSettings.AegisInterruptTiming = v end

    if AegisSettings.AegisInterruptTiming then
      if AegisSettings.AegisInterruptPercentage == nil then
        AegisSettings.AegisInterruptPercentage = 80
      end
      local pch, pv = imgui.slider_int("Interrupt at %##int_pct",
        AegisSettings.AegisInterruptPercentage, 10, 95)
      if pch then AegisSettings.AegisInterruptPercentage = pv end
      imgui.text_colored(C.text_secondary[1], C.text_secondary[2], C.text_secondary[3], 1.0,
        string.format("Casts interrupted at <= %d%% complete",
          AegisSettings.AegisInterruptPercentage or 80))
      imgui.text_colored(C.text_secondary[1], C.text_secondary[2], C.text_secondary[3], 1.0,
        "Channels delayed 700ms +/- 400ms")
    end
  end)

  Widgets.card("int_log", "RECENT INTERRUPTS", 0, Widgets.card_height(p_log), function()
    local log = Aegis._interrupt_log
    if not log or #log == 0 then
      imgui.text_colored(C.text_secondary[1], C.text_secondary[2], C.text_secondary[3], 1.0,
        "No interrupts logged yet")
      return
    end
    local now = os.clock()
    for i = #log, 1, -1 do
      local e = log[i]
      if e then
        local age = now - (e.time or 0)
        imgui.text(string.format("%5.1fs ago", age))
        imgui.same_line(0, 12)
        imgui.text_colored(C.text_primary[1], C.text_primary[2], C.text_primary[3], 1.0,
          (e.interrupt or "?") .. " -> " .. (e.target or "?"))
        imgui.same_line(0, 8)
        imgui.text_colored(C.text_secondary[1], C.text_secondary[2], C.text_secondary[3], 1.0,
          "(" .. (e.spell or "?") .. ")")
      end
    end
  end)

  imgui.end_child()
end

return Interrupts
