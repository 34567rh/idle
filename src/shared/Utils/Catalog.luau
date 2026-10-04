--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PickaxeCatalog = require(ReplicatedStorage.Config.PickaxeCatalog)
local PickaxeImages = require(ReplicatedStorage.Config.PickaxeImages)

export type Pickaxe = {
	Id: string,
	Name: string,
	Tier: string,
	OneIn: number,
	BaseDamage: number,
	Art: string,
	Hidden: boolean?,
}

local Catalog = {}
local byId: { [string]: Pickaxe } = {}
local rollable: { Pickaxe } = {}
local tierColours: { [string]: string } = {}

for _, tier in PickaxeCatalog.Tiers do
	tierColours[tier.Key] = tier.Colour
end
for _, pickaxe in PickaxeCatalog.Pickaxes do
	byId[pickaxe.Id] = pickaxe
	if pickaxe.Hidden ~= true then
		table.insert(rollable, pickaxe)
	end
end

Catalog.All = table.freeze(PickaxeCatalog.Pickaxes)
Catalog.Rollable = table.freeze(rollable)

function Catalog.Get(id: string): Pickaxe?
	return byId[id]
end

function Catalog.GetImage(id: string): string
	return (PickaxeImages :: any)[id] or ""
end

function Catalog.GetColour(id: string): Color3
	local pickaxe = byId[id]
	return Color3.fromHex(if pickaxe then tierColours[pickaxe.Tier] or "#FFFFFF" else "#FFFFFF")
end

function Catalog.GetDamage(id: string): number
	local pickaxe = byId[id]
	return if pickaxe then pickaxe.BaseDamage else 0
end

return Catalog
