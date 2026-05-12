-- Core-level on/off switch for the rotation, bound to an ImGui key.

local imgui = require("imgui")

---@class BehaviorToggle
local BehaviorToggle = {}

local _bind_pending = false

local _last_state = false

local SKIP_KEYS = {
  [0]   = true,
  [526] = true,
  [527] = true, [528] = true, [529] = true, [530] = true,
  [531] = true, [532] = true, [533] = true, [534] = true,
}

local KEY_NAMES = {
  [512]="Tab",     [513]="LeftArrow",  [514]="RightArrow",
  [515]="UpArrow", [516]="DownArrow",  [517]="PageUp",
  [518]="PageDown",[519]="Home",       [520]="End",
  [521]="Insert",  [522]="Delete",     [523]="Backspace",
  [524]="Space",   [525]="Enter",      [526]="Escape",
  [535]="Apostrophe",[536]="Comma",    [537]="Minus",
  [538]="Period",  [539]="Slash",      [540]="Semicolon",
  [541]="Equal",   [542]="LeftBracket",[543]="Backslash",
  [544]="RightBracket",[545]="GraveAccent",
}
for i = 0, 25 do KEY_NAMES[546 + i] = string.char(0x41 + i) end
for i = 0, 9  do KEY_NAMES[572 + i] = tostring(i) end
for i = 1, 12 do KEY_NAMES[583 + i] = "F" .. i end

local function key_label(code)
  if not code or code == 0 then return "(unbound)" end
  return KEY_NAMES[code] or ("#" .. code)
end

local function detect_any_press()
  for k = 512, 666 do
    if not SKIP_KEYS[k] then
      if imgui.is_key_pressed(k) then return k end
    end
  end
  return nil
end

-- Call every frame from plugin.lua onTick before the throttle.
function BehaviorToggle.Tick()
  if _bind_pending then
    local code = detect_any_press()
    if code then
      AegisSettings.AegisToggleKey = code
      _bind_pending = false
      print(string.format("[Aegis] Behavior toggle bound: %s",
                          key_label(code)))
    end
    return
  end

  local key = AegisSettings and AegisSettings.AegisToggleKey or 0
  if key == 0 then return end

  local pressed = imgui.is_key_pressed(key)
  if pressed and not _last_state then
    AegisSettings.AegisEnabled = not (AegisSettings.AegisEnabled == true)
    print(string.format("[Aegis] Rotation %s",
        AegisSettings.AegisEnabled and "ENABLED" or "PAUSED"))
  end
  _last_state = pressed
end

-- Renders the on-screen status badge near top center.
function BehaviorToggle.DrawIndicator()
  if not AegisSettings then return end
  local key = AegisSettings.AegisToggleKey or 0
  if key == 0 then return end
  if not (imgui.get_display_size and imgui.draw_text and imgui.color_u32) then
    return
  end

  local sx = imgui.get_display_size()
  if not sx or sx == 0 then return end

  local on = AegisSettings.AegisEnabled == true
  local label
  if on then
    label = string.format("ROTATION: ON  [%s to pause]", key_label(key))
  else
    label = string.format("ROTATION: PAUSED  [%s to resume]", key_label(key))
  end

  local w = #label * 8
  local x = sx * 0.5 - w * 0.5
  local y = 32

  local col_shadow = imgui.color_u32(0, 0, 0, 1.0)
  local col_text   = on
      and imgui.color_u32(0.3, 1.0, 0.4, 1.0)
       or imgui.color_u32(1.0, 0.4, 0.4, 1.0)

  imgui.draw_text(x + 1, y + 1, col_shadow, label)
  imgui.draw_text(x,     y,     col_text,   label)
end

-- Drop into the menu's General section via BehaviorToggle.DrawOptions().
function BehaviorToggle.DrawOptions()
  if not AegisSettings then return end
  if AegisSettings.AegisToggleKey == nil then
    AegisSettings.AegisToggleKey = 0
  end

  imgui.text(string.format("Toggle key: %s",
      key_label(AegisSettings.AegisToggleKey)))

  local btn_label = _bind_pending and "Press any key..." or "Bind Toggle Key"
  if imgui.button(btn_label .. "##aegis_toggle_bind") then
    _bind_pending = not _bind_pending
  end
  imgui.same_line(0, 8)
  if imgui.button("Clear##aegis_toggle_clr") then
    AegisSettings.AegisToggleKey = 0
    _bind_pending = false
  end

  if AegisSettings.AegisEnabled then
    imgui.text_colored(0.3, 1.0, 0.4, 1.0, "Rotation: ENABLED")
  else
    imgui.text_colored(1.0, 0.4, 0.4, 1.0, "Rotation: PAUSED")
  end
end

return BehaviorToggle
