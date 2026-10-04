--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Packets)
local Definitions = require(ReplicatedStorage.Config.Upgrades)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local Types = require(script.Parent.Parent.Types)
local Elements = require(script.Parent.Parent.Elements)

local Upgrades = {}
local prefix = "UpgradesPanel.Comb.Canvas."

function Upgrades.new(context: Types.Context, gui: GuiObject): Types.Screen
	local screen = Elements.New(context, gui, "Upgrades", true)
	local canvas = Elements.Get(gui, "UpgradesPanel.Comb.Canvas")
	if canvas and canvas:IsA("GuiObject") then
		canvas.Size = UDim2.fromScale(1, 1)
		canvas.Position = UDim2.fromScale(0.5, 0.5)
		canvas.AnchorPoint = Vector2.new(0.5, 0.5)
		for _, instance in canvas:GetChildren() do
			if instance:IsA("GuiObject") then
				instance.Visible = false
			end
		end
	end
	for index, upgrade in Definitions.All do
		local nodePath = prefix .. "Node" .. upgrade.Node
		local node = Elements.Get(gui, nodePath)
		if node and node:IsA("GuiObject") then
			node.AnchorPoint = Vector2.new(0.5, 0.5)
			node.Position =
				UDim2.fromScale(0.2 + ((index - 1) % 3) * 0.3, 0.28 + math.floor((index - 1) / 3) * 0.42)
			node.Size = UDim2.fromScale(0.23, 0.3)
		end
		Elements.Visible(gui, nodePath, true)
		Elements.Visible(gui, nodePath .. ".Content.Mystery", false)
		Elements.Text(gui, nodePath .. ".Content.Label", upgrade.ShortName)
		Elements.Bind(screen, nodePath, function()
			Packets.BuyUpgrade:Fire(upgrade.Id)
		end)
	end
	Elements.Text(
		gui,
		"UpgradesPanel.Subtitle",
		"Tap an upgrade to buy the next level. All upgrades use coins."
	)
	Elements.Text(
		gui,
		"UpgradesPanel.SubtitleBg",
		"Tap an upgrade to buy the next level. All upgrades use coins."
	)
	Elements.Bind(screen, "UpgradesPanel.BuyAll", function()
		Packets.BuyAll:Fire()
	end)
	Elements.Visible(gui, "UpgradesPanel.Hint", false)
	screen.Update = function(_, data: any)
		for _, upgrade in Definitions.All do
			local nodePath = prefix .. "Node" .. upgrade.Node
			local level = data.Upgrades[upgrade.Id]
			local cost = math.ceil(upgrade.BaseCost * upgrade.CostGrowth ^ level)
			Elements.Text(gui, nodePath .. ".Content.Label", upgrade.ShortName)
			Elements.Text(gui, nodePath .. ".Content.Count", `{level}/{upgrade.MaxLevel}`)
			Elements.Text(
				gui,
				nodePath .. ".Content.Detail",
				if level >= upgrade.MaxLevel then "MAX" else "$" .. NumberFormat.Compact(cost)
			)
		end
	end
	return screen
end

return Upgrades
