--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Packets)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local Types = require(script.Parent.Parent.Types)
local Elements = require(script.Parent.Parent.Elements)

local OfflineClaim = {}
local prefix = "Main.Box.Content.Body."

function OfflineClaim.new(context: Types.Context, gui: GuiObject): Types.Screen
	local screen = Elements.New(context, gui, "OfflineClaim", true)
	Elements.Visible(gui, prefix .. "Footer.ClaimX2Button", false)
	Elements.Bind(screen, prefix .. "Footer.ClaimButton", function()
		Packets.ClaimOffline:Fire()
		context.Close("OfflineClaim")
	end)
	Elements.Pair(gui, prefix .. "Span", "Welcome back! Your rig earned coins while you were away.")
	screen.Update = function(_, data: any)
		local amount = Elements.Get(gui, prefix .. "Amount")
		if amount then
			for _, child in amount:GetDescendants() do
				if child:IsA("TextLabel") then
					child.Text = "$" .. NumberFormat.Compact(data.OfflineCash)
				end
			end
		end
	end
	return screen
end

return OfflineClaim
