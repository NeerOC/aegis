---@meta

-- Central type declarations for the global Aegis namespace.
-- This file is only consumed by the Lua language server (see
-- .vscode/settings.json -> Lua.workspace.library); it is not loaded at runtime.

---@class Me : Player
---@field ClassName string Human-readable class name (e.g., "Warlock").
---@field Target Unit|nil Cached current target wrapper, refreshed each tick.
---@field Focus Unit|nil Cached focus-frame target, refreshed each tick.
---@field _class_key string Internal lowercase class key used for behavior file lookup.
---@field _class_name string Same as ClassName; kept for backwards compatibility.
---@field _spec_options string[] Valid specialization names for the player's class.

---@type Me?
Me = nil

---@class Aegis
---@field Debug AegisDebug
---@field Utils AegisUtils
---@field Errors table Error-cache module (LOS/facing pending state).
---@field include fun(rel_path: string): any Loads a Aegis module by relative path.
---@field _entity_cache table Last `game.objects` snapshot.
Aegis = Aegis or {}

---@class AegisSettings
---@field AegisEnabled boolean
---@field AegisAutoTarget boolean
---@field AegisAttackOOC boolean
---@field AegisAttackTarget boolean
---@field AegisSpecIdx number
---@field AegisSpecName string
---@field AegisSpecManualOverride boolean
---@field AegisInterruptMode number 0 = All, 1 = Whitelist, 2 = None.
---@field AegisInterruptTiming boolean
---@field AegisInterruptPercentage number
---@field AegisToggleKey number ImGui key code; 0 = unbound.
---@field AegisSpellQueueWindowMs number
---@field AegisSpellQueueSlackMs number
---@field AegisCastSuccessThrottleMs number
---@field AegisCoreDebug boolean
---@field AegisSpellDebug boolean
AegisSettings = AegisSettings or {}

---@type Combat
Combat = Combat or {}

---@type Heal
Heal = Heal or {}

---@type Tank
Tank = Tank or {}

---@type Behavior
Behavior = Behavior or {}

---@type Targeting
Targeting = Targeting or {}

---@type Pet
Pet = Pet or {}

---@type Item
Item = Item or {}

---@type Menu
Menu = Menu or {}

---@type Interrupts
Interrupts = Interrupts or {}

---@type Racials
Racials = Racials or {}

---@type TotemKeybind
TotemKeybind = TotemKeybind or {}

---@type BehaviorToggle
BehaviorToggle = BehaviorToggle or {}

---@type RangeTarget
RangeTarget = RangeTarget or {}

---@type Encounter
Encounter = Encounter or {}

---@type FriendlyDispels
FriendlyDispels = FriendlyDispels or {}

---@type OffensiveDispels
OffensiveDispels = OffensiveDispels or {}

---@type CrowdControl
CrowdControl = CrowdControl or {}

---@type AntiFear
AntiFear = AntiFear or {}

---@type Defensive
Defensive = Defensive or {}

-- BehaviorType enum is defined at runtime in system/behavior.lua. The
-- language server picks it up from there — duplicating the @enum here
-- would trip a "duplicate defined alias" warning.

-- ---------------------------------------------------------------------------
-- jmrTBC host API (console, imgui, cleu, wow, game, SCRIPTS_DIR, print) lives
-- in the shared `jmrtbc_api` library — see ../../jmrtbc_api/ and the
-- Lua.workspace.library entry in .vscode/settings.json.
-- ---------------------------------------------------------------------------

---@type fun(rel_path: string): any Aegis module loader; alias of Aegis.include.
include = include or function(_) end

---@type string Scripts root dir, set by jmrTBC's init.lua at boot.
SCRIPTS_DIR = SCRIPTS_DIR or ""
