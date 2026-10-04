--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Packets)
local Constants = require(ReplicatedStorage.Config.Constants)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local Types = require(script.Parent.Parent.Types)
local Elements = require(script.Parent.Parent.Elements)

local Rebirth = {}
local prefix = "Main.Box.Content.Body."

function Rebirth.new(context: Types.Context, gui: GuiObject): Types.Screen
	local screen = Elements.New(context, gui, "Rebirth", true)
	Elements.Bind(screen, prefix .. "Footer.Confirm", function()
		Packets.Rebirth:Fire()
	end)
	Elements.Pair(gui, prefix .. "Content.Keeps", "PICKAXES AND SLOTS ARE KEPT; MONEY AND UPGRADES RESET")
	screen.Update = function(_, data: any)
		local required = Constants.REBIRTH_BASE_LEVEL + Constants.REBIRTH_LEVEL_STEP * data.Rebirths
		Elements.Text(gui, prefix .. "Content.Need.Content.Held", `{data.Level} / {required}`)
		Elements.Visible(gui, prefix .. "Footer.Confirm.CanRebirth", data.Level >= required)
		Elements.Visible(gui, prefix .. "Footer.Confirm.CannotRebirth", data.Level < required)
		Elements.Pair(gui, prefix .. "Footer.Confirm.CannotRebirth.Content.Caption", `REACH LV {required}`)
		local content = Elements.Get(gui, prefix .. "Content")
		if not content then
			return
		end
		for _, before in content:GetChildren() do
			if before.Name ~= "Before" or not before:IsA("GuiObject") then
				continue
			end
			local label = Elements.Get(before, "Content.Stat")
			local stat = if label and label:IsA("TextLabel") then label.Text else ""
			local current = if stat == "MONEY"
				then NumberFormat.Compact(data.Cash)
				elseif stat == "LEVEL" then tostring(data.Level)
				elseif stat == "REBIRTHS" then tostring(data.Rebirths)
				else "x" .. NumberFormat.Compact(Constants.LUCK_PER_REBIRTH ^ data.Rebirths)
			Elements.Pair(before, "Content.Value", current)
			for _, after in content:GetChildren() do
				if
					after.Name == "After"
					and after:IsA("GuiObject")
					and after.Position.Y == before.Position.Y
				then
					local preview = if stat == "MONEY"
						then "0"
						elseif stat == "LEVEL" then "1"
						elseif stat == "REBIRTHS" then tostring(data.Rebirths + 1)
						else "x" .. NumberFormat.Compact(
							Constants.LUCK_PER_REBIRTH ^ (data.Rebirths + 1)
						)
					Elements.Pair(after, "Content.Value", preview)
					Elements.Pair(
						after,
						"Content.Delta.Label",
						if stat == "REBIRTHS" then "+1" elseif stat == "LUCK" then "x1.15" else "RESET"
					)
				end
			end
		end
	end
	return screen
end

return Rebirth
