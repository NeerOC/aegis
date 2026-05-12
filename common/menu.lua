-- Aegis menu — modern dark UI with sidebar nav, persistent top strip,
-- and tab dispatch into common/menu/tab_*.lua.

local imgui = require("imgui")

---@class Menu
---@field OptionMenus table[] Registered class/spec option panels (legacy contract).
---@field Open boolean Whether the main Aegis window is visible.
Menu = Menu or {}
Menu.OptionMenus = {}
Menu.Open = true
Menu._tab = Menu._tab or 1

-- Sub-modules loaded once at initialize time.
local Theme, Widgets, TopBar, Sidebar
local Tabs = {}

local function load_submodules()
  local function inc(rel)
    if include then return include(rel) end
    local ok, mod = pcall(require, rel:gsub("/", "."):gsub("%.lua$", ""))
    return ok and mod or nil
  end
  Theme   = inc("common/menu/theme.lua")
  Widgets = inc("common/menu/widgets.lua")
  TopBar  = inc("common/menu/topbar.lua")
  Sidebar = inc("common/menu/sidebar.lua")
  Tabs[1] = inc("common/menu/tab_dashboard.lua")
  Tabs[2] = inc("common/menu/tab_rotation.lua")
  Tabs[3] = inc("common/menu/tab_interrupts.lua")
  Tabs[4] = inc("common/menu/tab_spec.lua")
  Tabs[5] = inc("common/menu/tab_class_opts.lua")
  Tabs[6] = inc("common/menu/tab_advanced.lua")
end

function Menu:Initialize()
  self.OptionMenus = {}
  self.Open = true
  if not Theme then load_submodules() end
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

function Menu:Draw()
  if not self.Open then return end
  if not Theme then load_submodules() end
  if not Theme then return end

  Theme.Push()

  local visible, open = imgui.begin_window("Aegis", Theme.WindowFlags)
  if not visible then
    imgui.end_window()
    Theme.Pop()
    return
  end
  if open == false then self.Open = false end

  -- Top status strip (handles its own X-close request).
  local close_ref = { value = false }
  TopBar.Draw(close_ref)
  if close_ref.value then self.Open = false end

  -- Sidebar + tab content. Each tab owns its own begin_child wrapper sized
  -- explicitly from the parts manifest (Widgets.tab_height) so the window's
  -- AlwaysAutoResize flag can pack the window exactly to that height per tab.
  self._tab = Sidebar.Draw(self._tab or 1)

  local tab = Tabs[self._tab]
  if tab and tab.Draw then
    pcall(tab.Draw)
  else
    imgui.text("(tab not loaded)")
  end

  imgui.end_window()
  Theme.Pop()
end

return Menu
