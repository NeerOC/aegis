-- Aegis ErrorCache — reactive PQR-style cast-failure cache.

local M               = {}

local TTL_LOS         = 2.0
local TTL_BEHIND      = 2.0
local TTL_FRONT       = 1.0
local TTL_RANGE       = 1.0

local ATTR_WINDOW     = 0.30

M.los_blocked         = {}
M.behind_blocked      = {}
M.front_blocked       = {}
M.range_blocked       = {}

M._last_attempt_guid  = nil
M._last_attempt_at    = 0

local frame_installed = false

local function norm_guid(g)
  if type(g) ~= "string" or g == "" then return nil end
  g = g:lower()
  if g:sub(1, 2) == "0x" then g = g:sub(3) end
  return g
end

local function guid_of(target)
  if not target then return nil end
  if type(target) == "string" then return norm_guid(target) end
  if target.Guid and target.Guid ~= "" then return norm_guid(target.Guid) end
  return nil
end

local INSTALL_CODE = [[
if not _G.AegisErrQ then _G.AegisErrQ = {} end
if not _G.AegisErrFrame then
  local f = CreateFrame("Frame", "AegisErrFrame")
  f:RegisterEvent("UI_ERROR_MESSAGE")
  f:SetScript("OnEvent", function(_, _, _, msg)
    if not msg or msg == "" then return end
    _G.AegisErrQ[#_G.AegisErrQ + 1] = msg
  end)
  _G.AegisErrFrame = f
end
function _G.AegisErrDrain()
  local q = _G.AegisErrQ
  _G.AegisErrQ = {}
  if not q or #q == 0 then return "" end
  return table.concat(q, "\n")
end
]]

local function ensure_frame()
  if frame_installed then return true end
  if not (wow and wow.run_lua) then return false end
  local ok = pcall(wow.run_lua, INSTALL_CODE)
  if ok then frame_installed = true end
  return frame_installed
end

local function classify(msg)
  local m = msg:lower()
  if m:find("line of sight", 1, true) then return "los", TTL_LOS end
  if m:find("must be behind", 1, true) then return "behind", TTL_BEHIND end
  if m:find("must face", 1, true)
      or m:find("not in front", 1, true)
      or m:find("not facing", 1, true) then
    return "front", TTL_FRONT
  end
  if m:find("out of range", 1, true) then return "range", TTL_RANGE end
  return nil
end

local CACHE_TABLE = {
  los    = "los_blocked",
  behind = "behind_blocked",
  front  = "front_blocked",
  range  = "range_blocked",
}

local function attribute_guid(now)
  if M._last_attempt_guid and (now - M._last_attempt_at) <= ATTR_WINDOW then
    return M._last_attempt_guid
  end
  return nil
end

local function prune(now)
  for _, key in pairs(CACHE_TABLE) do
    local t = M[key]
    for g, exp in pairs(t) do
      if exp <= now then t[g] = nil end
    end
  end
end

--- Call once per aegis tick (drains the WoW-side queue).
function M:Tick()
  if not ensure_frame() then return end
  if not (wow and wow.eval_lua) then return end

  local ok, raw = pcall(wow.eval_lua, "AegisErrDrain()")
  if not ok or type(raw) ~= "string" or raw == "" then
    prune(os.clock())
    return
  end

  local now = os.clock()
  for msg in raw:gmatch("[^\n]+") do
    if msg ~= "" then
      local cat, ttl = classify(msg)
      if cat then
        local g = attribute_guid(now)
        if g then
          self[CACHE_TABLE[cat]][g] = now + ttl
        end
      end
    end
  end
  prune(now)
end

--- Mark a cast attempt so subsequent UI errors get attributed to its target.
function M:NotePending(target)
  local g = guid_of(target)
  if g then
    self._last_attempt_guid = g
    self._last_attempt_at   = os.clock()
  end
end

local function is_blocked(self, key, target)
  local g = guid_of(target); if not g then return false end
  local exp = self[key][g]
  if not exp then return false end
  if exp <= os.clock() then
    self[key][g] = nil
    return false
  end
  return true
end

function M:IsLOSBlocked(target) return is_blocked(self, "los_blocked", target) end

function M:IsBehindBlocked(target) return is_blocked(self, "behind_blocked", target) end

function M:IsFrontBlocked(target) return is_blocked(self, "front_blocked", target) end

function M:IsOutOfRangeBlocked(target) return is_blocked(self, "range_blocked", target) end

--- Manual seed (for tests / debugging).
function M:_seed(category, guid, ttl)
  local key = CACHE_TABLE[category]
  if key then self[key][norm_guid(guid)] = os.clock() + (ttl or 2.0) end
end

--- Diagnostics for the HUD / settings panel.
function M:Stats()
  local count = function(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
  end
  return {
    los       = count(self.los_blocked),
    behind    = count(self.behind_blocked),
    front     = count(self.front_blocked),
    range     = count(self.range_blocked),
    installed = frame_installed,
  }
end

return M
