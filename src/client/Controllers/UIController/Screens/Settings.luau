--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Packets)
local Constants = require(ReplicatedStorage.Config.Constants)
local Catalog = require(ReplicatedStorage.Utils.Catalog)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local Types = require(script.Parent.Parent.Types)
local Elements = require(script.Parent.Parent.Elements)

local Settings = {}
local left = "Main.Box.Content.Body.Content.Left.Options."
local toggles: { [string]: string } = { ["Auto spin"] = "AutoRoll", ["Auto-equip best"] = "AutoEquipBest" }
local stats = "Main.Box.Content.Body.Content.Right.Stats."

function Settings.new(context: Types.Context, gui: GuiObject): Types.Screen
	local screen = Elements.New(context, gui, "Settings", true)
	for label, setting in toggles do
		Elements.Bind(screen, left .. label .. ".Content.State", function()
			local data = context.Controllers.DataController:Get()
			if data then
				if setting == "AutoRoll" then
					Packets.SetAutoRoll:Fire(not data.AutoRoll)
				else
					Packets.SetAutoEquip:Fire(not data.AutoEquipBest)
				end
			end
		end)
	end
	for _, name in { "Auto use potions", "Sound effects", "Music" } do
		Elements.Visible(gui, left .. name, false)
	end
	Elements.Visible(gui, stats .. "PLAYTIME", false)
	Elements.Visible(gui, stats .. "RAREST", false)
	screen.Update = function(_, data: any)
		for label, setting in toggles do
			Elements.Visible(gui, left .. label .. ".Content.State.On", data[setting] == true)
			Elements.Visible(gui, left .. label .. ".Content.State.Off", data[setting] ~= true)
		end
		local damage = 0
		for _, id in data.Loadout do
			damage += Catalog.GetDamage(id)
		end
		Elements.Pair(gui, stats .. "RING DAMAGE.Content.Value", NumberFormat.Compact(damage))
		Elements.Pair(gui, stats .. "BLOCKS BROKEN.Content.Value", NumberFormat.Compact(data.BlocksBroken))
		Elements.Pair(gui, stats .. "ROLLS.Content.Value", NumberFormat.Compact(data.Rolls))
		Elements.Pair(
			gui,
			stats .. "LUCK.Content.Value",
			"x"
				.. NumberFormat.Compact(
					math.min(
						Constants.LUCK_CAP,
						Constants.LUCK_PER_LEVEL ^ data.Upgrades.Luck
							* Constants.LUCK_PER_REBIRTH ^ data.Rebirths
					)
				)
		)
	end
	return screen
end

return Settings
