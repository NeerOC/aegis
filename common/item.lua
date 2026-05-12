-- Minimal item wrapper for item-use rotations.

local _item_use_until = {}

local function scan_bag_items()
  if not game or not game.inventory then return {} end

  local ok, inv = pcall(game.inventory)
  if not ok or not inv or not inv.bags then return {} end

  local items = {}
  for _, bag in ipairs(inv.bags) do
    if bag and bag.items then
      local game_bag = bag.bag_index
      local c_bag = game_bag
      if game_bag == -1 then
        c_bag = 0
      elseif game_bag and game_bag >= 0 then
        c_bag = game_bag + 1
      end

      for slot = 1, (bag.num_slots or 0) do
        local info = bag.items[slot]
        local item_id = info and (info.id or info.entry_id or info.item_id)
        item_id = tonumber(item_id) or 0
        if item_id > 0 then
          items[#items + 1] = {
            id = item_id,
            bag = c_bag,
            slot = slot - 1,
            name = info.name or info.item_name or info.link_name or info.itemName or "",
          }
        end
      end
    end
  end

  return items
end

local function item_cooldown_ready(bag, slot)
  if not game or not game.bag_item_cooldown then return true end

  local ok, start, duration, enabled = pcall(game.bag_item_cooldown, bag, slot)
  if not ok or not start then return false end
  if enabled == false or enabled == 0 then return false end

  duration = tonumber(duration) or 0
  if duration <= 0 then return true end

  local now = game.game_time and (game.game_time() * 0.001) or os.clock()
  local elapsed = now - ((tonumber(start) or 0) * 0.001)
  return elapsed >= duration * 0.001
end

---@class ItemWrapper
---@field Id number
---@field EntryId number
---@field Name string
local ItemWrapper = {}
ItemWrapper.__index = ItemWrapper

function ItemWrapper:new(entry_id, name)
  return setmetatable({
    Id = tonumber(entry_id) or 0,
    EntryId = tonumber(entry_id) or 0,
    Name = name or "",
    _fail_until = 0,
    _use_until = 0,
  }, ItemWrapper)
end

function ItemWrapper:Exists()
  if self.Id == 0 or not game.find_item_by_entry then return false end
  local ok, ptr = pcall(game.find_item_by_entry, self.Id)
  return ok and ptr and ptr ~= 0 or false
end

function ItemWrapper:OnUseSpellId()
  if self.Id == 0 or not game.item_use_spell_by_entry then return 0 end
  local ok, spell_id = pcall(game.item_use_spell_by_entry, self.Id)
  return ok and (spell_id or 0) or 0
end

function ItemWrapper:IsUsable()
  return self:Exists() and self:OnUseSpellId() ~= 0
end

function ItemWrapper:CooldownRemains()
  local spell_id = self:OnUseSpellId()
  if spell_id == 0 or not game.spell_cooldown then return 0 end
  local ok, cd = pcall(game.spell_cooldown, spell_id)
  if not ok or not cd or not cd.on_cooldown then return 0 end
  return cd.remains or cd.duration or 0
end

function ItemWrapper:CooldownUp()
  return self:CooldownRemains() == 0
end

function ItemWrapper:IsReady()
  return self:IsUsable() and self:CooldownUp()
end

function ItemWrapper:Use()
  if not self:IsReady() then return false end
  local now = os.clock()
  if now < self._fail_until or now < self._use_until then return false end
  if not game.use_item_by_entry then return false end

  local ok, used = pcall(game.use_item_by_entry, self.Id)
  if ok and used then
    self._use_until = now + 0.2
    return true
  end
  self._fail_until = now + 1.0
  if Aegis and Aegis.Debug then
    Aegis.Debug.Log({ kind = "ITEM", item = self.Name, id = self.Id, result = "FAIL" })
  end
  return false
end

---@class Item
---@field Cache table<number, ItemWrapper>
---@field Wrapper ItemWrapper
---@field Data ItemData
Item = Item or {
  Cache = {},
  Wrapper = ItemWrapper,
}

---@class ItemData
---@field HastePotions number[]
---@field DestructionPotions number[]
---@field ManaPotions number[]
---@field ManaGems number[]
---@field FlameCaps number[]
---@field OffensiveTrinkets number[]
---@field DefensiveTrinkets number[]

Item.Data = Item.Data or {
  HastePotions = {
    22838,
  },

  DestructionPotions = {
    22839,
  },

  ManaPotions = {
    22832,
    31677,
    13444,
    18841,
    6149,
  },

  ManaGems = {
    22044,
    8008,
    8007,
    5513,
    5514,
  },

  FlameCaps = {
    22788,
  },

  OffensiveTrinkets = {
    21670,
    22954,
    23041,
    24128,
    28041,
    28121,
    28288,
    29383,
    29776,
    32654,
    32658,
    33831,
    35702,
    38287,

    23046,
    24126,
    29132,
    29179,
    29370,
    32483,
    33829,
    34429,
    38290,
  },

  DefensiveTrinkets = {
    27891,
    28528,
    29376,
    29387,
    30300,
    30629,
    32501,
    32534,
    33830,
    38289,
  },
}

function Item:ById(entry_id, name)
  local key = tonumber(entry_id) or 0
  if key == 0 then return ItemWrapper:new(0, "") end
  local cached = self.Cache[key]
  if not cached then
    cached = ItemWrapper:new(key, name)
    self.Cache[key] = cached
  end
  return cached
end

function Item:UseFirst(ids)
  ids = ids or {}

  for _, id in ipairs(ids) do
    local item = self:ById(id)
    if item and item.Use and item:Use() then
      return true
    end
  end

  if not game or not game.use_bag_item then return false end

  local wanted = {}
  for _, id in ipairs(ids) do wanted[id] = true end

  local now = os.clock()
  for _, item in ipairs(scan_bag_items()) do
    if wanted[item.id] and item.bag ~= nil and item.slot ~= nil then
      if now >= (_item_use_until[item.id] or 0) and item_cooldown_ready(item.bag, item.slot) then
        local ok, result = pcall(game.use_bag_item, item.bag, item.slot)
        if ok and result then
          _item_use_until[item.id] = now + 1.0
          return true
        end
      end
    end
  end

  return false
end

function Item:HasAny(ids)
  ids = ids or {}

  local wanted = {}
  for _, id in ipairs(ids) do wanted[id] = true end

  for _, item in ipairs(scan_bag_items()) do
    if wanted[item.id] then return true end
  end

  if game and game.find_item_by_entry then
    for _, id in ipairs(ids) do
      local ok, ptr = pcall(game.find_item_by_entry, id)
      if ok and ptr and ptr ~= 0 then return true end
    end
  end

  return false
end

function Item:HasReadyAny(ids)
  ids = ids or {}

  for _, id in ipairs(ids) do
    local item = self:ById(id)
    if item and item.IsReady and item:IsReady() then
      return true
    end
  end

  local wanted = {}
  for _, id in ipairs(ids) do wanted[id] = true end

  for _, item in ipairs(scan_bag_items()) do
    if wanted[item.id] and item.bag ~= nil and item.slot ~= nil and item_cooldown_ready(item.bag, item.slot) then
      return true
    end
  end

  return false
end

function Item.TryOffensiveTrinket()
  return Item and Item.UseFirst and Item:UseFirst(Item.Data.OffensiveTrinkets) or false
end

function Item.TryDefensiveTrinket()
  return Item and Item.UseFirst and Item:UseFirst(Item.Data.DefensiveTrinkets) or false
end

function Item.TryHastePotion()
  return Item and Item.UseFirst and Item:UseFirst(Item.Data.HastePotions) or false
end

function Item.TryDestructionPotion()
  return Item and Item.UseFirst and Item:UseFirst(Item.Data.DestructionPotions) or false
end

function Item.TryManaPotion()
  return Item and Item.UseFirst and Item:UseFirst(Item.Data.ManaPotions) or false
end

function Item.TryManaGem()
  return Item and Item.UseFirst and Item:UseFirst(Item.Data.ManaGems) or false
end

function Item.TryFlameCap()
  return Item and Item.UseFirst and Item:UseFirst(Item.Data.FlameCaps) or false
end

return Item
