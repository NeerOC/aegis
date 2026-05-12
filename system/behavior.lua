-- Behavior manager (mirrors Aegis system/behavior.lua).

---@enum BehaviorType
BehaviorType = {
  Heal   = 1,
  Tank   = 2,
  Combat = 3,
  Rest   = 4,
  Extra  = 5,
}

---@class Behavior
---@field LoadedClass string Class key of the currently loaded behavior file.
---@field LoadedSpec string Specialization name of the currently loaded behavior file.
Behavior = Behavior or {}
Behavior.LoadedClass = ""
Behavior.LoadedSpec  = ""

function Behavior:Initialize()
  if not Me then return end

  local class_key = Me._class_key or ""

  local spec_name
  if AegisSettings.AegisSpecManualOverride then
    spec_name = AegisSettings.AegisSpecName or ""
  else
    spec_name = Me.SpecName
    if not spec_name or spec_name == "" then
      spec_name = AegisSettings.AegisSpecName or ""
    end
  end
  if spec_name == "" then
    print("[Aegis] No specialization detected — open the Aegis menu to select one")
    return
  end

  if self.LoadedClass == class_key and self.LoadedSpec == spec_name then
    return
  end

  print("[Aegis] Initialize Behaviors")

  for _, v in pairs(BehaviorType) do
    self[v] = {}
  end

  local spec_file = spec_name:gsub("%s+", ""):lower()
  local rel_path  = "behaviors/" .. class_key .. "/" .. spec_file .. ".lua"
  local behavior  = Aegis.include(rel_path)

  if not behavior then
    print(string.format("[Aegis] No behavior file found: %s", rel_path))
    self.LoadedClass = ""
    self.LoadedSpec  = ""
    return
  end

  if behavior.Options then
    Menu:AddOptionMenu(behavior.Options)
  end

  self:AddBehaviorFunction(behavior.Behaviors, BehaviorType.Heal)
  self:AddBehaviorFunction(behavior.Behaviors, BehaviorType.Combat)
  self:AddBehaviorFunction(behavior.Behaviors, BehaviorType.Tank)
  self:AddBehaviorFunction(behavior.Behaviors, BehaviorType.Rest)
  self:AddBehaviorFunction(behavior.Behaviors, BehaviorType.Extra)

  local loaded = 0
  for _, v in pairs(BehaviorType) do
    if self[v] and #self[v] > 0 then
      loaded = loaded + #self[v]
    end
  end

  self.LoadedClass = class_key
  self.LoadedSpec  = spec_name
  print(string.format("[Aegis] Loaded %d behaviors for %s %s",
    loaded, Me._class_name or "?", spec_name))
end

function Behavior:Update()
  for _, k in pairs(BehaviorType) do
    if not self[k] then goto continue end
    for _, fn in ipairs(self[k]) do
      local ok, err = pcall(fn)
      if not ok then
        print("[Aegis] Behavior error: " .. tostring(err))
      end
    end
    ::continue::
  end
end

function Behavior:HasBehavior(btype)
  if not self[btype] then return false end
  return #self[btype] > 0
end

function Behavior:AddBehaviorFunction(tbl, btype)
  if not tbl or not tbl[btype] then return end
  if not self[btype] then self[btype] = {} end
  table.insert(self[btype], tbl[btype])
end

return Behavior
