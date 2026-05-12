-- General utility helpers inspired by HeroLib.Utils.

Aegis = Aegis or {}

---@class AegisUtils
---@field Compare table<string, fun(a: any, b: any): boolean> Operator → comparator lookup.
local Utils = Aegis.Utils or {}

local COMPARE = {
  [">"] = function(a, b) return a > b end,
  ["<"] = function(a, b) return a < b end,
  [">="] = function(a, b) return a >= b end,
  ["<="] = function(a, b) return a <= b end,
  ["=="] = function(a, b) return a == b end,
  ["~="] = function(a, b) return a ~= b end,
  ["min"] = function(a, b) return a < b end,
  ["max"] = function(a, b) return a > b end,
}

function Utils.BoolToInt(value)
  return value and 1 or 0
end

function Utils.IntToBool(value)
  return value ~= 0
end

function Utils.ValueIsInArray(array, search)
  if not array then return false end
  for i = 1, #array do
    if array[i] == search then return true end
  end
  return false
end

function Utils.ValueIsInTable(tbl, search)
  if not tbl then return false end
  for _, value in pairs(tbl) do
    if value == search then return true end
  end
  return false
end

function Utils.FindValueIndexInArray(array, search)
  if not array then return nil end
  for i = 1, #array do
    if array[i] == search then return i end
  end
  return nil
end

function Utils.CompareThis(operator, a, b)
  local fn = COMPARE[operator]
  if not fn then return false end
  return fn(a, b)
end

function Utils.Clamp(value, min_value, max_value)
  if value < min_value then return min_value end
  if value > max_value then return max_value end
  return value
end

function Utils.SortASC(a, b)
  return a < b
end

function Utils.SortDESC(a, b)
  return a > b
end

function Utils.StringToNumberIfPossible(value)
  local n = tonumber(value)
  return n ~= nil and n or value
end

function Utils.StartsWith(value, prefix)
  return type(value) == "string" and value:sub(1, #prefix) == prefix
end

function Utils.EndsWith(value, suffix)
  return type(value) == "string" and (suffix == "" or value:sub(-#suffix) == suffix)
end

Aegis.Utils = Utils
Utils.Compare = COMPARE

return Utils
