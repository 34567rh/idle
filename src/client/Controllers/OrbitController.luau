--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Catalog = require(ReplicatedStorage.Utils.Catalog)
local Constants = require(ReplicatedStorage.Config.Constants)

type Ring = { Character: Model, Signature: string, Parts: { BasePart } }

local OrbitController = { Name = "OrbitController" }
local rings: { [Player]: Ring } = {}
local connections: { RBXScriptConnection } = {}
local template: BasePart?
local stopped = false
local startup: thread? = nil

local function clear(player: Player)
	local ring = rings[player]
	if ring then
		for _, part in ring.Parts do
			part:Destroy()
		end
		rings[player] = nil
	end
end

local function refresh(player: Player, character: Model, signature: string): Ring?
	clear(player)
	local success, ids = pcall(function()
		return HttpService:JSONDecode(signature)
	end)
	if not success or type(ids) ~= "table" or not template then
		return nil
	end
	local ring: Ring = { Character = character, Signature = signature, Parts = {} }
	for _, id in ids do
		if type(id) ~= "string" or not Catalog.Get(id) then
			continue
		end
		local part = template:Clone()
		part.Name = `Pick_{id}`
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		for _, child in part:GetDescendants() do
			if child:IsA("ImageLabel") then
				child.Image = Catalog.GetImage(id)
				child.ImageColor3 = Color3.new(1, 1, 1)
			elseif child:IsA("BillboardGui") then
				child.Enabled = true
			end
		end
		part.Parent = workspace
		table.insert(ring.Parts, part)
	end
	rings[player] = ring
	return ring
end

function OrbitController.Init(_self: any, _registry: { [string]: any }) end

local function mount()
	local assets = ReplicatedStorage:WaitForChild("RecoveryAssets", 15)
	local rig = if assets then assets:FindFirstChild("OrbitRig") else nil
	local source = if rig then rig:FindFirstChild("Pick_Wooden") else nil
	if stopped then
		return
	end
	if not source or not source:IsA("BasePart") then
		warn("[OrbitController] Missing authored RecoveryAssets.OrbitRig.Pick_Wooden")
		return
	end
	template = source
	table.insert(connections, Players.PlayerRemoving:Connect(clear))
	table.insert(
		connections,
		RunService.RenderStepped:Connect(function()
			local elapsed = workspace:GetServerTimeNow()
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
				local signature = if character then character:GetAttribute("PickIds") else nil
				if not character or not root or not root:IsA("BasePart") or type(signature) ~= "string" then
					clear(player)
					continue
				end
				local ring: Ring? = rings[player]
				if not ring or ring.Character ~= character or ring.Signature ~= signature then
					ring = refresh(player, character, signature)
				end
				if not ring then
					continue
				end
				local speed = character:GetAttribute("OrbitSpeed")
				if type(speed) ~= "number" then
					speed = Constants.ORBIT_BASE_SPEED
				end
				for index, part in ring.Parts do
					local angle = elapsed * speed * math.pi * 2 + (index - 1) * math.pi * 2 / #ring.Parts
					local position = root.Position
						+ Vector3.new(
							math.cos(angle) * Constants.ORBIT_BASE_RADIUS,
							Constants.ORBIT_HEIGHT,
							math.sin(angle) * Constants.ORBIT_BASE_RADIUS
						)
					part.CFrame = CFrame.new(position) * CFrame.Angles(0, -angle, 0)
				end
			end
		end)
	)
end

function OrbitController.Start(_self: any)
	startup = task.defer(mount)
end

function OrbitController.Destroy(_self: any)
	stopped = true
	if startup then
		pcall(task.cancel, startup)
	end
	for _, connection in connections do
		connection:Disconnect()
	end
	for player in rings do
		clear(player)
	end
	table.clear(connections)
end

return OrbitController
