--!strict

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local input = "assets/The_Idle_Mines.original.rbxl"
local place = roblox.deserializePlace(fs.readFile(input))
local roots = place:GetChildren()
local output = "inspection"
fs.writeDir(output .. "/scripts")
local scripts = {}
local services = {}
local classes = {}
local allCount = 0
local function visit(instance)
	allCount += 1
	classes[instance.ClassName] = (classes[instance.ClassName] or 0) + 1
	if instance:IsA("LuaSourceContainer") then
		local index = #scripts + 1
		local file = string.format("%03d_%s.luau", index, instance.Name:gsub("[^%w_%-]", "_"))
		local source = instance.Source
		local info = {
			Id = index,
			Path = instance:GetFullName(),
			Class = instance.ClassName,
			File = file,
			Bytes = #source,
		}
		if instance:IsA("BaseScript") then
			info.Disabled = instance.Disabled
		end
		table.insert(scripts, info)
		fs.writeFile(output .. "/scripts/" .. file, source)
	end
	for _, child in instance:GetChildren() do
		visit(child)
	end
end
for _, root in roots do
	local children = {}
	for _, child in root:GetChildren() do
		table.insert(
			children,
			{ Name = child.Name, Class = child.ClassName, Children = #child:GetChildren() }
		)
	end
	table.insert(services, { Name = root.Name, Class = root.ClassName, Children = children })
	visit(root)
end
local report = { InstanceCount = allCount, Classes = classes, Services = services, Scripts = scripts }
fs.writeFile(output .. "/inventory.json", serde.encode("json", report, true))
print("Instances:", allCount, "Scripts:", #scripts)
for _, info in scripts do
	print(info.Id, info.Class, info.Path, "bytes:", info.Bytes, "disabled:", info.Disabled)
end
