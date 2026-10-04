--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Config.GameConfig)
local Constants = require(ReplicatedStorage.Config.Constants)
local Ores = require(ReplicatedStorage.Config.Ores)
local Types = require(script.Parent.Types)

local Builder = {}

function Builder.Key(column: number, row: number): number
	return (column - 1) * Config.MineRows + row
end

function Builder.CellPosition(centre: Vector3, column: number, row: number): Vector3
	return centre
		+ Vector3.new(
			(column - (Config.MineColumns + 1) / 2) * Config.CellSize,
			Config.BlockSize / 2,
			(row - (Config.MineRows + 1) / 2) * Config.CellSize
		)
end

function Builder.Create(parent: Folder, player: Player, slot: number): Types.Zone
	local centre = Vector3.new((slot - 1) * Constants.ZONE_SPACING, Config.FloorTop, 0)
	local folder = Instance.new("Folder")
	folder.Name = `MineZone_{player.UserId}`
	folder:SetAttribute(Constants.ZONE_OWNER_ATTRIBUTE, player.UserId)
	folder:SetAttribute(Constants.ZONE_CENTRE_ATTRIBUTE, centre)
	folder:SetAttribute(Constants.ZONE_FLOOR_TOP_ATTRIBUTE, centre.Y)
	folder:SetAttribute(Constants.FIELD_HALF_SPAN_X_ATTRIBUTE, Config.FloorSize / 2)
	folder:SetAttribute(Constants.FIELD_HALF_SPAN_Z_ATTRIBUTE, Config.FloorSize / 2)
	folder.Parent = parent
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Vector3.new(Config.FloorSize, 4, Config.FloorSize)
	floor.CFrame = CFrame.new(centre - Vector3.new(0, 2, 0))
	floor.Color = Color3.fromRGB(65, 67, 78)
	floor.Material = Enum.Material.Slate
	floor.Parent = folder
	local rocks = Instance.new("Folder")
	rocks.Name = Constants.ZONE_ROCKS_FOLDER
	rocks.Parent = folder
	return {
		Folder = folder,
		Centre = centre,
		Slot = slot,
		Rocks = {},
		Remaining = 0,
		Value = 0,
		Elapsed = 0,
		LastHits = {},
		MoveElapsed = 0,
	}
end

function Builder.Fill(zone: Types.Zone, level: number, random: Random)
	local folder = zone.Folder:FindFirstChild(Constants.ZONE_ROCKS_FOLDER) :: Folder
	folder:ClearAllChildren()
	table.clear(zone.Rocks)
	table.clear(zone.LastHits)
	zone.Remaining = 0
	zone.Value = 0
	local assets = ReplicatedStorage:FindFirstChild("RecoveryAssets")
	local oreAssets = if assets then assets:FindFirstChild("OreExport") else nil
	local available = math.min(#Ores, 3 + math.floor(level / 2))
	for column = 1, Config.MineColumns do
		for row = 1, Config.MineRows do
			if
				math.abs(column - (Config.MineColumns + 1) / 2) <= 1
				and math.abs(row - (Config.MineRows + 1) / 2) <= 1
			then
				continue
			end
			local ore = Ores[random:NextInteger(1, available)]
			local template = if oreAssets then oreAssets:FindFirstChild(ore.Id) else nil
			local part = if template and template:IsA("BasePart")
				then template:Clone()
				else Instance.new("Part")
			part.Name = ore.Id
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.Transparency = 0
			part.Size = Vector3.new(Config.BlockSize, Config.BlockSize, Config.BlockSize)
			part.CFrame = CFrame.new(Builder.CellPosition(zone.Centre, column, row))
			local hp = math.ceil(4 + level ^ 1.35)
			local key = Builder.Key(column, row)
			part:SetAttribute(Constants.ROCK_ID_ATTRIBUTE, key)
			part:SetAttribute(Constants.ROCK_ORE_ATTRIBUTE, ore.Id)
			part:SetAttribute(Constants.ROCK_HP_ATTRIBUTE, hp)
			part:SetAttribute(Constants.ROCK_MAX_HP_ATTRIBUTE, hp)
			part.Parent = folder
			zone.Rocks[key] =
				{ Part = part, Hp = hp, MaxHp = hp, Value = ore.Value, Column = column, Row = row }
			zone.Remaining += 1
			zone.Value += ore.Value
		end
	end
end

return Builder
