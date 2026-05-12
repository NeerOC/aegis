-- Shared Aegis debug helpers.

Aegis = Aegis or {}

---@class AegisDebug
---@field MaxEntries number Ring-buffer size for Debug.Log entries.
local Debug = Aegis.Debug or {}
Debug._warned = Debug._warned or {}
Debug._log = Debug._log or {}
Debug._log_idx = Debug._log_idx or 0
Debug.MaxEntries = Debug.MaxEntries or 120

local function enabled()
  return AegisSettings and AegisSettings.AegisCoreDebug
end

function Debug.Enabled()
  return enabled() and true or false
end

function Debug.WarnOnce(key, message)
  if not enabled() then return end
  if not key or Debug._warned[key] then return end
  Debug._warned[key] = true
  local text = "[Aegis][CoreDebug] " .. tostring(message or key)
  if console and console.warn then
    console.warn(text)
  else
    print(text)
  end
end

function Debug.Log(entry)
  if not enabled() then return end
  if type(entry) ~= "table" then
    entry = { message = tostring(entry) }
  end
  entry.time = entry.time or os.clock()
  entry.tick = Aegis._last_tick or Aegis._spell_debug_tick or 0

  Debug._log_idx = Debug._log_idx + 1
  local idx = ((Debug._log_idx - 1) % Debug.MaxEntries) + 1
  Debug._log[idx] = entry
end

function Debug.Entries()
  return Debug._log, Debug._log_idx
end

Aegis.Debug = Debug

return Debug
