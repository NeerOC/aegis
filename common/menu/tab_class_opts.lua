-- Class Opts tab — dynamic per-class/spec option menus (legacy contract).

local imgui = require("imgui")
local Theme = include and include("common/menu/theme.lua")
    or require("common.menu.theme")
local Widgets = include and include("common/menu/widgets.lua")
    or require("common.menu.widgets")

local C = Theme.C
local ClassOpts = {}

-- Tally widget kinds in an OptionMenu so we can derive its card height.
local function parts_for(opts)
  local parts = {}
  for _, w in ipairs(opts.Widgets or {}) do
    local t = w.type
    if t == "text" or t == "custom" then
      parts.text = (parts.text or 0) + 1
    elseif t == "checkbox" then
      parts.checkbox = (parts.checkbox or 0) + 1
    elseif t == "slider" then
      parts.slider = (parts.slider or 0) + 1
    elseif t == "combobox" then
      parts.button = (parts.button or 0) + 1
    end
  end
  return parts
end

function ClassOpts.Draw()
  if not Menu or not Menu.OptionMenus or #Menu.OptionMenus == 0 then
    local p_none  = { text = 1 }
    local total_h = Widgets.tab_height({ p_none })
    imgui.begin_child("aegis_class_opts", Theme.CONTENT_W, total_h, false, 24)
    Widgets.card("co_none", "CLASS OPTIONS", 0, Widgets.card_height(p_none), function()
      imgui.text_colored(C.text_secondary[1], C.text_secondary[2], C.text_secondary[3], 1.0,
        "No class options registered for the current spec.")
    end)
    imgui.end_child()
    return
  end

  -- Build parts per section first so we can size the outer wrapper exactly.
  local parts_list = {}
  for _, opts in ipairs(Menu.OptionMenus) do
    parts_list[#parts_list + 1] = parts_for(opts)
  end
  local total_h = Widgets.tab_height(parts_list)
  imgui.begin_child("aegis_class_opts", Theme.CONTENT_W, total_h, false, 24)

  for i, opts in ipairs(Menu.OptionMenus) do
    Widgets.card("co_" .. i, opts.Name or ("Section " .. i), 0,
      Widgets.card_height(parts_list[i]), function()
        for _, w in ipairs(opts.Widgets or {}) do
          Widgets.draw_legacy_widget(w)
        end
      end)
  end

  imgui.end_child()
end

return ClassOpts
