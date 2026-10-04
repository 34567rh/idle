--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Config.GameConfig)
local Constants = require(ReplicatedStorage.Config.Constants)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local Builder = require(script.Builder)
local Mining = require(script.Mining)
local Types = require(script.Types)

local MineService = { Name = "MineService" }
local services: { [string]: any } = {}
local zones: { [Player]: Types.Zone } = {}
local usedSlots: { [number]: boolean } = {}
local connections: { any } = {}
local characterConnections: { [Player]: any } = {}
local random = Random.new()
local root: Folder
local tickAccumulator = 0
local stopped = false

function MineService.Init(_self: any, registry: { [string]: any })
	services = registry
	root = Instance.new("Folder")
	root.Name = Constants.ZONE_ROOT_NAME
	root.Parent = workspace
end

local function positionCharacter(player: Player, character: Model)
	task.spawn(function()
		local body = character:WaitForChild("HumanoidRootPart", 10)
		local zone = zones[player]
		if body and zone and not stopped and character.Parent and player.Character == character then
			character:PivotTo(CFrame.new(zone.Centre + Vector3.new(0, 5, 0)))
			services.GameService:Publish(player)
		end
	end)
end

function MineService.Reset(_self: any, player: Player)
	local zone = zones[player]
	local data = services.DataService:GetData(player)
	if zone and data then
		Builder.Fill(zone, data.Level, random)
		if player.Character then
			positionCharacter(player, player.Character)
		end
	end
end

local function addPlayer(player: Player)
	if stopped or zones[player] then
		return
	end
	local slot = 1
	while usedSlots[slot] do
		slot += 1
	end
	usedSlots[slot] = true
	zones[player] = Builder.Create(root, player, slot)
	MineService:Reset(player)
	characterConnections[player] = player.CharacterAdded:Connect(function(character: Model)
		positionCharacter(player, character)
	end)
	if player.Character then
		positionCharacter(player, player.Character)
	else
		task.spawn(function()
			if player.Parent == Players and not stopped then
				local success, message = pcall(function()
					player:LoadCharacterAsync()
				end)
				if not success then
					warn(`[MineService] Character load failed: {message}`)
				end
			end
		end)
	end
end

local function removePlayer(player: Player)
	local zone = zones[player]
	if zone then
		usedSlots[zone.Slot] = nil
		zone.Folder:Destroy()
		zones[player] = nil
	end
	local connection = characterConnections[player]
	if connection then
		connection:Disconnect()
		characterConnections[player] = nil
	end
end

function MineService.Start(_self: any)
	table.insert(connections, services.DataService.PlayerLoaded:Connect(addPlayer))
	table.insert(connections, Players.PlayerRemoving:Connect(removePlayer))
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(delta: number)
			tickAccumulator += delta
			if tickAccumulator < Config.MineTick then
				return
			end
			local step = math.min(tickAccumulator, 0.5)
			tickAccumulator = 0
			for player, zone in zones do
				zone.Elapsed += step
				zone.MoveElapsed += step
				local data = services.DataService:GetData(player)
				if not data then
					continue
				end
				local updated = Mining.Step(zone, player, data, os.clock())
				if updated then
					services.GameService:Commit(player, updated)
					data = updated
				end
				if data.Idle and zone.MoveElapsed >= 0.5 then
					zone.MoveElapsed = 0
					Mining.MoveIdle(zone, player)
				end
				if zone.Remaining == 0 then
					local cleared = PlayerData.Clone(data)
					cleared.Clears += 1
					cleared.Cash = math.min(
						Config.MaxCash,
						cleared.Cash
							+ math.floor(
								zone.Value * (1 + Constants.CLEAR_BONUS_PER_LEVEL * cleared.Upgrades.Haul)
							)
					)
					services.GameService:Commit(player, cleared)
					MineService:Reset(player)
				end
			end
		end)
	)
end

function MineService.Destroy(_self: any)
	stopped = true
	for _, connection in connections do
		connection:Disconnect()
	end
	for player in zones do
		removePlayer(player)
	end
	table.clear(connections)
	if root then
		root:Destroy()
	end
end

return MineService
