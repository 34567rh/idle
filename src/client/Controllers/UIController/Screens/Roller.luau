--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Packets)
local Catalog = require(ReplicatedStorage.Utils.Catalog)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local Types = require(script.Parent.Parent.Types)
local Elements = require(script.Parent.Parent.Elements)

local Roller = {}

function Roller.new(context: Types.Context, gui: GuiObject): Types.Screen
	local screen = Elements.New(context, gui, "Roller", true)
	local latest: string? = nil
	Elements.Visible(gui, "Stage.RollStrip", false)
	Elements.Visible(gui, "Stage.Takeover", false)
	Elements.Visible(gui, "Stage.RollScreen.Rack", false)
	Elements.Bind(screen, "Stage.RollScreen.Controls.Hide", function()
		context.Close("Roller")
	end)
	Elements.Bind(screen, "Stage.RollScreen.Controls.AutoSpin", function()
		local data = context.Controllers.DataController:Get()
		if data then
			Packets.SetAutoRoll:Fire(not data.AutoRoll)
		end
	end)
	local function display(id: string)
		local pick = Catalog.Get(id)
		if not pick then
			return
		end
		latest = id
		Elements.Visible(gui, "Stage.Takeover", true)
		Elements.Text(gui, "Stage.Takeover.Name", pick.Name)
		Elements.Text(gui, "Stage.Takeover.Odds", "1 in " .. NumberFormat.Compact(pick.OneIn))
		Elements.Text(gui, "Stage.Takeover.Tier", string.upper(pick.Tier))
		Elements.Text(gui, "Stage.Takeover.IsNew", "ADDED TO YOUR PICKAXES")
		Elements.Text(gui, "Stage.Takeover.ChainSpent", "Tap the result to roll again")
		Elements.PickArt(gui, "Stage.Takeover.Art", id)
	end
	Elements.Bind(screen, "Stage.Takeover.Scrim", function()
		Packets.Roll:Fire()
	end)
	Elements.Bind(screen, "Stage.RollScreen.Scrim", function()
		Packets.Roll:Fire()
	end)
	screen.Trove:Add(Packets.RollResult.OnClientEvent:Connect(function(id: string)
		display(id)
		local pick = Catalog.Get(id)
		if pick then
			context.Notify(`Rolled {pick.Name}!`)
		end
	end))
	screen.Update = function(_, data: any)
		Elements.Text(gui, "Stage.RollScreen.Title", "ROLL — tap to spin")
		Elements.Text(gui, "Stage.RollScreen.Luck", `{data.Rolls} rolls`)
		Elements.Text(
			gui,
			"Stage.RollScreen.Controls.AutoSpin.Caption",
			if data.AutoRoll then "Auto on" else "Auto off"
		)
		if latest then
			display(latest)
		end
	end
	return screen
end

return Roller
