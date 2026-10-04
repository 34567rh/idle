--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.Utils.Catalog)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local Types = require(script.Parent.Parent.Types)
local Elements = require(script.Parent.Parent.Elements)

local Collection = {}
local prefix = "Main.Box.Content.Body.Content.Main."

function Collection.new(context: Types.Context, gui: GuiObject): Types.Screen
	local screen = Elements.New(context, gui, "Collection", true)
	local scroller = Elements.Get(gui, prefix .. "Cards.Content.Pickaxes")
	local cards: { GuiButton } = {}
	if scroller and scroller:IsA("ScrollingFrame") then
		scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroller.CanvasSize = UDim2.fromOffset(0, 0)
		for _, child in scroller:GetChildren() do
			if child:IsA("GuiButton") then
				table.insert(cards, child)
			end
		end
	end
	Elements.Visible(gui, prefix .. "Cards.Content.Ores", false)
	Elements.Visible(gui, prefix .. "Progress.Content.Ores", false)
	Elements.Visible(gui, prefix .. "Finishes", false)
	Elements.Visible(gui, "Main.Box.Content.Body.Content.Rail", false)
	Elements.Pair(gui, "Main.Box.Content.TitleBar.Content.Title", "PICKAXE INDEX")
	screen.Update = function(_, data: any)
		if #cards == 0 or not scroller then
			return
		end
		while #cards < #Catalog.All do
			local card = cards[1]:Clone()
			card.Name = `Card{#cards + 1}`
			card.Parent = scroller
			table.insert(cards, card)
		end
		local found = 0
		for index, pick in Catalog.All do
			local card = cards[index]
			local owned = data.Inventory[pick.Id] ~= nil
			if owned then
				found += 1
			end
			card.Visible = true
			card.LayoutOrder = index
			Elements.Visible(card, "Found", owned)
			Elements.Visible(card, "Missing", not owned)
			Elements.Pair(card, "Found.Name", pick.Name)
			Elements.Pair(card, "Found.Odds", "1 IN " .. NumberFormat.Compact(pick.OneIn))
			Elements.PickArt(card, "Found.Zone.Art", pick.Id)
			Elements.Pair(card, "Missing.Name", "UNDISCOVERED")
			Elements.Pair(card, "Found.Zone.Count", "x" .. tostring(data.Inventory[pick.Id] or 0))
			Elements.Visible(card, "Found.Zone.Claim", false)
			Elements.Visible(card, "Found.Zone.Claimed", false)
		end
		Elements.Pair(gui, prefix .. "Progress.Content.Pickaxes.Found", tostring(found))
		Elements.Pair(gui, prefix .. "Progress.Content.Pickaxes.Total", "/ " .. tostring(#Catalog.All))
		Elements.Pair(
			gui,
			prefix .. "Progress.Content.Pickaxes.Bar.Percent",
			string.format("%.0f%%", found / #Catalog.All * 100)
		)
	end
	return screen
end

return Collection
