--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Config.GameConfig)
local Upgrades = require(ReplicatedStorage.Config.Upgrades)
local Catalog = require(ReplicatedStorage.Utils.Catalog)

export type Data = {
	SchemaVersion: number,
	Cash: number,
	Level: number,
	Rebirths: number,
	BlocksBroken: number,
	BlocksThisRun: number,
	Clears: number,
	Rolls: number,
	Slots: number,
	Inventory: { [string]: number },
	Loadout: { string },
	Upgrades: { [string]: number },
	AutoRoll: boolean,
	AutoEquipBest: boolean,
	Idle: boolean,
	LastSeenAt: number,
	OfflineCash: number,
	Receipts: { string },
}

local PlayerData = {}
local upgradeLevels: { [string]: number } = {}
for _, upgrade in Upgrades.All do
	upgradeLevels[upgrade.Id] = 0
end

PlayerData.Template = {
	SchemaVersion = Config.SchemaVersion,
	Cash = 0,
	Level = 1,
	Rebirths = 0,
	BlocksBroken = 0,
	BlocksThisRun = 0,
	Clears = 0,
	Rolls = 0,
	Slots = 1,
	Inventory = { Wooden = 1 },
	Loadout = { "Wooden" },
	Upgrades = upgradeLevels,
	AutoRoll = false,
	AutoEquipBest = true,
	Idle = false,
	LastSeenAt = 0,
	OfflineCash = 0,
	Receipts = {},
} :: Data

local function isInteger(value: any, minimum: number, maximum: number): boolean
	return type(value) == "number"
		and value == value
		and value >= minimum
		and value <= maximum
		and value % 1 == 0
end

function PlayerData.Validate(data: any): boolean
	if type(data) ~= "table" or data.SchemaVersion ~= Config.SchemaVersion then
		return false
	end
	for _, key in { "Cash", "OfflineCash", "BlocksBroken", "BlocksThisRun", "Clears", "Rolls", "LastSeenAt" } do
		if not isInteger(data[key], 0, Config.MaxCash) then
			return false
		end
	end
	if
		not isInteger(data.Level, 1, Config.MaxMineLevel)
		or not isInteger(data.Rebirths, 0, 100000)
		or not isInteger(data.Slots, 1, Config.MaxSlots)
	then
		return false
	end
	if
		type(data.Inventory) ~= "table"
		or type(data.Loadout) ~= "table"
		or type(data.Upgrades) ~= "table"
		or type(data.Receipts) ~= "table"
	then
		return false
	end
	for id, copies in data.Inventory do
		if
			type(id) ~= "string"
			or Catalog.Get(id) == nil
			or not isInteger(copies, 1, Config.MaxInventoryCopies)
		then
			return false
		end
	end
	local used: { [string]: number } = {}
	local loadoutCount = 0
	for slot, id in data.Loadout do
		loadoutCount += 1
		if not isInteger(slot, 1, data.Slots) or type(id) ~= "string" then
			return false
		end
		used[id] = (used[id] or 0) + 1
		if used[id] > (data.Inventory[id] or 0) then
			return false
		end
	end
	if loadoutCount < 1 or loadoutCount ~= #data.Loadout then
		return false
	end
	for id, level in data.Upgrades do
		local upgrade = Upgrades.ById[id]
		if not upgrade or not isInteger(level, 0, upgrade.MaxLevel) then
			return false
		end
	end
	for _, upgrade in Upgrades.All do
		if data.Upgrades[upgrade.Id] == nil then
			return false
		end
	end
	return type(data.AutoRoll) == "boolean"
		and type(data.AutoEquipBest) == "boolean"
		and type(data.Idle) == "boolean"
end

function PlayerData.Clone(data: Data): Data
	local copy = table.clone(data)
	copy.Inventory = table.clone(data.Inventory)
	copy.Loadout = table.clone(data.Loadout)
	copy.Upgrades = table.clone(data.Upgrades)
	copy.Receipts = table.clone(data.Receipts)
	return copy
end

function PlayerData.Migrate(_data: Data) end

return PlayerData
