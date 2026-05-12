-- Tick-scoped and persistent caches used by HeroLib-style helpers.

Aegis = Aegis or {}

---@class AegisCache
---@field Tick number Monotonic tick counter, bumped each Aegis tick.
---@field UnitInfo table<string, table> Per-GUID scratch cache.
---@field SpellInfo table Per-tick spell info cache.
---@field ItemInfo table Per-tick item info cache.
---@field Enemies table<string, table> Tick-scoped enemy buckets.
---@field TTD table Time-to-death tracker (Units, Scratch, HistoryTime, HistoryCount).
local Cache = Aegis.Cache or {}

Cache.Tick = Cache.Tick or 0
Cache.UnitInfo = Cache.UnitInfo or {}
Cache.SpellInfo = Cache.SpellInfo or {}
Cache.ItemInfo = Cache.ItemInfo or {}
Cache.Enemies = Cache.Enemies or {
  Ranged = {},
  Melee = {},
  Spell = {},
}

Cache.TTD = Cache.TTD or {
  Units = {},
  Scratch = {},
  HistoryTime = 10.4,
  HistoryCount = 100,
}

local function wipe(tbl)
  for k in pairs(tbl) do
    tbl[k] = nil
  end
end

function Cache:NextTick()
  self.Tick = (self.Tick or 0) + 1
  Aegis._last_tick = self.Tick
  wipe(self.Enemies.Ranged)
  wipe(self.Enemies.Melee)
  wipe(self.Enemies.Spell)
  wipe(self.SpellInfo)
  wipe(self.ItemInfo)

  for _, info in pairs(self.UnitInfo) do
    info.GCD = nil
    info.IsStunned = nil
    info.IsStunnable = nil
  end
end

function Cache:Reset()
  self.UnitInfo = {}
  self.SpellInfo = {}
  self.ItemInfo = {}
  self.Enemies = {
    Ranged = {},
    Melee = {},
    Spell = {},
  }
  self.TTD = {
    Units = {},
    Scratch = {},
    HistoryTime = 10.4,
    HistoryCount = 100,
  }
end

function Cache:Unit(guid)
  if not guid or guid == "" then return nil end
  local info = self.UnitInfo[guid]
  if not info then
    info = {}
    self.UnitInfo[guid] = info
  end
  return info
end

function Cache:CleanupUnitInfo(existing_guids)
  if not existing_guids then return end
  for guid in pairs(self.UnitInfo) do
    if not existing_guids[guid] then
      self.UnitInfo[guid] = nil
    end
  end
end

function Cache:RefreshTTD(units)
  local tracker = self.TTD
  local now = os.clock()
  local existing = tracker.Scratch
  wipe(existing)

  units = units or (Combat and Combat.Targets) or {}
  for i = 1, #units do
    local unit = units[i]
    local guid = unit and unit.Guid
    if guid and guid ~= "" and not existing[guid] then
      existing[guid] = true
      if unit.HealthPct and unit.HealthPct < 100 and unit.HealthPct > 0 then
        local record = tracker.Units[guid]
        if not record or unit.HealthPct > record.last_hp then
          record = { start = now, last_hp = unit.HealthPct, values = {} }
          tracker.Units[guid] = record
        end

        local values = record.values
        if #values == 0 or values[1][2] ~= unit.HealthPct then
          table.insert(values, 1, { now - record.start, unit.HealthPct })
          record.last_hp = unit.HealthPct
          local n = #values
          while n > tracker.HistoryCount or (n > 0 and (values[1][1] - values[n][1]) > tracker.HistoryTime) do
            values[n] = nil
            n = n - 1
          end
        end
      end
    end
  end

  for guid in pairs(tracker.Units) do
    if not existing[guid] then
      tracker.Units[guid] = nil
    end
  end
end

Aegis.Cache = Cache

return Cache
