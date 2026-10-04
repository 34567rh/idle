--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Packets)
local Constants = require(ReplicatedStorage.Config.Constants)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Elements = require(script.Elements)
local Types = require(script.Types)

local modules: { [string]: { Module: any, Path: string } } = {
	Hud = { Module = require(script.Screens.Hud), Path = "HUD" },
	Roller = { Module = require(script.Screens.Roller), Path = "Frames.Roller" },
	Loadout = { Module = require(script.Screens.Loadout), Path = "Frames.Loadout" },
	Upgrades = { Module = require(script.Screens.Upgrades), Path = "Frames.UpgradeTree" },
	Rebirth = { Module = require(script.Screens.Rebirth), Path = "Frames.Rebirth" },
	Settings = { Module = require(script.Screens.Settings), Path = "Frames.Settings" },
	Collection = { Module = require(script.Screens.Collection), Path = "Frames.Index" },
	OfflineClaim = { Module = require(script.Screens.OfflineClaim), Path = "Frames.OfflineClaim" },
}

local UIController = { Name = "UIController" }
local controllers: { [string]: any } = {}
local screens: { [string]: Types.Screen } = {}
local openScreens: { [string]: boolean } = {}
local trove: any = nil
local gui: ScreenGui? = nil
local latestData: any = nil
local toastGeneration = 0
local welcomed = false
local stopped = false

function UIController.Init(_self: any, registry: { [string]: any })
	controllers = registry
	trove = Trove.new()
end

function UIController.Open(_self: any, name: string)
	local screen = screens[name]
	if not screen then
		return
	end
	if screen.Modal then
		for otherName, other in screens do
			if other.Modal and otherName ~= name then
				other:Close()
				openScreens[otherName] = nil
			end
		end
	end
	screen:Open()
	openScreens[name] = true
	local update = screen.Update
	if latestData and update then
		update(screen, latestData)
	end
end

function UIController.Close(_self: any, name: string)
	local screen = screens[name]
	if screen then
		screen:Close()
		openScreens[name] = nil
	end
end

function UIController.IsOpen(_self: any, name: string): boolean
	return openScreens[name] == true
end

function UIController.Notify(_self: any, message: string)
	local currentGui = gui
	if not currentGui then
		return
	end
	toastGeneration += 1
	local generation = toastGeneration
	Elements.Text(currentGui, "HUD.Stage.Toast.Plate.Content.Text", message)
	Elements.Visible(currentGui, "HUD.Stage.Toast", true)
	local toast = Elements.Get(currentGui, "HUD.Stage.Toast")
	if toast and toast:IsA("CanvasGroup") then
		toast.GroupTransparency = 0
	end
	trove:Add(task.delay(4, function()
		if generation == toastGeneration and gui then
			Elements.Visible(gui, "HUD.Stage.Toast", false)
		end
	end))
end

local function mount()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", 15)
	local templates = ReplicatedStorage:WaitForChild("UITemplates", 15)
	if stopped then
		return
	end
	if not playerGui or not templates or not templates:IsA("ScreenGui") then
		error("Expected PlayerGui and the authored ReplicatedStorage.UITemplates ScreenGui")
	end
	local clone = templates:Clone()
	clone.Name = "TheIdleMinesUI"
	clone.ResetOnSpawn = false
	clone.Enabled = true
	clone.Parent = playerGui
	gui = clone
	trove:Add(clone)
	local frames = clone:FindFirstChild("Frames")
	if frames and frames:IsA("GuiObject") then
		frames.Visible = true
		for _, panel in frames:GetChildren() do
			if panel:IsA("GuiObject") then
				panel.Visible = false
			end
		end
	end
	local pickDrop = clone:FindFirstChild("PickDrop")
	if pickDrop then
		pickDrop:Destroy()
	end
	local context: Types.Context = {
		Controllers = controllers,
		Open = function(name: string)
			UIController:Open(name)
		end,
		Close = function(name: string)
			UIController:Close(name)
		end,
		Notify = function(message: string)
			UIController:Notify(message)
		end,
	}
	for name, entry in modules do
		local panel = Elements.Get(clone, entry.Path)
		if not panel or not panel:IsA("GuiObject") then
			warn(`[UIController] Missing authored panel {entry.Path}; only {name} is disabled`)
			continue
		end
		local success, result = pcall(entry.Module.new, context, panel)
		if not success then
			warn(`[UIController] {name} failed to initialize: {result}`)
			continue
		end
		local screen = result :: Types.Screen
		screens[name] = screen
		trove:Add(function()
			screen:Destroy()
		end)
		if screen.StartsOpen then
			UIController:Open(name)
		end
	end
	trove:Add(Packets.Notice.OnClientEvent:Connect(function(message: string)
		UIController:Notify(message)
	end))
	trove:Add(controllers.DataController:Observe({}, function(data: any)
		latestData = data
		for name, screen in screens do
			local update = screen.Update
			if openScreens[name] and update then
				update(screen, data)
			end
		end
		if not welcomed then
			welcomed = true
			Players.LocalPlayer:SetAttribute(Constants.CLIENT_READY_ATTRIBUTE, true)
			UIController:Notify("Move through the mine, or turn Idle on. Tap Roll for better pickaxes!")
			if data.OfflineCash > 0 then
				UIController:Open("OfflineClaim")
			end
		end
	end))
end

function UIController.Start(_self: any)
	trove:Add(task.defer(mount))
end

function UIController.Destroy(_self: any)
	stopped = true
	if trove then
		trove:Destroy()
	end
	gui = nil
	table.clear(screens)
	table.clear(openScreens)
end

return UIController
