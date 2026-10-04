--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Packets)
local Config = require(ReplicatedStorage.Config.GameConfig)
local Catalog = require(ReplicatedStorage.Utils.Catalog)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local Types = require(script.Parent.Parent.Types)
local Elements = require(script.Parent.Parent.Elements)

local Loadout = {}
local body = "Main.Box.Content.Body.Content."

function Loadout.new(context: Types.Context, gui: GuiObject): Types.Screen
	local screen = Elements.New(context, gui, "Loadout", true)
	local selectedSlot = 1
	local cards: { GuiButton } = {}
	local scroller = Elements.Get(gui, body .. "RightCol.Picks.Content.Scroller")
	if scroller and scroller:IsA("ScrollingFrame") then
		scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroller.CanvasSize = UDim2.fromOffset(0, 0)
		for _, child in scroller:GetChildren() do
			if child:IsA("GuiButton") and string.match(child.Name, "^Card%d+$") then
				table.insert(cards, child)
			end
		end
		table.sort(cards, function(a, b)
			return (tonumber(string.match(a.Name, "%d+")) or 0) < (tonumber(string.match(b.Name, "%d+")) or 0)
		end)
	end
	local function wireCard(card: GuiButton)
		card.Active = true
		card.Interactable = true
		screen.Trove:Add(card.Activated:Connect(function()
			local id = card:GetAttribute("PickId")
			if type(id) == "string" then
				Packets.Equip:Fire(id, selectedSlot)
			end
		end))
	end
	for _, card in cards do
		wireCard(card)
		card.Visible = false
	end
	for slot = 1, 15 do
		Elements.Bind(screen, body .. "LeftCol.Ring.Slot" .. slot, function()
			local data = context.Controllers.DataController:Get()
			if data and slot <= data.Slots then
				selectedSlot = math.min(slot, #data.Loadout + 1)
				Elements.Pair(gui, body .. "RightCol.Head.Status", `TAP A PICK FOR SLOT {selectedSlot}`)
			end
		end)
	end
	Elements.Bind(screen, body .. "LeftCol.Actions.EquipBest", function()
		Packets.EquipBest:Fire()
	end)
	Elements.Bind(screen, body .. "LeftCol.Actions.AutoEquip", function()
		local data = context.Controllers.DataController:Get()
		if data then
			Packets.SetAutoEquip:Fire(not data.AutoEquipBest)
		end
	end)
	Elements.Bind(screen, body .. "LeftCol.NextSlot.Content.Buy", function()
		Packets.BuySlot:Fire()
	end)
	Elements.Visible(gui, body .. "RightCol.Finishes", false)
	Elements.Visible(gui, body .. "LeftCol.NextSlot.Content.Skip", false)
	Elements.Pair(
		gui,
		body .. "LeftCol.NextSlot.Content.Sold",
		"All available recovery slots are earned with coins"
	)
	screen.Update = function(_, data: any)
		local ids: { string } = {}
		for id in data.Inventory do
			table.insert(ids, id)
		end
		table.sort(ids, function(a, b)
			return Catalog.GetDamage(a) > Catalog.GetDamage(b)
		end)
		if #cards > 0 and scroller then
			while #cards < #ids do
				local card = cards[1]:Clone()
				card.Name = `Card{#cards + 1}`
				card.Parent = scroller
				table.insert(cards, card)
				wireCard(card)
			end
		end
		for index, card in cards do
			local id = ids[index]
			card.Visible = id ~= nil
			if not id then
				continue
			end
			local pick = Catalog.Get(id)
			if not pick then
				continue
			end
			card:SetAttribute("PickId", id)
			card.LayoutOrder = index
			Elements.Pair(card, "Name", pick.Name)
			Elements.Pair(card, "Odds", "1 IN " .. NumberFormat.Compact(pick.OneIn))
			Elements.Pair(card, "Finish", "NORMAL")
			Elements.Pair(card, "Zone.Count", "x" .. tostring(data.Inventory[id]))
			Elements.PickArt(card, "Zone.Art", id)
			Elements.Visible(card, "Zone.InRing", table.find(data.Loadout, id) ~= nil)
		end
		for slot = 1, 15 do
			local prefix = body .. "LeftCol.Ring.Slot" .. slot
			local id = data.Loadout[slot]
			Elements.Visible(gui, prefix, slot <= Config.MaxSlots)
			Elements.Visible(gui, prefix .. ".Filled", id ~= nil)
			Elements.Visible(gui, prefix .. ".Empty", id == nil)
			if id then
				Elements.PickArt(gui, prefix .. ".Filled.Art", id)
			end
		end
		local cost = Config.SlotCosts[data.Slots]
		Elements.Pair(
			gui,
			body .. "LeftCol.NextSlot.Content.Heading",
			if data.Slots < Config.MaxSlots then `NEXT SLOT {data.Slots + 1}` else "ALL SLOTS UNLOCKED"
		)
		Elements.Pair(
			gui,
			body .. "LeftCol.NextSlot.Content.Buy.Body.Content.Caption",
			if cost then "$" .. NumberFormat.Compact(cost) else "MAX"
		)
		Elements.Pair(
			gui,
			body .. "LeftCol.Actions.AutoEquip.Body.Content.Caption",
			if data.AutoEquipBest then "AUTO ON" else "AUTO OFF"
		)
	end
	return screen
end

return Loadout
