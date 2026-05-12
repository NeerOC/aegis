-- ImGui menu system (mirrors Aegis common/menu.lua).

local imgui = require("imgui")

---@class Menu
---@field OptionMenus table[] Registered class/spec option panels.
---@field Open boolean Whether the main Aegis window is visible.
Menu = Menu or {}
Menu.OptionMenus = {}
Menu.Open = true

function Menu:Initialize()
  self.OptionMenus = {}
  self.Open = true
  print("[Aegis] Menu initialized")
end

function Menu:AddOptionMenu(options)
  if not options or not options.Name then
    print("[Aegis] Menu:AddOptionMenu — missing Name field")
    return
  end
  if not options.Widgets then
    print("[Aegis] Menu:AddOptionMenu — missing Widgets field")
    return
  end
  self.OptionMenus[#self.OptionMenus + 1] = options
end

local function draw_widget(w)
  if not w.type then return end

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
    local lo           = w.min or 0
    local hi           = w.max or 100
    local cur          = AegisSettings[safe_uid] or w.default or lo
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

function Menu:Draw()
  if not self.Open then return end

  imgui.set_next_window_size(320, 400, 4)
  local visible, open = imgui.begin_window("Aegis", 0)
  if not visible then
    imgui.end_window()
    return
  end
  if not open then self.Open = false end

  if Me then
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
    local label = string.format("%s — %s", class_name, spec_name)
    if AegisSettings.AegisSpecManualOverride then
      label = label .. " [OVERRIDE]"
    end
    imgui.text_colored(0.4, 0.8, 1.0, 1.0, label)
    if Me.SpecId > 0 then
      imgui.same_line(0, 8)
      imgui.text_colored(0.5, 0.5, 0.5, 1.0,
        string.format("(spec %d)", Me.SpecId))
    end
  else
    imgui.text_colored(0.6, 0.6, 0.6, 1.0, "Not logged in")
  end

  imgui.separator()

  local now = os.clock()
  local last = Aegis._last_cast
  if last and last ~= "" then
    local age = now - (Aegis._last_cast_time or 0)
    if age < 5 then
      local tgt_name = Aegis._last_cast_tgt or ""
      imgui.text_colored(0.3, 1.0, 0.4, 1.0,
        string.format("Cast: %s -> %s", last, tgt_name))
    end
  end

  local fail = Aegis._last_fail
  if fail and fail ~= "" then
    local age = now - (Aegis._last_fail_time or 0)
    if age < 3 then
      imgui.text_colored(1.0, 0.3, 0.3, 1.0,
        string.format("FAIL: %s (backed off 1s)", fail))
    end
  end

  if Combat and Combat.BestTarget then
    local bt = Combat.BestTarget
    imgui.text(string.format("Target: %s (%.0f%%)", bt.Name, bt.HealthPct))
    imgui.same_line(0, 8)
    imgui.text_colored(0.5, 0.5, 0.5, 1.0,
      string.format("[%d enemies]", Combat.Enemies or 0))
  end

  imgui.separator()

  if imgui.collapsing_header("Combat") then
    if AegisSettings.AegisAutoTarget == nil then AegisSettings.AegisAutoTarget = false end
    local ch1, v1 = imgui.checkbox("Auto-target##aegis", AegisSettings.AegisAutoTarget)
    if ch1 then AegisSettings.AegisAutoTarget = v1 end

    if AegisSettings.AegisAttackOOC == nil then AegisSettings.AegisAttackOOC = false end
    local ch2, v2 = imgui.checkbox("Attack out of combat##aegis", AegisSettings.AegisAttackOOC)
    if ch2 then AegisSettings.AegisAttackOOC = v2 end

    if AegisSettings.AegisAttackTarget == nil then AegisSettings.AegisAttackTarget = true end
    local ch5, v5 = imgui.checkbox("Always attack current target##aegis", AegisSettings.AegisAttackTarget)
    if ch5 then AegisSettings.AegisAttackTarget = v5 end
  end

  if imgui.collapsing_header("General") then
    if AegisSettings.AegisEnabled == nil then AegisSettings.AegisEnabled = true end
    local ch3, v3 = imgui.checkbox("Enabled##aegis_en", AegisSettings.AegisEnabled)
    if ch3 then AegisSettings.AegisEnabled = v3 end

    if AegisSettings.AegisSpellDebug == nil then AegisSettings.AegisSpellDebug = false end
    local chsd, vsd = imgui.checkbox("Spell Debug Window##aegis_spelldebug", AegisSettings.AegisSpellDebug)
    if chsd then AegisSettings.AegisSpellDebug = vsd end

    if AegisSettings.AegisCastSuccessThrottleMs == nil then AegisSettings.AegisCastSuccessThrottleMs = 30 end
    local ch_ct, v_ct = imgui.slider_int("Cast throttle (ms)##aegis_cast_throttle",
      AegisSettings.AegisCastSuccessThrottleMs, 0, 1000)
    if ch_ct then AegisSettings.AegisCastSuccessThrottleMs = v_ct end
    imgui.text("Per-spell-ID delay added after cast completion")

    if BehaviorToggle and BehaviorToggle.DrawOptions then
      imgui.separator()
      pcall(BehaviorToggle.DrawOptions)
    end
  end

  if imgui.collapsing_header("Interrupts") then
    if AegisSettings.AegisInterruptMode == nil then AegisSettings.AegisInterruptMode = 0 end
    local mode_options = { "All", "Whitelist", "None" }
    local cur_mode = AegisSettings.AegisInterruptMode or 0
    local preview = mode_options[cur_mode + 1] or "All"
    if imgui.begin_combo("Interrupt Mode##aegis_interrupt_mode", preview) then
      for i, opt in ipairs(mode_options) do
        local sel = (i - 1 == cur_mode)
        if imgui.selectable(opt .. "##interrupt_mode" .. i, sel) then
          AegisSettings.AegisInterruptMode = i - 1
        end
      end
      imgui.end_combo()
    end

    if AegisSettings.AegisInterruptTiming == nil then AegisSettings.AegisInterruptTiming = false end
    local timing_changed, timing_val = imgui.checkbox("Enable Advanced Timing##aegis_timing",
      AegisSettings.AegisInterruptTiming)
    if timing_changed then AegisSettings.AegisInterruptTiming = timing_val end

    if AegisSettings.AegisInterruptTiming then
      if AegisSettings.AegisInterruptPercentage == nil then AegisSettings.AegisInterruptPercentage = 80 end
      local pct_changed, pct_val = imgui.slider_int("Interrupt at %##aegis_interrupt_pct",
        AegisSettings.AegisInterruptPercentage, 10, 95)
      if pct_changed then AegisSettings.AegisInterruptPercentage = pct_val end
      imgui.text("Interrupts casts when ≤" .. (AegisSettings.AegisInterruptPercentage or 80) .. "% complete")
      imgui.text("Channels interrupted after random delay (700ms ± 400ms)")
    end
  end

  if Me and Me._spec_options then
    if imgui.collapsing_header("Specialization") then
      local detected = Me.SpecName or ""
      local is_override = AegisSettings.AegisSpecManualOverride

      if detected ~= "" then
        imgui.text_colored(0.3, 1.0, 0.4, 1.0, "Detected: " .. detected)
      end

      if is_override then
        imgui.text_colored(1.0, 0.8, 0.2, 1.0,
          "OVERRIDE active: " .. (AegisSettings.AegisSpecName or "?"))
        if imgui.button("Reset to auto-detect##aegis_spec_reset") then
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
      else
        imgui.text_colored(0.5, 0.5, 0.5, 1.0,
          "Override below if detection is wrong:")
      end

      local cur = AegisSettings.AegisSpecIdx or 0
      local preview = Me._spec_options[cur + 1] or "(auto)"
      if imgui.begin_combo("Spec##aegis_spec", preview) then
        for i, name in ipairs(Me._spec_options) do
          if imgui.selectable(name .. "##spec" .. i, (i - 1) == cur) then
            AegisSettings.AegisSpecIdx = i - 1
            AegisSettings.AegisSpecName = name
            if name ~= detected then
              AegisSettings.AegisSpecManualOverride = true
            else
              AegisSettings.AegisSpecManualOverride = false
            end
          end
        end
        imgui.end_combo()
      end

      if wow and wow.talent_tabs then
        local ok, tabs = pcall(wow.talent_tabs)
        if ok and tabs and #tabs > 0 then
          imgui.text_colored(0.5, 0.5, 0.5, 1.0, "Talent tabs:")
          for _, t in ipairs(tabs) do
            imgui.text_colored(0.5, 0.5, 0.5, 1.0,
              string.format("  tab=%d  id=%d  pts=%d",
                t.tab or -1, t.tab_id or 0, t.points or 0))
          end
        end
      end
    end
  end

  for _, opts in ipairs(self.OptionMenus) do
    if imgui.collapsing_header(opts.Name) then
      for _, w in ipairs(opts.Widgets) do
        draw_widget(w)
      end
    end
  end

  imgui.end_window()
end

return Menu
