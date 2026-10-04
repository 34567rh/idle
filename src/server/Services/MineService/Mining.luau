--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Config.GameConfig)
local Constants = require(ReplicatedStorage.Config.Constants)
local Catalog = require(ReplicatedStorage.Utils.Catalog)
local PlayerData = require(script.Parent.Parent.Parent.Data.PlayerData)
local Progression = require(script.Parent.Parent.Parent.Data.Progression)
local Builder = require(script.Parent.Builder)
local Types = require(script.Parent.Types)

local Mining = {}

function Mining.GetPickPosition(
	root: Vector3,
	elapsed: number,
	speed: number,
	index: number,
	count: number
): Vector3
	local angle = elapsed * speed * math.pi * 2 + (index - 1) * math.pi * 2 / count
	return root
		+ Vector3.new(
			math.cos(angle) * Constants.ORBIT_BASE_RADIUS,
			Constants.ORBIT_HEIGHT,
			math.sin(angle) * Constants.ORBIT_BASE_RADIUS
		)
end

function Mining.Step(
	zone: Types.Zone,
	player: Player,
	data: PlayerData.Data,
	now: number
): (PlayerData.Data?, number)
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not character or not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return nil, 0
	end
	local position = root.CFrame.Position
	if position.X ~= position.X or position.Y ~= position.Y or position.Z ~= position.Z then
		return nil, 0
	end
	if
		math.abs(position.X - zone.Centre.X) > Config.FloorSize / 2 + 8
		or math.abs(position.Z - zone.Centre.Z) > Config.FloorSize / 2 + 8
		or position.Y < zone.Centre.Y - 8
		or position.Y > zone.Centre.Y + 20
	then
		character:PivotTo(CFrame.new(zone.Centre + Vector3.new(0, 5, 0)))
		return nil, 0
	end
	local working: PlayerData.Data? = nil
	local broken = 0
	for index, id in data.Loadout do
		local pickPosition = Mining.GetPickPosition(
			position,
			workspace:GetServerTimeNow(),
			Progression.GetOrbitSpeed(data),
			index,
			#data.Loadout
		)
		local column = math.floor(
			(pickPosition.X - zone.Centre.X) / Config.CellSize + (Config.MineColumns + 1) / 2 + 0.5
		)
		local row =
			math.floor((pickPosition.Z - zone.Centre.Z) / Config.CellSize + (Config.MineRows + 1) / 2 + 0.5)
		if column < 1 or column > Config.MineColumns or row < 1 or row > Config.MineRows then
			continue
		end
		local key = Builder.Key(column, row)
		local rock = zone.Rocks[key]
		if not rock or now - (zone.LastHits[key] or -math.huge) < Constants.STRIKE_BASE_COOLDOWN then
			continue
		end
		local delta = rock.Part.CFrame.Position - pickPosition
		if Vector2.new(delta.X, delta.Z).Magnitude > Config.CellSize then
			continue
		end
		zone.LastHits[key] = now
		rock.Hp = math.max(0, rock.Hp - Catalog.GetDamage(id))
		rock.Part:SetAttribute(Constants.ROCK_HP_ATTRIBUTE, rock.Hp)
		if rock.Hp == 0 then
			zone.Rocks[key] = nil
			zone.Remaining -= 1
			rock.Part:Destroy()
			local nextData = working or PlayerData.Clone(data)
			working = nextData
			Progression.AwardBlock(nextData, rock.Value)
			broken += 1
		end
	end
	return working, broken
end

function Mining.MoveIdle(zone: Types.Zone, player: Player)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not humanoid or not root or not root:IsA("BasePart") then
		return
	end
	local target: Types.Rock? = nil
	local distance = math.huge
	for _, rock in zone.Rocks do
		local nextDistance = (rock.Part.CFrame.Position - root.CFrame.Position).Magnitude
		if nextDistance < distance then
			target, distance = rock, nextDistance
		end
	end
	if target then
		local targetPosition = target.Part.CFrame.Position
		local delta = Vector3.new(
			targetPosition.X - root.CFrame.Position.X,
			0,
			targetPosition.Z - root.CFrame.Position.Z
		)
		local direction = if delta.Magnitude > 0.01 then delta.Unit else Vector3.new(1, 0, 0)
		local destination = targetPosition - direction * Constants.ORBIT_BASE_RADIUS
		humanoid:MoveTo(Vector3.new(destination.X, zone.Centre.Y, destination.Z))
	end
end

return Mining
