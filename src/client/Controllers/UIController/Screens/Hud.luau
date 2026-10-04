--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Packets)
local Config = require(ReplicatedStorage.Config.GameConfig)
local Constants = require(ReplicatedStorage.Config.Constants)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local Types = require(script.Parent.Parent.Types)
local Elements = require(script.Parent.Parent.Elements)

local Hud = {}

function Hud.new(context: Types.Context, gui: GuiObject): Types.Screen
	local screen = Elements.New(context, gui, "Hud", false)
	local buttons: { [string]: string } = {
		Loadout = "Loadout",
		Roller = "Roller",
		Upgrade = "Upgrades",
		Settings = "Settings",
		Collection = "Collection",
	}
	for button, panel in buttons do
		Elements.Bind(screen, "Stage.ThumbRow." .. button, function()
			context.Open(panel)
			if panel == "Roller" then
				Packets.Roll:Fire()
			end
		end)
	end
	Elements.Bind(screen, "Stage.Rail.Rebirth", function()
		context.Open("Rebirth")
	end)
	Elements.Bind(screen, "Stage.LeftRail.Mode", function()
		local data = context.Controllers.DataController:Get()
		if data then
			Packets.SetIdle:Fire(not data.Idle)
		end
	end)
	for _, path in
		{
			"Stage.Rail.Gear",
			"Stage.Rail.Potions",
			"Stage.Rail.Shop",
			"Stage.LeftRail.Throw",
			"Stage.LeftRail.PickDrop",
			"Stage.LeftRail.Ranks",
			"Stage.GroupBanner",
			"Stage.Milestones",
			"Stage.PowerUpStrip",
			"BottomScreen",
			"Debug",
			"Backdrop",
		}
	do
		Elements.Visible(gui, path, false)
	end
	Elements.Visible(gui, "Stage.Tooltip", false)
	Elements.Visible(gui, "Stage.Toast", false)
	Elements.Visible(gui, "Stage.Money.Gain", false)
	screen.Update = function(_, data: any)
		Elements.Text(gui, "Stage.Money.Amount", "$" .. NumberFormat.Compact(data.Cash))
		Elements.Text(gui, "Stage.Level.Amount", `LV {data.Level}`)
		local luck = math.min(
			Constants.LUCK_CAP,
			Constants.LUCK_PER_LEVEL ^ data.Upgrades.Luck * Constants.LUCK_PER_REBIRTH ^ data.Rebirths
		)
		local interval = math.max(
			Constants.ROLL_MIN_SPIN,
			Constants.ROLL_BASE_SPIN - Constants.ROLL_SPIN_PER_LEVEL * data.Upgrades.RollSpeed
		) + Constants.ROLL_REST_SECONDS
		Elements.Text(gui, "Stage.Readouts.Luck.Value", "x" .. NumberFormat.Compact(luck))
		Elements.Text(gui, "Stage.Readouts.Interval.Value", string.format("%.2fs", interval))
		Elements.Text(gui, "Stage.LeftRail.Mode.Caption", if data.Idle then "Idle on" else "Idle off")
		Elements.Text(gui, "Stage.ThumbRow.Loadout.Badge", tostring(#data.Loadout))
		Elements.Visible(gui, "Stage.ThumbRow.Upgrade.Badge", false)
		Elements.Visible(gui, "Stage.Level.Gate", false)
	end
	Elements.Pair(gui, "Stage.ThumbRow.Roller.Caption", "Roll")
	assert(Config.Name ~= "")
	return screen
end

return Hud
