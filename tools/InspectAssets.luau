--!strict

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local place = roblox.deserializePlace(fs.readFile("assets/The_Idle_Mines.original.rbxl"))
local function tree(instance, depth, maxDepth)
	print(string.rep("  ", depth) .. instance.Name .. " [" .. instance.ClassName .. "]")
	if depth < maxDepth then
		for _, child in instance:GetChildren() do
			tree(child, depth + 1, maxDepth)
		end
	end
end
for _, name in { "Players", "StarterPlayer" } do
	local service = place:FindFirstChild(name)
	if service then
		print("SERVICE", name)
		for _, property in
			{
				"CharacterAutoLoads",
				"CharacterWalkSpeed",
				"CharacterJumpPower",
				"CameraMode",
				"CameraMinZoomDistance",
				"CameraMaxZoomDistance",
			}
		do
			local ok, value = pcall(function()
				return service[property]
			end)
			if ok then
				print(property, value)
			end
		end
	end
end
local storage = place:FindFirstChild("ReplicatedStorage")
print("UI TEMPLATES")
tree(storage:FindFirstChild("UITemplates"), 0, 4)
local workspace = place:FindFirstChild("Workspace")
for _, name in { "Digs", "OreExport", "MinerCart", "OrbitRig", "Baseplate", "PickaxeRiftChests" } do
	local item = workspace:FindFirstChild(name)
	print("ASSET", name)
	if item then
		tree(item, 0, 2)
		local part = if item:IsA("BasePart") then item else item:FindFirstChildWhichIsA("BasePart", true)
		if part then
			print("POSITION", part.CFrame.Position, "SIZE", part.Size)
		end
	end
end
