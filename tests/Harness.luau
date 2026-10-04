--!strict

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local task = require("@lune/task")

local Harness = {}

function Harness.Signal()
	local callbacks = {}
	return {
		Connect = function(_, callback)
			local key = {}
			callbacks[key] = callback
			return {
				Disconnect = function()
					callbacks[key] = nil
				end,
			}
		end,
		Fire = function(_, ...)
			for _, callback in table.clone(callbacks) do
				callback(...)
			end
		end,
	}
end

function Harness.New()
	local place = roblox.deserializePlace(fs.readFile("build/code.rbxlx"))
	local ui =
		roblox.deserializePlace(fs.readFile("assets/The_Idle_Mines.original.rbxl")).ReplicatedStorage.UITemplates
	ui.Parent = place.ReplicatedStorage
	local cache = {}
	local warnings = {}
	local buttonEvents = {}
	local packets = {}
	for _, name in
		{
			"Roll",
			"EquipBest",
			"Equip",
			"BuyUpgrade",
			"BuyAll",
			"BuySlot",
			"Rebirth",
			"SetAutoRoll",
			"SetAutoEquip",
			"SetIdle",
			"ClaimOffline",
			"Notice",
			"RollResult",
		}
	do
		packets[name] = {
			OnClientEvent = Harness.Signal(),
			OnServerEvent = Harness.Signal(),
			Calls = {},
			Fire = function(self, ...)
				table.insert(self.Calls, table.pack(...))
			end,
			FireClient = function(self, ...)
				table.insert(self.Calls, table.pack(...))
			end,
		}
	end
	cache[place.ReplicatedStorage.Packets] = packets
	roblox.implementProperty("GuiButton", "Activated", function(button)
		if not buttonEvents[button] then
			buttonEvents[button] = Harness.Signal()
		end
		return buttonEvents[button]
	end)
	roblox.implementProperty("BasePart", "Position", function(part)
		return part.CFrame.Position
	end)
	roblox.implementMethod("DataModel", "GetService", function(self, name)
		local existing = self:FindFirstChild(name)
		if existing then
			return existing
		end
		local service = roblox.Instance.new(name)
		service.Parent = self
		return service
	end)
	local function load(module)
		if cache[module] then
			return cache[module]
		end
		assert(module:IsA("ModuleScript"), "Expected ModuleScript")
		local environment = setmetatable({
			game = place,
			workspace = place:GetService("Workspace"),
			script = module,
			require = load,
			task = task,
			warn = function(message)
				table.insert(warnings, tostring(message))
			end,
			Instance = roblox.Instance,
			Color3 = roblox.Color3,
			Vector2 = roblox.Vector2,
			Vector3 = roblox.Vector3,
			CFrame = roblox.CFrame,
			UDim2 = roblox.UDim2,
			Enum = roblox.Enum,
			Random = {
				new = function()
					return {
						NextNumber = function()
							return 0.5
						end,
					}
				end,
			},
		}, { __index = getfenv() })
		local result =
			luau.load(module.Source, { debugName = module:GetFullName(), environment = environment })()
		cache[module] = result
		return result
	end
	return {
		Place = place,
		Load = load,
		Packets = packets,
		Warnings = warnings,
		Buttons = buttonEvents,
		Cache = cache,
	}
end

return Harness
