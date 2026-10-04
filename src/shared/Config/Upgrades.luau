--!strict

export type Upgrade = {
	Id: string,
	Name: string,
	ShortName: string,
	BaseCost: number,
	CostGrowth: number,
	MaxLevel: number,
	Node: number,
}

local upgrades: { Upgrade } = {
	{
		Id = "OrbitSpeed",
		Name = "Orbit Speed",
		ShortName = "ORBIT",
		BaseCost = 100,
		CostGrowth = 1.18,
		MaxLevel = 50,
		Node = 2,
	},
	{
		Id = "WalkSpeed",
		Name = "Movement Speed",
		ShortName = "MOVE",
		BaseCost = 300,
		CostGrowth = 1.18,
		MaxLevel = 25,
		Node = 5,
	},
	{
		Id = "MoneyMultiplier",
		Name = "Money Multiplier",
		ShortName = "MONEY",
		BaseCost = 500,
		CostGrowth = 1.18,
		MaxLevel = 50,
		Node = 4,
	},
	{
		Id = "Luck",
		Name = "Luck",
		ShortName = "LUCK",
		BaseCost = 100000,
		CostGrowth = 1.3,
		MaxLevel = 50,
		Node = 3,
	},
	{
		Id = "RollSpeed",
		Name = "Roll Speed",
		ShortName = "ROLL",
		BaseCost = 2500,
		CostGrowth = 1.18,
		MaxLevel = 50,
		Node = 8,
	},
	{
		Id = "Haul",
		Name = "Mine Clear Bonus",
		ShortName = "HAUL",
		BaseCost = 1000,
		CostGrowth = 1.2,
		MaxLevel = 50,
		Node = 22,
	},
}

local byId: { [string]: Upgrade } = {}
for _, upgrade in upgrades do
	byId[upgrade.Id] = table.freeze(upgrade)
end

return table.freeze({ All = table.freeze(upgrades), ById = table.freeze(byId) })
