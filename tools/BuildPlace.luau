--!strict

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local originalPath = "assets/The_Idle_Mines.original.rbxl"
local codePath = "build/code.rbxlx"
local outputPath = "build/The_Idle_Mines_Recovered.rbxl"
local place = roblox.deserializePlace(fs.readFile(originalPath))
local code = roblox.deserializePlace(fs.readFile(codePath))
local removedScripts = 0
local sourceContainers = {}
for _, instance in place:GetDescendants() do
	if instance:IsA("LuaSourceContainer") then
		table.insert(sourceContainers, instance)
	end
end
for index = #sourceContainers, 1, -1 do
	sourceContainers[index]:Destroy()
	removedScripts += 1
end

local function service(name: string)
	local existing = place:FindFirstChild(name)
	if existing then
		return existing
	end
	local created = roblox.Instance.new(name)
	created.Parent = place
	return created
end

local storage = service("ReplicatedStorage")
local serverStorage = service("ServerStorage")
local workspace = service("Workspace")
local archive = roblox.Instance.new("Folder")
archive.Name = "RecoveryArchive"
archive.Parent = serverStorage
local oldDigs = workspace:FindFirstChild("Digs")
if oldDigs then
	oldDigs.Parent = archive
end
local assets = roblox.Instance.new("Folder")
assets.Name = "RecoveryAssets"
assets.Parent = storage
for _, name in { "OreExport", "OrbitRig" } do
	local source = workspace:FindFirstChild(name)
	assert(source, `Missing authored gameplay asset Workspace.{name}`)
	source.Parent = assets
end
local camera = workspace:FindFirstChildOfClass("Camera")
if camera then
	camera:Destroy()
end

for _, codeService in code:GetChildren() do
	local destination = service(codeService.ClassName)
	for _, child in codeService:GetChildren() do
		if codeService.ClassName == "StarterPlayer" and child.ClassName == "StarterPlayerScripts" then
			local target = destination:FindFirstChildOfClass("StarterPlayerScripts")
			assert(target, "Original place needs StarterPlayerScripts")
			for _, scriptChild in child:GetChildren() do
				local old = target:FindFirstChild(scriptChild.Name)
				if old then
					old:Destroy()
				end
				scriptChild.Parent = target
			end
		else
			local old = destination:FindFirstChild(child.Name)
			if old then
				old:Destroy()
			end
			child.Parent = destination
		end
	end
end

local players = service("Players")
players.CharacterAutoLoads = true
local starterPlayer = service("StarterPlayer")
starterPlayer.CharacterWalkSpeed = 15
starterPlayer.CharacterJumpPower = 50
starterPlayer.CameraMinZoomDistance = 0.5
starterPlayer.CameraMaxZoomDistance = 128
local spawn = roblox.Instance.new("SpawnLocation")
spawn.Name = "RecoverySpawn"
spawn.Anchored = true
spawn.Neutral = true
spawn.Size = roblox.Vector3.new(6, 1, 6)
spawn.CFrame = roblox.CFrame.new(0, 0.5, 0)
spawn.Transparency = 1
spawn.CanCollide = false
spawn.Parent = workspace

local bytecodeContainers = 0
local codeScripts = 0
for _, instance in place:GetDescendants() do
	if instance:IsA("LuaSourceContainer") then
		assert(#instance.Source > 0, `Empty source: {instance:GetFullName()}`)
		if string.find(instance.Source, "Bytecode (Base64)", 1, true) then
			bytecodeContainers += 1
		end
		codeScripts += 1
	end
end
assert(bytecodeContainers == 0, "Unrepaired bytecode containers remain")
assert(storage:FindFirstChild("UITemplates"), "Authored UI templates were not preserved")
assert(place:FindFirstChild("ServerScriptService"):FindFirstChild("Bootstrap"), "Missing server bootstrap")
fs.writeFile(outputPath, roblox.serializePlace(place))
local reopened = roblox.deserializePlace(fs.readFile(outputPath))
assert(reopened:FindFirstChild("Players").CharacterAutoLoads == true)
assert(reopened:FindFirstChild("ReplicatedStorage"):FindFirstChild("UITemplates"))
local report = {
	OriginalSourceContainers = removedScripts,
	RecoveredSourceContainers = codeScripts,
	OriginalAssetPath = originalPath,
	RecoveredPlacePath = outputPath,
	AuthoredUiPreserved = true,
	StudioPlaytested = false,
	InstanceCount = #reopened:GetDescendants(),
}
fs.writeFile("build/recovery-report.json", serde.encode("json", report, true))
print(
	`Built {outputPath}; {removedScripts} non-runnable scripts replaced by {codeScripts} source containers.`
)
