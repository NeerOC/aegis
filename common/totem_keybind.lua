-- Totem manual-drop keybind helper for shaman behaviors.

local imgui = require("imgui")

---@class TotemKeybind
local TotemKeybind = {}

local _bind_pending = {}
local _drops_enabled = {}
local _warning = {}

local DEFAULT_DROPS_ENABLED = true

local SKIP_KEYS = {
  [0]   = true,
  [526] = true,
  [527] = true,
  [528] = true,
  [529] = true,
  [530] = true,
  [531] = true,
  [532] = true,
  [533] = true,
  [534] = true,
}

local KEY_NAMES = {
  [512] = "Tab",
  [513] = "LeftArrow",
  [514] = "RightArrow",
  [515] = "UpArrow",
  [516] = "DownArrow",
  [517] = "PageUp",
  [518] = "PageDown",
  [519] = "Home",
  [520] = "End",
  [521] = "Insert",
  [522] = "Delete",
  [523] = "Backspace",
  [524] = "Space",
  [525] = "Enter",
  [526] = "Escape",
  [535] = "Apostrophe",
  [536] = "Comma",
  [537] = "Minus",
  [538] = "Period",
  [539] = "Slash",
  [540] = "Semicolon",
  [541] = "Equal",
  [542] = "LeftBracket",
  [543] = "Backslash",
  [544] = "RightBracket",
  [545] = "GraveAccent",
}
for i = 0, 25 do KEY_NAMES[546 + i] = string.char(0x41 + i) end
for i = 0, 9 do KEY_NAMES[572 + i] = tostring(i) end
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

-- Settings presence check — manual mode on?
function TotemKeybind.IsManual(prefix)
  return AegisSettings[prefix .. "ManualTotems"] == true
end

-- Returns the current toggle state for a spec.
function TotemKeybind.AreDropsEnabled(prefix)
  local v = _drops_enabled[prefix]
  if v == nil then return DEFAULT_DROPS_ENABLED end
  return v
end

-- Allow specs to sync the toggle state with their own timed-window logic.
function TotemKeybind.SetDropsEnabled(prefix, enabled)
  _drops_enabled[prefix] = (enabled == true) or false
end

-- Call every frame from plugin.lua onTick.
function TotemKeybind.Tick(prefix)
  if _bind_pending[prefix] then
    local code = detect_any_press()
    if code then
      AegisSettings[prefix .. "TotemKey"] = code
      _bind_pending[prefix] = nil
      print(string.format("[Aegis] %s totem key bound: %s",
        prefix, key_label(code)))
    end
    return
  end

  if not TotemKeybind.IsManual(prefix) then return end
  local key = AegisSettings[prefix .. "TotemKey"] or 0
  if key == 0 then return end

  if imgui.is_key_pressed(key) then
    local new_state = not TotemKeybind.AreDropsEnabled(prefix)
    _drops_enabled[prefix] = new_state
    print(string.format("[Aegis] %s totem drops %s",
      prefix, new_state and "ENABLED" or "DISABLED"))
  end
end

-- Set warning text each tick; empty/nil clears the warning.
function TotemKeybind.SetWarning(prefix, text)
  _warning[prefix] = text or ""
end

-- Renders any active warning at screen center.
function TotemKeybind.DrawWarning()
  local msg = nil
  for _, w in pairs(_warning) do
    if w and w ~= "" then
      msg = w; break
    end
  end
  if not msg then return end
  if not imgui.get_display_size or not imgui.draw_text then return end

  local sx, sy = imgui.get_display_size()
  if not sx or sx == 0 then return end

  local lines = {}
  for line in (msg .. "\n"):gmatch("(.-)\n") do
    if line ~= "" then lines[#lines + 1] = line end
  end
  if #lines == 0 then return end

  local col_shadow = imgui.color_u32 and imgui.color_u32(0, 0, 0, 1.0) or 0xFF000000
  local col_red    = imgui.color_u32 and imgui.color_u32(1.0, 0.3, 0.3, 1.0) or 0xFF4D4DFF

  local line_h     = 18
  local total_h    = #lines * line_h
  local start_y    = sy * 0.5 - total_h * 0.5 - 15

  for i, line in ipairs(lines) do
    local w = #line * 8
    local x = sx * 0.5 - w * 0.5
    local y = start_y + (i - 1) * line_h
    imgui.draw_text(x + 1, y + 1, col_shadow, line)
    imgui.draw_text(x, y, col_red, line)
  end
end

-- Renders the keybind widgets inside a spec's options header.
function TotemKeybind.DrawOptions(prefix)
  local enable_key = prefix .. "ManualTotems"
  local key_setting = prefix .. "TotemKey"

  if AegisSettings[enable_key] == nil then AegisSettings[enable_key] = false end

  local ch, v = imgui.checkbox("Manual totem drop (keybind)##" .. prefix .. "_mt",
    AegisSettings[enable_key])
  if ch then AegisSettings[enable_key] = v end

  if not AegisSettings[enable_key] then return end

  imgui.text(string.format("  Bound key: %s",
    key_label(AegisSettings[key_setting] or 0)))

  local capturing = _bind_pending[prefix] == true
  local btn_label = capturing and "Press any key..." or "Bind Totem Drop Key"
  if imgui.button(btn_label .. "##" .. prefix .. "_bind") then
    _bind_pending[prefix] = not capturing
  end
  imgui.same_line(0, 8)
  if imgui.button("Clear##" .. prefix .. "_bindclr") then
    AegisSettings[key_setting] = 0
    _bind_pending[prefix] = nil
  end

  local on = TotemKeybind.AreDropsEnabled(prefix)
  if on then
    imgui.text_colored(0.3, 1.0, 0.4, 1.0, "  Totem drops: ENABLED")
  else
    imgui.text_colored(1.0, 0.5, 0.3, 1.0, "  Totem drops: DISABLED")
  end
end

return TotemKeybind
