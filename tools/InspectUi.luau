--!strict

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local place = roblox.deserializePlace(fs.readFile("assets/The_Idle_Mines.original.rbxl"))
fs.writeDir("inspection")
local templates = place:FindFirstChild("ReplicatedStorage"):FindFirstChild("UITemplates")
local report = {}
for _, instance in templates:GetDescendants() do
	if instance:IsA("GuiObject") then
		local info = { Path = instance:GetFullName(), Class = instance.ClassName, Visible = instance.Visible }
		if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
			info.Text = instance.Text
		end
		if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
			local ok, image = pcall(function()
				return instance.Image
			end)
			if ok then
				info.Image = image
			end
		end
		table.insert(report, info)
	end
end
fs.writeFile("inspection/ui.json", serde.encode("json", report, true))
local storage = place:FindFirstChild("ReplicatedStorage")
fs.writeFile("inspection/ui-template.rbxm", roblox.serializeModel({ templates }))
local world = place:FindFirstChild("Workspace")
local zones = {}
for _, zone in world:FindFirstChild("Digs"):GetChildren() do
	local parts = {}
	for _, obj in zone:GetDescendants() do
		if obj:IsA("BasePart") and #parts < 12 then
			table.insert(
				parts,
				{ Name = obj.Name, Position = tostring(obj.CFrame.Position), Size = tostring(obj.Size) }
			)
		end
	end
	local attributes = {}
	for name, value in zone:GetAttributes() do
		attributes[name] = tostring(value)
	end
	table.insert(zones, { Name = zone.Name, Attributes = attributes, Parts = parts })
end
fs.writeFile("inspection/zones.json", serde.encode("json", zones, true))
print("UI elements:", #report)
