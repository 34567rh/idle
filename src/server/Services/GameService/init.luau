--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Packets = require(ReplicatedStorage.Packets)
local Constants = require(ReplicatedStorage.Config.Constants)
local Progression = require(script.Parent.Parent.Data.Progression)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local Actions = require(script.Actions)

local GameService = { Name = "GameService" }
local services: { [string]: any } = {}
local connections: { any } = {}
local nextRoll: { [Player]: number } = {}
local random = Random.new()
local accumulator = 0

function GameService.Init(_self: any, registry: { [string]: any })
	services = registry
end

function GameService.Publish(_self: any, player: Player)
	local data = services.DataService:GetData(player)
	local replica = services.DataService:GetReplica(player)
	if not data or not replica then
		return
	end
	local character = player.Character
	if character then
		local pickIds = HttpService:JSONEncode(data.Loadout)
		if character:GetAttribute("PickIds") ~= pickIds then
			character:SetAttribute("PickIds", pickIds)
		end
		character:SetAttribute("OrbitSpeed", Progression.GetOrbitSpeed(data))
		character:SetAttribute("OrbitRadius", Constants.ORBIT_BASE_RADIUS)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = Progression.GetWalkSpeed(data)
		end
	end
end

function GameService.Commit(_self: any, player: Player, data: PlayerData.Data): boolean
	local replica = services.DataService:GetReplica(player)
	if not replica or not PlayerData.Validate(data) then
		return false
	end
	local publicData: { [string]: any } = {}
	for key in PlayerData.Template :: any do
		if key ~= "LastSeenAt" and key ~= "Receipts" and key ~= "SchemaVersion" then
			publicData[key] = data[key]
		end
	end
	replica:SetValues({}, publicData)
	GameService:Publish(player)
	return true
end

function GameService.Roll(_self: any, player: Player, now: number): boolean
	local data = services.DataService:GetData(player)
	if not data or now < (nextRoll[player] or 0) then
		return false
	end
	nextRoll[player] = now + Progression.GetRollInterval(data)
	local working = PlayerData.Clone(data)
	local id = Progression.Roll(working, random:NextNumber())
	if not GameService:Commit(player, working) then
		return false
	end
	Packets.RollResult:FireClient(player, id)
	GameService:Publish(player)
	return true
end

local function bindAction(name: string)
	local packet = (Packets :: any)[name]
	table.insert(
		connections,
		packet.OnServerEvent:Connect(function(player: Player, first: any, second: any)
			local success, message = Actions.Apply(services, player, name, first, second)
			if success then
				GameService:Publish(player)
			end
			Actions.Notify(player, message)
		end)
	)
end

function GameService.Start(_self: any)
	for _, name in
		{
			"BuyUpgrade",
			"BuyAll",
			"BuySlot",
			"Equip",
			"EquipBest",
			"Rebirth",
			"ClaimOffline",
			"SetAutoRoll",
			"SetAutoEquip",
			"SetIdle",
		}
	do
		bindAction(name)
	end
	table.insert(
		connections,
		Packets.Roll.OnServerEvent:Connect(function(player: Player)
			if not GameService:Roll(player, os.clock()) then
				Actions.Notify(player, "The roller is cooling down. Try again shortly.")
			end
		end)
	)
	table.insert(
		connections,
		services.DataService.PlayerLoaded:Connect(function(player: Player)
			GameService:Publish(player)
		end)
	)
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(player: Player)
			nextRoll[player] = nil
		end)
	)
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(delta: number)
			accumulator += delta
			if accumulator < 0.25 then
				return
			end
			accumulator = 0
			for _, player in Players:GetPlayers() do
				local data = services.DataService:GetData(player)
				if data and data.AutoRoll then
					GameService:Roll(player, os.clock())
				end
			end
		end)
	)
end

function GameService.Destroy(_self: any)
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(nextRoll)
end

return GameService
