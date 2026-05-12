-- ═══════════════════════════════════════════════════════════════════
-- Aegis shim — bridges jmrTBC's `wow.*` surface to the `game.*` surface
-- Aegis expects. Loaded by Aegis/plugin.lua onEnable, before any
-- common/* modules.
--
-- Strategy:
--   1. Reshape OM entries into Aegis's nested {..., unit = {...}} shape
--      and alias wrapper→obj_ptr, wrapper→cgunit.
--   2. Wrap cast/stop/info helpers to return Aegis's 2-value (code, desc).
--   3. Stub the features we haven't REd yet with sane defaults so the
--      framework runs without crashing (spell_cooldown, is_spell_in_range,
--      get_spell_info, group_members, etc.). Each stub is labelled with
--      a TODO so we know what to fill in.
-- ═══════════════════════════════════════════════════════════════════

-- ── LuaLS: declare every field this shim adds to the `game` class ──
-- The host stubs in jmrtbc_api/game.lua only declare the native
-- (game.traceline, game.los, …); without this block every `function
-- game.foo()` below trips "Fields cannot be injected" under strict mode.

---@class game
---@field objects               fun(): table[]
---@field local_player          fun(): table|nil
---@field target                fun(): table|nil
---@field focus                 fun(): table|nil
---@field unit_target           fun(obj_ptr: number): table|nil
---@field set_target            fun(target: number|string|table): boolean
---@field clear_target          fun()
---@field with_mouseover        fun(u: any, fn: fun(token: string): any): any
---@field cast_spell_at_unit    fun(id: number, obj_ptr: any, opts?: table): number, string
---@field cast_at_pos           fun(id: number, x: number, y: number, z: number): number, string
---@field stop_casting          fun()
---@field IsCurrentSpell        fun(id: number): boolean
---@field IsAutoRepeatSpell     fun(id: number): boolean
---@field is_spell_known        fun(id: number): boolean
---@field spell_cooldown        fun(id: number): { on_cooldown: boolean, enabled: boolean, start: number, duration: number }
---@field is_usable_spell       fun(id: number): boolean, boolean
---@field is_spell_in_range     fun(id: number, obj_ptr: number): number|nil
---@field get_spell_info        fun(id: number): { max_range: number, min_range: number, cast_time: number }
---@field get_spell_name        fun(id: number): string
---@field spell_dispel_type     fun(id: number): number
---@field spell_school_mask     fun(id: number): number
---@field spell_is_stealable    fun(id: number): boolean
---@field item_use_spell        fun(obj_ptr: number): number
---@field item_use_spell_by_entry fun(entry_id: number): number
---@field use_item              fun(obj_ptr: number): boolean
---@field find_item_by_entry    fun(entry_id: number): number
---@field use_item_by_entry     fun(entry_id: number): boolean
---@field find_spell_id         fun(name: string): number|nil
---@field known_spells          fun(want_names?: boolean): table
---@field pet_spells            fun(want_names?: boolean): table
---@field unit_casting_info     fun(tok: any): table|nil
---@field unit_channel_info     fun(tok: any): table|nil
---@field unit_dead_or_ghost    fun(obj_ptr: number): boolean
---@field unit_can_attack       fun(a: any, b?: any): boolean
---@field unit_is_attackable    fun(obj_ptr: any): boolean
---@field unit_is_enemy         fun(a: any, b?: any): boolean
---@field unit_is_friend        fun(a: any, b?: any): boolean
---@field unit_reaction         fun(a: number, b: number): number
---@field unit_role             fun(obj_ptr: number): string
---@field unit_is_tank          fun(obj_ptr: number): boolean
---@field unit_is_healer        fun(obj_ptr: number): boolean
---@field unit_is_dps           fun(obj_ptr: number): boolean
---@field unit_threat           fun(obj_ptr: number): boolean, number, number, number, number
---@field entity_position       fun(obj_ptr: number): { x: number, y: number, z: number }|nil
---@field entity_bounds         fun(obj_ptr: number): { width: number, height: number }|nil
---@field is_visible            fun(a: number, b: number, flags?: number): boolean
---@field has_aura              fun(obj_ptr: number, name_or_id: string|number): boolean
---@field aura_info             fun(obj_ptr: number, name_or_id: string|number): table|nil
---@field is_in_group           fun(): boolean
---@field is_in_raid            fun(): boolean
---@field group_members         fun(): table
---@field attack_speed          fun(obj_ptr: number): { mh: number, oh: number, ranged: number }|nil
---@field swing_info            fun(guid_hex: string, hand?: string): table|nil
---@field world_to_screen       fun(x: number, y: number, z: number): number|nil, number|nil
---@field set_facing            fun(a: number|table, b?: number, c?: number): boolean
---@field entity_facing         fun(wrapper: number): number|nil
---@field move_to               fun(x: number, y: number, z: number): boolean
---@field move_direction        fun(angle: number, distance: number): boolean
---@field is_moving             fun(): boolean
---@field stop_moving           fun(): boolean

-- Note: no load guard here. Aegis's dev loop relies on END-key reloads
-- re-running onEnable (and hence this shim) to pick up edits. All setup
-- below is idempotent (function re-definitions, table rebinds), so
-- re-executing on every reload is safe and intentional.
_G._aegis_shim_loaded = true

local wow = rawget(_G, "wow") or (require and require("wow"))
local game = _G.game or {}
_G.game = game
game.SCRIPTS_DIR = game.SCRIPTS_DIR or SCRIPTS_DIR or "."

-- Note: jmrTBC already ships a native `scripts/settings.lua` module
-- (same one jmrMoP uses). Don't override it here — an earlier sidecar
-- implementation called `os.execute('md ...')` to create a settings
-- dir, which spawned cmd.exe synchronously on every save (every ~5s
-- in aegis_core) and stalled the game thread long enough to freeze
-- the focused window.  The native module writes into each plugin's
-- own directory (which already exists) via plain io.open, no mkdir
-- required.

-- ── Entity shape conversion ────────────────────────────────────────

-- Maps TBC type_id / type_name to Aegis's "class" string. The C++ side
-- emits lowercase type names ("activeplayer", "player", "gameobject",
-- "item", "unit", "object" — see object_manager.cc), so match lowercase
-- here and return the Pascal-case shape downstream consumers expect.
local function aegis_class(e)
  local t = e.type or ""
  if t == "activeplayer" then return "ActivePlayer" end
  if t == "player" then return "Player" end
  if t == "gameobject" then return "GameObject" end
  if t == "item" then return "Item" end
  if t == "container" then return "Container" end
  return "Unit"
end

local CLASSIFICATION_NAMES = {
  [0] = "normal",
  [1] = "elite",
  [2] = "rare",
  [3] = "worldboss",
  [4] = "rareelite",
}

-- TBC spec names by (class_id, tab_idx) — mirrors classes.lua SPEC_MAP but
-- inlined here because the shim loads before aegis_core.
-- Class IDs: Warrior=1, Paladin=2, Hunter=3, Rogue=4, Priest=5, Shaman=7,
-- Mage=8, Warlock=9, Druid=11.
local TBC_SPEC_MAP = {
  [1]  = { [0] = "Arms", [1] = "Fury", [2] = "Protection" },                -- Warrior
  [2]  = { [0] = "Holy", [1] = "Protection", [2] = "Retribution" },         -- Paladin
  [3]  = { [0] = "Beast Mastery", [1] = "Marksmanship", [2] = "Survival" }, -- Hunter
  [4]  = { [0] = "Assassination", [1] = "Combat", [2] = "Subtlety" },       -- Rogue
  [5]  = { [0] = "Discipline", [1] = "Holy", [2] = "Shadow" },              -- Priest
  [7]  = { [0] = "Elemental", [1] = "Enhancement", [2] = "Restoration" },   -- Shaman
  [8]  = { [0] = "Arcane", [1] = "Fire", [2] = "Frost" },                   -- Mage
  [9]  = { [0] = "Affliction", [1] = "Demonology", [2] = "Destruction" },   -- Warlock
  [11] = { [0] = "Balance", [1] = "Feral Combat", [2] = "Restoration" },    -- Druid
}

-- Local-player-only spec derivation. We can only walk the talent list for
-- the ActivePlayer; every other entity gets a (0, "") stub.
local function local_spec_id(e)
  if e.type ~= "activeplayer" then return 0 end
  if not wow.dominant_spec then return 0 end
  local tab = wow.dominant_spec()
  if not tab or tab < 0 then return 0 end
  return tab + 1 -- 1-based to match Blizzard's GetActiveTalentGroup convention
end

local function local_spec_name(e)
  if e.type ~= "activeplayer" then return "" end
  if not wow.dominant_spec then return "" end
  local tab = wow.dominant_spec()
  if not tab or tab < 0 then return "" end
  local class_specs = TBC_SPEC_MAP[e.class or 0]
  if not class_specs then return "" end
  return class_specs[tab] or ""
end

-- GetUnitSpeed(unit) only takes a unit token, so route arbitrary OM
-- entities through the mouseover bridge: park the entity's GUID in the
-- "mouseover" slot, run the in-game Lua, then restore. ActivePlayer can
-- still use the cheaper "player" token directly. Computed lazily — the
-- mouseover swap + eval_lua round-trip is too expensive to pay for every
-- unit on every snapshot when most reads never touch .speed.
local function eval_unit_speed(e)
  if not wow.eval_lua then return 0 end
  if e.type == "activeplayer" then
    return tonumber(wow.eval_lua("GetUnitSpeed('player')")) or 0
  end
  if not wow.with_mouseover then return 0 end
  local guid = e.guid
  if not guid or guid == "" then return 0 end
  local v = wow.with_mouseover(guid, function(tok)
    return wow.eval_lua("GetUnitSpeed('" .. tok .. "')")
  end)
  return tonumber(v) or 0
end

-- Reshape a raw wow.om_entities() row into Aegis's expected shape.
-- Perf: the nested `unit` sub-table is the bulk of wrap_entity's cost
-- (~30 field assignments per entity). Only units/players/activeplayers
-- get the full unit table; items/containers/gameobjects/unknown get a
-- slim wrapper with `unit = nil`. Aegis's CollectTargets functions already
-- filter these out via `cls ~= "Unit"` checks, and existing sites that
-- read e.unit use `if not eu then goto skip` so nil is handled.
-- In Stormwind (~200 non-unit entities from vendor inventories + GOs)
-- this drops ~6000 wasted Lua table ops per tick.
local function wrap_entity(e)
  if not e then return nil end
  local is_unit_like =
      e.type == "unit" or
      e.type == "player" or
      e.type == "activeplayer"

  local has_pos = e.x ~= nil
  local position = has_pos and { x = e.x, y = e.y, z = e.z } or nil

  -- Items/containers/GOs: slim wrapper, no nested unit table.
  if not is_unit_like then
    return {
      obj_ptr          = e.wrapper,
      cgunit           = e.instance,
      guid             = e.guid or "",
      guid_lo          = e.guid_lo or 0,
      guid_hi          = e.guid_hi or 0,
      name             = e.name or "",
      position         = position,
      facing           = e.facing or 0,
      entry_id         = e.entry_id or 0,
      class            = aegis_class(e),
      dynamic_flags    = e.dynamic_flags or e.obj_dynamic_flags or 0,
      is_lootable      = ((e.obj_dynamic_flags or 0) % 2) == 1,
      wrapper          = e.wrapper,
      instance         = e.instance,
      real             = e.real,
      type             = e.type,
      type_id          = e.type_id,
      created_by_guid  = e.created_by_guid or "",
      summoned_by_guid = e.summoned_by_guid or "",
      unit             = nil,
    }
  end

  local cast_spell_id = e.cast_spell_id or 0
  local casting       = false
  local channeling    = false
  local cast_name     = ""
  if cast_spell_id > 0 then
    -- cast_state byte 1=casting, 2=channeling (verified from sub_2299CA0)
    if e.cast_state == 2 then channeling = true else casting = true end
    cast_name = wow.spell_name and wow.spell_name(cast_spell_id) or ""
  end

  local classification_id = e.classification or 0
  local classification_nm = CLASSIFICATION_NAMES[classification_id] or "normal"

  local unit_flags        = e.unit_flags or 0
  local in_combat         = (unit_flags % 0x100000) >= 0x80000 -- bit 0x80000
  local is_mounted        = (e.mount_display_id or 0) ~= 0
      and not ((e.client_state_flags or 0) >= 0x200000
        and ((e.client_state_flags or 0) % 0x400000) >= 0x200000)

  local is_player         = e.type == "player" or e.type == "activeplayer"

  return {
    -- Top-level fields Aegis reads
    obj_ptr          = e.wrapper,
    cgunit           = e.instance,
    guid             = e.guid or "",
    guid_lo          = e.guid_lo or 0,
    guid_hi          = e.guid_hi or 0,
    name             = e.name or "",
    position         = position,
    facing           = e.facing or 0,
    entry_id         = e.entry_id or 0,
    class            = aegis_class(e),
    dynamic_flags    = e.dynamic_flags or e.obj_dynamic_flags or 0,
    is_lootable      = ((e.obj_dynamic_flags or 0) % 2) == 1, -- bit 0 = lootable

    -- Raw TBC fields passed through for power users
    wrapper          = e.wrapper,
    instance         = e.instance,
    real             = e.real,
    type             = e.type,
    type_id          = e.type_id,
    created_by_guid  = e.created_by_guid or "",
    summoned_by_guid = e.summoned_by_guid or "",

    -- Nested unit table Aegis consumes. `speed` is omitted from the
    -- literal and resolved lazily by the metatable below — see
    -- eval_unit_speed for the mouseover-bridge plumbing.
    unit             = setmetatable({
      name                  = e.name or "",
      health                = e.health or 0,
      max_health            = e.max_health or 1,
      level                 = e.level or 0,
      unit_flags            = unit_flags,
      unit_flags2           = e.unit_flags2 or 0,
      unit_flags3           = 0, -- MoP-only, stub
      power                 = e.power or 0,
      max_power             = (e.max_power and e.max_power > 0) and e.max_power or 1,
      power_type            = e.power_type or 0,
      class_id              = e.class or 0, -- numeric class (warrior=1, paladin=2, ...)
      race                  = e.race or 0,
      is_dead               = e.is_dead or false,
      is_player             = is_player,
      in_combat             = in_combat,
      is_mounted            = is_mounted,
      mount_display_id      = e.mount_display_id or 0,
      classification        = classification_id,
      classification_name   = classification_nm,
      is_casting            = casting,
      is_channeling         = channeling,
      casting_spell_id      = casting and cast_spell_id or 0,
      casting_spell_name    = casting and cast_name or "",
      channeling_spell_id   = channeling and cast_spell_id or 0,
      channeling_spell_name = channeling and cast_name or "",
      cast_start_ms         = e.cast_start_ms or 0,
      cast_duration_ms      = e.cast_duration_ms or 0,
      cast_end_ms           = e.cast_end_ms or 0,
      auras                 = e.auras or {},
      bounding_radius       = e.bounding_radius or 0,
      combat_reach          = e.combat_reach or 0,
      attack_time_mh        = e.attack_time_mh or 0,
      attack_time_oh        = e.attack_time_oh or 0,
      attack_time_ranged    = e.attack_time_ranged or 0,
      powers                = e.powers or {},
      max_powers            = e.max_powers or {},
      spec_id               = local_spec_id(e),   -- 1-based tab index (talent-derived on local player, else 0)
      spec_name             = local_spec_name(e), -- talent-derived spec name ("Retribution", ...) or "" on other players
      dynamic_flags         = e.dynamic_flags or 0,
      is_lootable           = ((e.obj_dynamic_flags or 0) % 2) == 1,
    }, {
      __index = function(t, k)
        if k == "speed" then
          local v = eval_unit_speed(e)
          rawset(t, "speed", v) -- cache so subsequent reads in this tick are free
          return v
        end
        return nil
      end,
    }),
  }
end

-- ── game.objects / local_player / target ───────────────────────────
--
-- Perf: `wow.om_entities()` rebuilds the entire snapshot (400+ entities,
-- each with ~30 fields + nested aura arrays) on every call. The shim used
-- to call it 3-5 times per tick (game.objects + game.target +
-- game.unit_target + game.local_player) which multiplied that cost into
-- the dominant city-lag driver. Cache the raw snapshot for a short TTL
-- so multiple calls within the same tick share one build.
-- TTL = 30ms: shorter than Aegis's 50ms tick (so next tick always
-- refreshes), longer than the burst of lookups a single tick triggers.

local _raw_cache = nil
local _raw_cache_time = -1.0
local _RAW_CACHE_TTL = 0.030 -- seconds

local function raw_entities()
  local now = os.clock()
  if _raw_cache and (now - _raw_cache_time) < _RAW_CACHE_TTL then
    return _raw_cache
  end
  _raw_cache = wow.om_entities and wow.om_entities() or {}
  _raw_cache_time = now
  return _raw_cache
end

function game.objects()
  local raw = raw_entities()
  local out = {}
  for i = 1, #raw do
    local w = wrap_entity(raw[i])
    if w then out[#out + 1] = w end
  end
  return out
end

local function find_by_wrapper(wrapper)
  if not wrapper or wrapper == 0 then return nil end
  local raw = raw_entities()
  for i = 1, #raw do
    if raw[i].wrapper == wrapper then return wrap_entity(raw[i]) end
  end
  return nil
end

local function find_by_guid_hex(hex)
  if not hex or hex == "" then return nil end
  local raw = raw_entities()
  for i = 1, #raw do
    if raw[i].guid == hex then return wrap_entity(raw[i]) end
  end
  return nil
end

function game.local_player()
  local raw = raw_entities()
  for i = 1, #raw do
    if raw[i].type == "activeplayer" then return wrap_entity(raw[i]) end
  end
  return nil
end

function game.target()
  local hex = wow.target_guid and wow.target_guid()
  return find_by_guid_hex(hex)
end

function game.focus()
  local hex = wow.focus_guid and wow.focus_guid()
  return find_by_guid_hex(hex)
end

function game.unit_target(obj_ptr)
  if not obj_ptr or obj_ptr == 0 then return nil end
  local hex = wow.unit_target_guid and wow.unit_target_guid(obj_ptr)
  return find_by_guid_hex(hex)
end

-- om_entities only surfaces `guid` (32-char hex "%016llX%016llX"). Parse
-- the two halves back out so we can feed wow.set_target(lo, hi). NPC GUIDs
-- fit comfortably in a Lua double (lo is a 32-bit spawn id, hi is a small
-- type prefix) so tonumber(_, 16) preserves enough precision for the setter.
local function split_guid_hex(hex)
  if type(hex) ~= "string" or #hex ~= 32 then return 0, 0 end
  local hi = tonumber(hex:sub(1, 16), 16) or 0
  local lo = tonumber(hex:sub(17, 32), 16) or 0
  return lo, hi
end

-- Programmatic target selection. Accepts a Aegis entity table, a raw wrapper
-- pointer integer, or a GUID hex string. Resolves to a (guid_lo, guid_hi)
-- pair and calls wow.set_target which writes xmmword_452A7E8 and fires
-- UNIT_TARGET_CHANGED on the next main-thread tick.
function game.set_target(obj_ptr)
  if not obj_ptr or obj_ptr == 0 or not wow.set_target then return false end
  local lo, hi, hex = 0, 0, nil
  if type(obj_ptr) == "table" then
    lo = obj_ptr.guid_lo or (obj_ptr.unit and obj_ptr.unit.guid_lo) or 0
    hi = obj_ptr.guid_hi or (obj_ptr.unit and obj_ptr.unit.guid_hi) or 0
    hex = obj_ptr.guid or (obj_ptr.unit and obj_ptr.unit.guid)
  elseif type(obj_ptr) == "string" then
    hex = obj_ptr
    local raw = wow.om_entities and wow.om_entities() or {}
    for i = 1, #raw do
      if raw[i].guid == obj_ptr then
        lo = raw[i].guid_lo or 0
        hi = raw[i].guid_hi or 0
        break
      end
    end
  elseif type(obj_ptr) == "number" then
    local raw = wow.om_entities and wow.om_entities() or {}
    for i = 1, #raw do
      if raw[i].wrapper == obj_ptr then
        lo = raw[i].guid_lo or 0
        hi = raw[i].guid_hi or 0
        hex = raw[i].guid
        break
      end
    end
  end
  -- Prefer passing the hex string — NPC GUID `hi` exceeds 2^53 so the
  -- lo/hi pair silently loses precision through LuaJIT's double→int64.
  if hex and #hex == 32 then
    wow.set_target(hex)
    _G._aegis_pending_target = obj_ptr
    return true
  end
  if lo == 0 and hi == 0 then return false end
  wow.set_target(lo, hi)
  _G._aegis_pending_target = obj_ptr
  return true
end

function game.clear_target()
  _G._aegis_pending_target = nil
end

-- ── Mouseover bridge (cross-VM unit-token swap) ────────────────────
--
-- Pair the native wow.set_mouseover_guid with the "mouseover" unit token
-- so any OM unit / arbitrary GUID can be fed into a WoW Lua function that
-- takes a unit token (UnitName, UnitDebuff, UnitInParty, addon helpers,
-- ...). Save → swap → run → restore; pcall the inner call so the engine
-- slot is restored even on error and the original error is rethrown.
--
-- Accepts: Aegis Unit, OM entry, wrapper int, raw 32-char GUID hex.

local function resolve_mouseover_guid(u)
  if type(u) == "string" then
    if #u == 32 then return u end
    return nil
  end
  if type(u) == "number" then
    if u == 0 then return nil end
    if wow.entity_guid then
      local g = wow.entity_guid(u)
      if g and g ~= "" then return g end
    end
    return nil
  end
  if type(u) == "table" then
    return u.Guid
        or u.guid
        or (u.unit and u.unit.guid)
        or nil
  end
  return nil
end

if wow and wow.set_mouseover_guid and not wow.with_mouseover then
  function wow.with_mouseover(u, fn)
    if type(fn) ~= "function" then
      error("wow.with_mouseover: fn must be a function", 2)
    end
    local guid = resolve_mouseover_guid(u)
    -- No resolvable GUID: still run fn so caller can detect via the
    -- "mouseover" token returning empty (UnitName("mouseover") == "").
    if not guid then return fn("mouseover") end
    local prev = wow.set_mouseover_guid(guid)
    local ok, result = pcall(fn, "mouseover")
    wow.set_mouseover_guid(prev)
    if not ok then error(result, 2) end
    return result
  end
end

-- game.* mirror so aegis_core plugins talking through the game.* surface
-- don't need to reach into wow.* directly.
function game.with_mouseover(u, fn)
  if wow and wow.with_mouseover then
    return wow.with_mouseover(u, fn)
  end
  return fn("mouseover") -- fallback: no DLL bridge available
end

-- ── Casting (adapts bool → {code, desc} shape) ─────────────────────

-- Aegis codes (from common/spell.lua comments): 0=ok, 9=throttled,
-- 10=not ready, 11=on cd, 12=queued. We return 0 "ok" on success.
local CAST_OK            = { 0, "ok" }
local CAST_FAIL          = { 1, "failed" }

-- Async-queue spam guard: wow.cast_spell{_at_target} always returns true
-- because the bridge just enqueues a request — the actual game-side result
-- is never surfaced back to Lua. So Aegis sees "success" and retries every
-- CAST_THROTTLE (0.2s), spamming cooldown-locked spells like Elemental
-- Mastery. This map records the last queue time per spell_id; within
-- POST_QUEUE_GUARD_S we return NOT_READY (10) instead of queuing again,
-- tick-throttling Aegis without triggering FAIL_BACKOFF. The main cast
-- pre-check (game.spell_cooldown) catches legitimate CDs before this kicks
-- in; the guard only limits damage when the cooldown leaf mis-reports.
local _last_queue_at     = {}
local POST_QUEUE_GUARD_S = 1.5

-- Resolve obj_ptr into (guid_hex, guid_lo, guid_hi, is_self). obj_ptr is
-- usually the wrapper number (Me.obj_ptr / target.obj_ptr) but we accept
-- a Unit table defensively.
local function resolve_obj_guid(obj_ptr)
  local me_wrap = (wow.active_player and wow.active_player()) or 0
  if type(obj_ptr) == "table" then
    local inner = obj_ptr.obj_ptr or obj_ptr
    if inner == me_wrap then return nil, 0, 0, true end
    local g  = obj_ptr.guid or (obj_ptr.unit and obj_ptr.unit.guid) or ""
    local lo = obj_ptr.guid_lo or (obj_ptr.unit and obj_ptr.unit.guid_lo) or 0
    local hi = obj_ptr.guid_hi or (obj_ptr.unit and obj_ptr.unit.guid_hi) or 0
    if lo == 0 and hi == 0 then lo, hi = split_guid_hex(g) end
    return g, lo, hi, false
  end
  if type(obj_ptr) ~= "number" then return nil, 0, 0, false end
  if obj_ptr == me_wrap then return nil, 0, 0, true end
  local raw = wow.om_entities and wow.om_entities() or {}
  for i = 1, #raw do
    if raw[i].wrapper == obj_ptr then
      local g = raw[i].guid or ""
      local lo = raw[i].guid_lo or 0
      local hi = raw[i].guid_hi or 0
      if lo == 0 and hi == 0 then lo, hi = split_guid_hex(g) end
      return g, lo, hi, false
    end
  end
  return nil, 0, 0, false
end

function game.cast_spell_at_unit(id, obj_ptr, opts)
  -- opts.ground is unused — ground-targeted casts go through CastAtPos.
  if not id or id == 0 then return CAST_FAIL[1], CAST_FAIL[2] end

  local now = os.clock()
  local tgt_guid, tgt_lo, tgt_hi, is_self = resolve_obj_guid(obj_ptr)

  -- Self-cast: call cast_spell (no target lookup inside the bridge).
  if is_self then
    if wow.cast_spell then
      local ok = wow.cast_spell(id)
      if ok then _last_queue_at[id] = now end
      return ok and CAST_OK[1] or CAST_FAIL[1], ok and CAST_OK[2] or CAST_FAIL[2]
    end
    return CAST_FAIL[1], CAST_FAIL[2]
  end

  -- Unresolvable target → fail loud so the rotation skips this spell.
  if not tgt_guid or tgt_guid == "" or (tgt_lo == 0 and tgt_hi == 0) then
    return CAST_FAIL[1], "no target guid"
  end

  -- Preferred path: cast directly at the GUID, no current-target
  -- round-trip. Bypasses set_target entirely so heals on party
  -- members don't drop the player's enemy target, and doesn't burn
  -- a tick on the queued target switch.
  if wow.cast_spell_at_guid then
    local ok = wow.cast_spell_at_guid(id, tgt_guid)
    if ok then _last_queue_at[id] = now end
    return ok and CAST_OK[1] or CAST_FAIL[1], ok and CAST_OK[2] or CAST_FAIL[2]
  end

  -- Legacy fallback (older DLL versions before cast_spell_at_guid):
  -- queue a set_target if the current target doesn't match, then cast
  -- on the next tick once target_guid() catches up. Pass the full hex
  -- GUID — NPC GUIDs have `kind << 58` in hi, putting them past 2^53,
  -- so LuaJIT's double->int64 round-trip would corrupt the value.
  local cur = (wow.target_guid and wow.target_guid()) or ""
  if cur ~= tgt_guid then
    if wow.set_target then wow.set_target(tgt_guid) end
    return 10, "target switching"
  end

  if wow.cast_spell_at_target then
    local ok = wow.cast_spell_at_target(id)
    if ok then _last_queue_at[id] = now end
    return ok and CAST_OK[1] or CAST_FAIL[1], ok and CAST_OK[2] or CAST_FAIL[2]
  end
  if wow.cast_spell then
    local ok = wow.cast_spell(id)
    if ok then _last_queue_at[id] = now end
    return ok and CAST_OK[1] or CAST_FAIL[1], ok and CAST_OK[2] or CAST_FAIL[2]
  end
  return CAST_FAIL[1], CAST_FAIL[2]
end

function game.cast_at_pos(id, x, y, z)
  if not id or id == 0 then return CAST_FAIL[1], CAST_FAIL[2] end
  local now = os.clock()
  local last = _last_queue_at[id]
  if last and (now - last) < POST_QUEUE_GUARD_S then
    return 10, "queued, awaiting game resolve"
  end
  if wow.cast_spell_at_position then
    local ok = wow.cast_spell_at_position(id, x, y, z)
    if ok then _last_queue_at[id] = now end
    return ok and CAST_OK[1] or CAST_FAIL[1], ok and CAST_OK[2] or CAST_FAIL[2]
  end
  return CAST_FAIL[1], CAST_FAIL[2]
end

function game.stop_casting()
  if wow.stop_casting then wow.stop_casting() end
end

-- ── Spell metadata / state (stubs until RE'd) ──────────────────────

---@param id number
---@return boolean
function game.IsCurrentSpell(id)
  return wow.eval_lua("C_Spell.IsCurrentSpell(" .. id .. ")") == true
end

---@param id number
---@return boolean
function game.IsAutoRepeatSpell(id)
  return wow.eval_lua("C_Spell.IsAutoRepeatSpell(" .. id .. ")") == true
end

function game.is_spell_known(id)
  if wow.is_spell_known then return wow.is_spell_known(id) end
  return true
end

-- Wired via DB2 clean leaf sub_2AD0030. Engine returns start_sec (engine
-- time base) and duration_sec; we flag on_cooldown when duration > 0 since
-- the engine zeroes duration at expiry.
function game.spell_cooldown(id)
  if wow.spell_cooldown then
    local cd = wow.spell_cooldown(id)
    if cd then
      local dur = cd.duration_sec or 0
      return {
        on_cooldown = dur > 0,
        enabled = cd.enabled ~= false,
        start = cd.start_sec or 0,
        duration = dur,
      }
    end
  end
  return { on_cooldown = false, enabled = true, start = 0, duration = 0 }
end

-- IsUsableSpell → wow.spell_is_usable (sub_22594B0 + sub_225A600 composed).
-- Lua contract: returns (usable, notEnoughMana). Aegis checks usable first;
-- if false but notEnoughMana==true, rotations may downgrade to mana-free
-- filler instead of blocking entirely.
function game.is_usable_spell(id)
  if not id or not wow or not wow.spell_is_usable then return true, false end
  local ok, u, p = pcall(wow.spell_is_usable, id)
  if not ok then return true, false end
  return u, p
end

-- Distance vs. spell max_range from the DB2 leaf. Returns 1/0 on a definitive
-- check, nil when either endpoint is missing (Aegis treats nil as "skip").
function game.is_spell_in_range(id, obj_ptr)
  if not id or not obj_ptr or obj_ptr == 0 then return nil end
  if not wow.spell_info or not wow.entity_position then return 1 end
  local info = wow.spell_info(id, 70)
  local max_r = info and info.max_range or 0
  if max_r <= 0 then return 1 end -- no declared range → self/melee/buff: let Aegis try
  local player = wow.active_player and wow.active_player() or 0
  if player == 0 then return nil end
  local px, py, pz = wow.entity_position(player)
  local tx, ty, tz = wow.entity_position(obj_ptr)
  if not px or not tx then return nil end
  local dx, dy, dz = tx - px, ty - py, tz - pz
  local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
  return dist <= max_r and 1 or 0
end

-- Wired via DB2 leaves sub_22524F0 (cast_time) + sub_2252B40 (max_range).
-- Level 70 default matches TBC cap; Aegis doesn't pass level through here.
function game.get_spell_info(id)
  if wow.spell_info then
    local info = wow.spell_info(id, 70)
    if info then
      return {
        max_range = info.max_range or 0,
        min_range = info.min_range or 0,
        cast_time = info.cast_time_ms or 0,
      }
    end
  end
  return { max_range = 0, min_range = 0, cast_time = 0 }
end

function game.get_spell_name(id)
  return (wow.spell_name and wow.spell_name(id)) or ""
end

-- wow.spell_dispel_type → raw DB2 dispel type (0=None,1=Magic,2=Curse,3=Disease,4=Poison,9=Enrage).
function game.spell_dispel_type(id)
  if not id or not wow.spell_dispel_type then return 0 end
  local ok, v = pcall(wow.spell_dispel_type, id)
  return ok and v or 0
end

-- wow.spell_school_mask → bitmask (1=Physical,2=Holy,4=Fire,8=Nature,16=Frost,32=Shadow,64=Arcane).
function game.spell_school_mask(id)
  if not id or not wow.spell_school_mask then return 0 end
  local ok, v = pcall(wow.spell_school_mask, id)
  return ok and v or 0
end

-- wow.spell_is_stealable → boolean (Magic + not passive).
function game.spell_is_stealable(id)
  if not id or not wow.spell_is_stealable then return false end
  local ok, v = pcall(wow.spell_is_stealable, id)
  return ok and v or false
end

-- wow.item_use_spell → spell_id for an item's on-use effect, or 0.
-- Uses wrapper → entry_id → ItemEffect DB2 lookup internally.
function game.item_use_spell(obj_ptr)
  if not obj_ptr or not wow.item_use_spell then return 0 end
  local ok, v = pcall(wow.item_use_spell, obj_ptr)
  return ok and v or 0
end

-- Look up use-effect spell directly by entry_id (no wrapper needed).
function game.item_use_spell_by_entry(entry_id)
  if not entry_id or not wow.item_use_spell_by_entry then return 0 end
  local ok, v = pcall(wow.item_use_spell_by_entry, entry_id)
  return ok and v or 0
end

-- Use an item by obj_ptr — reads its use-effect spell and sends USE_ITEM.
function game.use_item(obj_ptr)
  if not obj_ptr then return false end
  local entry_id = 0
  local ents = wow.om_entities and wow.om_entities() or {}
  for _, e in ipairs(ents) do
    if e.wrapper == obj_ptr and e.entry_id and e.entry_id ~= 0 then
      entry_id = e.entry_id
      break
    end
  end
  if entry_id == 0 then return false end
  return game.use_item_by_entry(entry_id)
end

-- Find item wrapper by entry_id (searches the current OM snapshot).
function game.find_item_by_entry(entry_id)
  if not entry_id or not wow.find_item_by_entry then return 0 end
  local ok, v = pcall(wow.find_item_by_entry, entry_id)
  return ok and v or 0
end

-- Use an item by entry_id — DB2 lookup for spell, then USE_ITEM cast.
function game.use_item_by_entry(entry_id)
  if not entry_id then return false end
  local spell_id = game.item_use_spell_by_entry(entry_id)
  if not spell_id or spell_id == 0 then return false end
  if wow.use_item then
    local ok, r = pcall(wow.use_item, spell_id, entry_id)
    return ok and r
  end
  return false
end

-- TODO: RE name → id lookup. Slow fallback: linear scan known_spells.
function game.find_spell_id(name)
  if not wow.known_spells then return nil end
  local ids = wow.known_spells()
  for i = 1, #ids do
    if (wow.spell_name and wow.spell_name(ids[i])) == name then
      return ids[i]
    end
  end
  return nil
end

function game.known_spells(want_names)
  if not wow.known_spells then return {} end
  local ids = wow.known_spells()
  if not want_names then return ids end
  local out = {}
  for i = 1, #ids do
    out[i] = { id = ids[i], name = wow.spell_name and wow.spell_name(ids[i]) or "" }
  end
  return out
end

function game.pet_spells(want_names)
  -- TODO: RE pet spellbook if/when needed.
  return {}
end

-- ── Casting info (accepts "player"/"target" token or obj_ptr) ──────

local function resolve_unit_token(tok)
  if type(tok) == "number" then return tok end
  if tok == "player" then return wow.active_player and wow.active_player() or 0 end
  if tok == "target" then
    local hex = wow.target_guid and wow.target_guid()
    if not hex or hex == "" then return 0 end
    return wow.get_object_by_guid and wow.get_object_by_guid(hex) or 0
  end
  return 0
end

-- Per-entity cast timings are already plumbed through wow.om_entities()
-- (cast_start_ms / cast_duration_ms / cast_end_ms at rec+0x5CC/+0x5D0). We
-- scan the OM once here — wow.casting_info(wrapper) doesn't expose timing.
local function raw_entity_by_wrapper(wrapper)
  if not wrapper or wrapper == 0 then return nil end
  local raw = wow.om_entities and wow.om_entities() or {}
  for i = 1, #raw do
    if raw[i].wrapper == wrapper then return raw[i] end
  end
  return nil
end

function game.unit_casting_info(tok)
  local wrapper = resolve_unit_token(tok)
  if wrapper == 0 then return nil end
  local e = raw_entity_by_wrapper(wrapper)
  if not e or (e.cast_spell_id or 0) == 0 then return nil end
  -- cast_state: 1=casting, 2=channeling (from sub_2299CA0).
  if e.cast_state == 2 then return nil end
  local name = wow.spell_name and wow.spell_name(e.cast_spell_id) or ""
  return {
    spell_id          = e.cast_spell_id,
    spell_name        = name,
    cast_start        = e.cast_start_ms or 0,
    cast_end          = e.cast_end_ms or 0,
    not_interruptible = false,
  }
end

function game.unit_channel_info(tok)
  local wrapper = resolve_unit_token(tok)
  if wrapper == 0 then return nil end
  local e = raw_entity_by_wrapper(wrapper)
  if not e or (e.cast_spell_id or 0) == 0 or e.cast_state ~= 2 then return nil end
  local name = wow.spell_name and wow.spell_name(e.cast_spell_id) or ""
  return {
    spell_id          = e.cast_spell_id,
    spell_name        = name,
    channel_start     = e.cast_start_ms or 0,
    channel_end       = e.cast_end_ms or 0,
    not_interruptible = false,
  }
end

-- ── Unit predicates ────────────────────────────────────────────────

function game.unit_dead_or_ghost(obj_ptr)
  if wow.unit_is_dead_or_ghost then return wow.unit_is_dead_or_ghost(obj_ptr) end
  return false
end

-- Aegis's one-arg form means "can the local player X this unit?" — the
-- jmrTBC C bindings always require an (attacker, target) pair, so fill in
-- the local player when the caller omits it. Bail if we can't resolve the
-- local player (e.g. pre-login) rather than raising on the C side.
local function local_player_ptr()
  return (wow.active_player and wow.active_player()) or 0
end

function game.unit_can_attack(a, b)
  if not wow.unit_can_attack then return false end
  if not b then
    b = a; a = local_player_ptr()
  end
  if not a or a == 0 or not b or b == 0 then return false end
  return wow.unit_can_attack(a, b)
end

function game.unit_is_attackable(obj_ptr)
  return game.unit_can_attack(obj_ptr)
end

function game.unit_is_enemy(a, b)
  if not wow.unit_is_enemy then return false end
  if not b then
    b = a; a = local_player_ptr()
  end
  if not a or a == 0 or not b or b == 0 then return false end
  return wow.unit_is_enemy(a, b)
end

function game.unit_is_friend(a, b)
  if not wow.unit_is_friend then return false end
  if not b then
    b = a; a = local_player_ptr()
  end
  if not a or a == 0 or not b or b == 0 then return false end
  return wow.unit_is_friend(a, b)
end

function game.unit_reaction(a, b)
  if wow.unit_reaction then return wow.unit_reaction(a, b) or 0 end
  return 0
end

-- TBC 2.5.5 has THREE sources of role information for other players,
-- in priority order:
--
--   1. UnitGroupRolesAssigned(unit) — the LFG / "/role" assignment.
--      Instant, no packet needed. Returns "TANK"/"HEALER"/"DAMAGER"/
--      "NONE". ElvUI's role icons primarily key off this. Most players
--      in dungeons set this via the Group frame at queue time.
--
--   2. NotifyInspect → INSPECT_TALENT_READY → GetTalentTabInfo(...,
--      true). Talent-derived role from the dominant tree. Slower
--      (one round-trip per inspect, ~5s throttle), but works even
--      when the player didn't set a role. ElvUI falls back to this
--      for "tagged but un-assigned" players.
--
--   3. Aura hints (Defensive Stance, Bear Form, Righteous Fury,
--      Shadowform, Tree of Life, Cat/Moonkin Form). Zero latency,
--      reflects the player's CURRENT activity, used as both an
--      override ("they're tanking right now regardless of build")
--      and a fallback while inspect packets round-trip.
--
-- All three are wired through the Lua bridge — UnitGroupRolesAssigned
-- and NotifyInspect both live in the in-game JmrTBCInspectFrame snippet.
--
-- Class IDs: Warrior=1, Paladin=2, Hunter=3, Rogue=4, Priest=5, Shaman=7,
-- Mage=8, Warlock=9, Druid=11.
local TBC_TANK_SPECS = {
  [1]  = { [2] = true }, -- Warrior / Protection
  [2]  = { [1] = true }, -- Paladin / Protection
  [11] = { [1] = true }, -- Druid   / Feral (bear)
}
local TBC_HEALER_SPECS = {
  [2]  = { [0] = true },             -- Paladin / Holy
  [5]  = { [0] = true, [1] = true }, -- Priest  / Discipline, Holy
  [7]  = { [2] = true },             -- Shaman  / Restoration
  [11] = { [2] = true },             -- Druid   / Restoration
}

local TBC_PURE_DPS = { [3] = true, [4] = true, [8] = true, [9] = true }

-- Aura hints — "you are tanking RIGHT NOW" signals that override or
-- prefigure the inspect-derived role. The OM aura snapshot sees these
-- on visible party members.
local TBC_TANK_AURAS = {
  ["Defensive Stance"] = true,
  ["Bear Form"]        = true,
  ["Dire Bear Form"]   = true,
  ["Righteous Fury"]   = true,
}
local TBC_DPS_AURAS = {
  ["Cat Form"]     = true,
  ["Moonkin Form"] = true,
  ["Shadowform"]   = true,
}
local TBC_HEALER_AURAS = {
  ["Tree of Life"] = true,
}

---@return string|nil
local function aura_role_hint(e)
  local au = e and e.unit and e.unit.auras
  if not au then return nil end
  for i = 1, #au do
    local name = au[i] and au[i].name
    if name then
      if TBC_TANK_AURAS[name] then return "TANK" end
      if TBC_HEALER_AURAS[name] then return "HEALER" end
      if TBC_DPS_AURAS[name] then return "DAMAGER" end
    end
  end
  return nil
end

-- ── Inspect-frame bootstrap ───────────────────────────────────────
-- Runs once per session. Creates a hidden frame in the game's Lua VM
-- that handles INSPECT_TALENT_READY events and stashes role results
-- in a global table the shim reads back via wow.read_lua_path.

local _inspect_bootstrapped = false
local _last_inspect_at      = {}  -- player_name → os.clock when NotifyInspect was last fired
local INSPECT_COOLDOWN_S    = 6.0 -- TBC server-side throttle is ~5s; pad a bit

local function bootstrap_inspect_listener()
  if _inspect_bootstrapped or not wow or not wow.run_lua then return end
  -- Snippet runs inside the WoW Lua VM. Defensive: only create the frame
  -- once even across plugin reloads (which re-exec this shim).
  pcall(wow.run_lua, [[
    if not _G._jmrtbc_inspect_frame then
      _G._jmrtbc_party_roles = _G._jmrtbc_party_roles or {}
      local f = CreateFrame("Frame", "JmrTBCInspectFrame")
      f:RegisterEvent("INSPECT_TALENT_READY")
      -- Map (class_token, dominant_tab_1based) → role.
      local TANK = {
        WARRIOR  = { [3] = true },                    -- Protection
        PALADIN  = { [2] = true },                    -- Protection
        DRUID    = { [2] = true },                    -- Feral (bear)
      }
      local HEALER = {
        PALADIN  = { [1] = true },                    -- Holy
        PRIEST   = { [1] = true, [2] = true },        -- Disc, Holy
        SHAMAN   = { [3] = true },                    -- Restoration
        DRUID    = { [3] = true },                    -- Restoration
      }
      local function classify(class_token, best_tab)
        if TANK[class_token]   and TANK[class_token][best_tab]   then return "TANK" end
        if HEALER[class_token] and HEALER[class_token][best_tab] then return "HEALER" end
        return "DAMAGER"
      end
      local function unit_for_guid(guid)
        if not guid or guid == "" then return nil end
        if UnitGUID("target") == guid then return "target" end
        for i = 1, 4 do
          local u = "party" .. i
          if UnitGUID(u) == guid then return u end
        end
        for i = 1, 40 do
          local u = "raid" .. i
          if UnitGUID(u) == guid then return u end
        end
        return nil
      end
      f:SetScript("OnEvent", function(self, event, guid)
        local unit = unit_for_guid(guid) or "target"
        if not UnitExists(unit) then return end
        local _, class_token = UnitClass(unit)
        if not class_token then return end
        local name = UnitName(unit)
        if not name or name == "" then return end
        local best_tab, best_pts = 0, -1
        for tab = 1, 3 do
          local _, _, pts = GetTalentTabInfo(tab, true)
          pts = pts or 0
          if pts > best_pts then best_pts = pts; best_tab = tab end
        end
        if best_pts < 0 then return end
        _G._jmrtbc_party_roles[name] = classify(class_token, best_tab)
      end)
      _G._jmrtbc_inspect_frame = f

      _G._jmrtbc_inspect_last = _G._jmrtbc_inspect_last or {}

      -- Find a party/raid/target unit token by player name.
      local function find_unit(name)
        if not name or name == "" then return nil end
        if UnitExists("target") and UnitName("target") == name then return "target" end
        for i = 1, 4 do
          local u = "party" .. i
          if UnitExists(u) and UnitName(u) == name then return u end
        end
        for i = 1, 40 do
          local u = "raid" .. i
          if UnitExists(u) and UnitName(u) == name then return u end
        end
        return nil
      end

      -- Composite role lookup: prefer UnitGroupRolesAssigned (LFG /role
      -- assignment) → then inspect cache. Returns "" when neither has
      -- data so the shim knows to fire an inspect packet.
      function _G.JmrTBC_GetRole(name)
        if not name or name == "" then return "" end
        local unit = find_unit(name)
        if unit and UnitGroupRolesAssigned then
          local r = UnitGroupRolesAssigned(unit)
          if r and r ~= "" and r ~= "NONE" then return r end
        end
        local cached = _G._jmrtbc_party_roles[name]
        if cached and cached ~= "" then return cached end
        return ""
      end

      -- Fire an inspect packet (rate-limited). Caller should already
      -- have checked GetRole returned "". Engine-side cap at 5s in case
      -- the shim cooldown gets reset by reload.
      function _G.JmrTBC_RequestInspect(name)
        if not name or name == "" then return end
        local now = GetTime and GetTime() or 0
        local last = _G._jmrtbc_inspect_last[name] or 0
        if (now - last) < 5.0 then return end
        local unit = find_unit(name)
        if not unit then return end
        -- NotifyInspect silently fails out of range (~28y in TBC); we
        -- still set the cooldown so we don't hammer it every tick.
        NotifyInspect(unit)
        _G._jmrtbc_inspect_last[name] = now
      end
    end
  ]])
  _inspect_bootstrapped = true
end

-- Read the composite role string for a player by name. The in-game
-- helper JmrTBC_GetRole(name) checks UnitGroupRolesAssigned first, then
-- the inspect cache. Lua-side TTL keeps a tick that asks 5 members
-- to one round-trip per name per half-second.
local _role_lookup_cache = {} -- name → {role, at}
local ROLE_LOOKUP_TTL = 0.5

---@param name string
---@return string|nil
local function inspect_role_for(name)
  if not name or name == "" then return nil end
  local now = os.clock()
  local cached = _role_lookup_cache[name]
  if cached and (now - cached.at) < ROLE_LOOKUP_TTL then return cached.role end
  if not wow or not wow.read_lua_path then return nil end
  local stash = "__jmrtbc_role_lookup_" .. name:gsub("[^%w]", "_")
  pcall(wow.run_lua,
    string.format("_G[%q] = (JmrTBC_GetRole and JmrTBC_GetRole(%q)) or \"\"",
      stash, name))
  local v = wow.read_lua_path(stash)
  local role = (type(v) == "string" and v ~= "" and v ~= "NONE") and v or nil
  _role_lookup_cache[name] = { role = role, at = now }
  return role
end

local function request_inspect(name)
  if not name or name == "" then return end
  local now = os.clock()
  if (now - (_last_inspect_at[name] or 0)) < INSPECT_COOLDOWN_S then return end
  _last_inspect_at[name] = now
  pcall(wow.run_lua, string.format("if JmrTBC_RequestInspect then JmrTBC_RequestInspect(%q) end", name))
end

local function role_for(obj_ptr)
  local e = find_by_wrapper(obj_ptr)
  if not e or not e.unit or not e.unit.is_player then return "DAMAGER" end
  local class_id = e.unit.class_id or 0

  -- Local player: talent tab is authoritative (no inspect packet needed).
  if e.type == "activeplayer" and wow.dominant_spec then
    local tab = wow.dominant_spec()
    if tab and tab >= 0 then
      if TBC_TANK_SPECS[class_id] and TBC_TANK_SPECS[class_id][tab] then return "TANK" end
      if TBC_HEALER_SPECS[class_id] and TBC_HEALER_SPECS[class_id][tab] then return "HEALER" end
    end
    return "DAMAGER"
  end

  -- Pure DPS classes — no need to inspect.
  if TBC_PURE_DPS[class_id] then return "DAMAGER" end

  bootstrap_inspect_listener()

  -- Aura hint: takes priority for tank-stance signals because it's "now"
  -- (a fury warrior in Defensive Stance is tanking THIS pull regardless
  -- of their talent build).
  local hint = aura_role_hint(e)
  if hint == "TANK" or hint == "HEALER" then return hint end

  -- Inspect-cached role.
  local insp = inspect_role_for(e.name or "")
  if insp then return insp end

  -- No cached talent data yet — fire the inspect packet (rate-limited)
  -- so the next tick has data, and use the aura hint or DAMAGER for now.
  request_inspect(e.name or "")
  if hint then return hint end
  return "DAMAGER"
end

function game.unit_role(obj_ptr) return role_for(obj_ptr) end

function game.unit_is_tank(obj_ptr) return role_for(obj_ptr) == "TANK" end

function game.unit_is_healer(obj_ptr) return role_for(obj_ptr) == "HEALER" end

function game.unit_is_dps(obj_ptr) return role_for(obj_ptr) == "DAMAGER" end

function game.unit_threat(obj_ptr)
  -- Aegis wants 5 returns. Adapter: (is_tanking, status, scaled, raw, value).
  if wow.unit_threat_situation then
    local status, is_attacked, pct, raw = wow.unit_threat_situation(obj_ptr)
    local is_tanking = (status or 0) >= 2
    return is_tanking, status or 0, pct or 0, raw or 0, 0
  end
  return false, 0, 0, 0, 0
end

-- ── Geometry ───────────────────────────────────────────────────────

function game.entity_position(obj_ptr)
  if not wow.entity_position then return nil end
  local x, y, z = wow.entity_position(obj_ptr)
  if x then
    return { x = x, y = y, z = z }
  end
  return nil
end

-- TODO: return bounding_radius from cached entity fields. Stub.
function game.entity_bounds(obj_ptr)
  local e = find_by_wrapper(obj_ptr)
  if not e then return nil end
  return { width = e.unit.bounding_radius or 0, height = 0 }
end

-- game.is_facing_coords is registered in C alongside game.is_facing — both
-- point to the same l_is_facing(src_facing, src_x, src_y, tgt_x, tgt_y
-- [, threshold]) function.  The _coords alias survives the override below
-- so Traceline Explorer and other coord-based callers keep working.

function game.is_facing(a, b, threshold)
  local pa = game.entity_position(a)
  local pb = game.entity_position(b)
  if not pa or not pb then return false end
  local facing = wow.entity_facing(a)
  if not facing then return false end
  return game.is_facing_coords(facing, pa.x, pa.y, pb.x, pb.y, threshold)
end

-- game.distance — C binding already registered. Keep as-is (coord form).

function game.is_visible(a, b, flags)
  -- TBC's game.los takes coords. Convert wrapper pairs to coords.
  local pa = game.entity_position(a)
  local pb = game.entity_position(b)
  if not pa or not pb then return true end -- optimistic: assume visible
  if _G.game.los then
    return _G.game.los(pa.x, pa.y, pa.z + 1.5, pb.x, pb.y, pb.z + 1.5, flags or 0x03)
  end
  return true
end

-- ── Auras ──────────────────────────────────────────────────────────

function game.has_aura(obj_ptr, name_or_id)
  local e = find_by_wrapper(obj_ptr)
  if not e or not e.unit.auras then return false end
  local is_id = type(name_or_id) == "number"
  for _, a in ipairs(e.unit.auras) do
    if (is_id and a.spell_id == name_or_id) or (not is_id and a.name == name_or_id) then
      return true
    end
  end
  return false
end

function game.aura_info(obj_ptr, name_or_id)
  local e = find_by_wrapper(obj_ptr)
  if not e or not e.unit.auras then return nil end
  local is_id = type(name_or_id) == "number"
  local me_guid = wow.active_player_guid and wow.active_player_guid() or ""
  for _, a in ipairs(e.unit.auras) do
    if (is_id and a.spell_id == name_or_id) or (not is_id and a.name == name_or_id) then
      return {
        spell_id       = a.spell_id,
        name           = a.name,
        stacks         = a.stacks,
        duration_ms    = a.duration_ms,
        expire_ms      = a.expire_ms,
        caster_guid    = a.caster_guid,
        is_from_player = (a.caster_guid == me_guid),
      }
    end
  end
  return nil
end

-- ── Group (wired via xmmword_40BDFA8 direct read) ─────────────────

function game.is_in_group()
  if wow.is_in_group then return wow.is_in_group() end
  return false
end

function game.is_in_raid()
  if wow.is_in_raid then return wow.is_in_raid() end
  return false
end

function game.group_members()
  if wow.group_members then return wow.group_members() end
  return {}
end

-- ── Swing Timer ──────────────────────────────────────────────────

-- Returns { mh = secs, oh = secs, ranged = secs } from the OM descriptor
-- attack time fields. All values are haste-adjusted.
function game.attack_speed(obj_ptr)
  local e = find_by_wrapper(obj_ptr)
  if not e then return nil end
  local u = e.unit
  if not u then return nil end
  return {
    mh     = u.attack_time_mh or 0,
    oh     = u.attack_time_oh or 0,
    ranged = u.attack_time_ranged or 0,
  }
end

-- Returns swing timer state from the CLEU-driven tracker (if loaded).
-- hand = "main" | "off" | "ranged". Returns { remaining_ms, speed_ms,
-- last_ms, next_ms, confidence } or nil.
function game.swing_info(guid_hex, hand)
  local ok, st = pcall(require, "combat.swing_tracker")
  if not ok or not st then return nil end
  return st.get(guid_hex, hand or "main")
end

-- ── Projection (pass-through) ─────────────────────────────────────

if not game.world_to_screen then
  game.world_to_screen = wow.world_to_screen
end

-- ── Facing / Movement ─────────────────────────────────────────────

-- game.set_facing(desired_yaw)
-- game.set_facing(target_wrapper)
-- game.set_facing(x, y, z)
--
-- Overloaded: pass a single number for absolute yaw, a wrapper for
-- face-toward-entity, or (x,y,z) coords for face-toward-point.
function game.set_facing(a, b, c)
  if not wow.set_facing then return false end
  local player = wow.active_player and wow.active_player() or nil
  if not player or player == 0 then return false end

  local desired
  if type(a) == "number" and b == nil then
    desired = a
  else
    local px, py
    local pp = game.entity_position(player)
    if not pp then return false end
    px, py = pp.x, pp.y

    local tx, ty
    if type(a) == "number" and type(b) == "number" then
      tx, ty = a, b
    else
      local tp = game.entity_position(a)
      if not tp then return false end
      tx, ty = tp.x, tp.y
    end
    desired = math.atan2(ty - py, tx - px)
  end

  return wow.set_facing(desired)
end

-- game.entity_facing(wrapper) → radians or nil
function game.entity_facing(wrapper)
  if wow.entity_facing then return wow.entity_facing(wrapper) end
  return nil
end

-- game.move_to(x, y, z) → bool
-- Face toward (x,y,z) then walk forward until the planar distance is
-- covered. Caller must drive wow.tick_movement() each frame for the
-- auto-stop to fire (already done by most plugins via onTick).
function game.move_to(x, y, z)
  if not wow.set_facing or not wow.walk_forward_distance then
    return false
  end
  local player = wow.active_player and wow.active_player() or nil
  if not player or player == 0 then return false end
  local pp = game.entity_position(player)
  if not pp then return false end

  local dx = x - pp.x
  local dy = y - pp.y
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist < 0.5 then return true end

  local angle = math.atan2(dy, dx)
  wow.set_facing(angle)
  return wow.walk_forward_distance(dist)
end

-- game.move_direction(angle_rad, distance_yards) → bool
-- Face the given direction and walk forward the specified distance.
function game.move_direction(angle, distance)
  if not wow.set_facing or not wow.walk_forward_distance then
    return false
  end
  wow.set_facing(angle)
  return wow.walk_forward_distance(distance)
end

-- game.is_moving() → bool
function game.is_moving()
  if wow.is_moving_forward then return wow.is_moving_forward() end
  return false
end

-- game.stop_moving() → bool
function game.stop_moving()
  if wow.cancel_walk then wow.cancel_walk() end
  if wow.move_forward_stop then return wow.move_forward_stop() end
  return false
end

print("[aegis_shim] game.* surface installed")
