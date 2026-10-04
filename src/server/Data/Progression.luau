--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Config.GameConfig)
local Constants = require(ReplicatedStorage.Config.Constants)
local Upgrades = require(ReplicatedStorage.Config.Upgrades)
local Catalog = require(ReplicatedStorage.Utils.Catalog)
local PlayerData = require(script.Parent.PlayerData)

local Progression = {}

function Progression.GetLuck(data: PlayerData.Data): number
	return math.min(
		Constants.LUCK_CAP,
		Constants.LUCK_PER_LEVEL ^ data.Upgrades.Luck * Constants.LUCK_PER_REBIRTH ^ data.Rebirths
	)
end

function Progression.GetRollInterval(data: PlayerData.Data): number
	return math.max(
		Constants.ROLL_MIN_SPIN,
		Constants.ROLL_BASE_SPIN - Constants.ROLL_SPIN_PER_LEVEL * data.Upgrades.RollSpeed
	) + Constants.ROLL_REST_SECONDS
end

function Progression.GetOrbitSpeed(data: PlayerData.Data): number
	return math.min(
		Constants.ORBIT_MAX_SPEED,
		Constants.ORBIT_BASE_SPEED + Constants.ORBIT_SPEED_PER_LEVEL * data.Upgrades.OrbitSpeed
	)
end

function Progression.GetWalkSpeed(data: PlayerData.Data): number
	return math.min(
		Constants.WALK_MAX_SPEED,
		Constants.WALK_BASE_SPEED + Constants.WALK_SPEED_PER_LEVEL * data.Upgrades.WalkSpeed
	)
end

function Progression.GetRequiredLevel(data: PlayerData.Data): number
	return Constants.REBIRTH_BASE_LEVEL + Constants.REBIRTH_LEVEL_STEP * data.Rebirths
end

function Progression.GetUpgradeCost(data: PlayerData.Data, id: string): number?
	local upgrade = Upgrades.ById[id]
	if not upgrade or data.Upgrades[id] >= upgrade.MaxLevel then
		return nil
	end
	return math.min(Config.MaxCash, math.ceil(upgrade.BaseCost * upgrade.CostGrowth ^ data.Upgrades[id]))
end

function Progression.BuyUpgrade(data: PlayerData.Data, id: string): (boolean, string)
	local cost = Progression.GetUpgradeCost(data, id)
	if not cost then
		return false, "That upgrade is unavailable or already maxed."
	end
	if data.Cash < cost then
		return false, "Mine more coins to buy this upgrade."
	end
	data.Cash -= cost
	data.Upgrades[id] += 1
	return true, "Upgrade purchased!"
end

function Progression.BuySlot(data: PlayerData.Data): (boolean, string)
	local cost = Config.SlotCosts[data.Slots]
	if data.Slots >= Config.MaxSlots or not cost then
		return false, "All mine-earned slots are unlocked."
	end
	if data.Cash < cost then
		return false, "Mine more coins to unlock another slot."
	end
	data.Cash -= cost
	data.Slots += 1
	Progression.EquipBest(data)
	return true, "New pickaxe slot unlocked!"
end

function Progression.EquipBest(data: PlayerData.Data)
	local owned: { { Id: string, Copies: number } } = {}
	for id, copies in data.Inventory do
		table.insert(owned, { Id = id, Copies = copies })
	end
	table.sort(owned, function(left, right)
		local leftDamage, rightDamage = Catalog.GetDamage(left.Id), Catalog.GetDamage(right.Id)
		return if leftDamage == rightDamage then left.Id < right.Id else leftDamage > rightDamage
	end)
	local loadout: { string } = {}
	for _, item in owned do
		for _ = 1, math.min(item.Copies, data.Slots - #loadout) do
			table.insert(loadout, item.Id)
		end
		if #loadout == data.Slots then
			break
		end
	end
	data.Loadout = loadout
end

function Progression.Equip(data: PlayerData.Data, id: string, slot: number): (boolean, string)
	if not Catalog.Get(id) or not data.Inventory[id] then
		return false, "You do not own that pickaxe."
	end
	if slot ~= slot or slot % 1 ~= 0 or slot < 1 or slot > data.Slots or slot > #data.Loadout + 1 then
		return false, "Choose an unlocked slot."
	end
	local used = 0
	for index, equippedId in data.Loadout do
		if index ~= slot and equippedId == id then
			used += 1
		end
	end
	if used >= data.Inventory[id] then
		return false, "All copies of that pickaxe are already equipped."
	end
	data.Loadout[slot] = id
	return true, "Pickaxe equipped!"
end

function Progression.Roll(data: PlayerData.Data, sample: number): string
	assert(sample >= 0 and sample < 1, "Roll sample must be in [0, 1)")
	local pickId = Constants.FIRST_ROLL_PICKAXE_ID
	if data.Rolls > 0 then
		local luck = Progression.GetLuck(data)
		local total = 0
		local weights: { number } = {}
		for index, pick in Catalog.Rollable do
			local odds = if pick.OneIn >= Constants.LUCK_THRESHOLD_ONE_IN
				then math.max(Constants.LUCK_FLOOR_ONE_IN, pick.OneIn / luck)
				else pick.OneIn
			weights[index] = 1 / odds
			total += weights[index]
		end
		local cursor = sample * total
		pickId = Catalog.Rollable[#Catalog.Rollable].Id
		for index, pick in Catalog.Rollable do
			cursor -= weights[index]
			if cursor < 0 then
				pickId = pick.Id
				break
			end
		end
	end
	data.Inventory[pickId] = math.min(Config.MaxInventoryCopies, (data.Inventory[pickId] or 0) + 1)
	data.Rolls += 1
	if data.AutoEquipBest then
		Progression.EquipBest(data)
	end
	return pickId
end

function Progression.AwardBlock(data: PlayerData.Data, value: number): number
	assert(value >= 0 and value < math.huge and value == value, "Invalid ore reward")
	local reward = math.floor(value * (1 + Constants.MONEY_PER_LEVEL * data.Upgrades.MoneyMultiplier))
	local previousCash = data.Cash
	data.Cash = math.min(Config.MaxCash, data.Cash + reward)
	data.BlocksBroken += 1
	data.BlocksThisRun += 1
	data.Level = math.min(Config.MaxMineLevel, 1 + math.floor(data.BlocksThisRun / Config.BlocksPerLevel))
	return data.Cash - previousCash
end

function Progression.Rebirth(data: PlayerData.Data): (boolean, string)
	if data.Level < Progression.GetRequiredLevel(data) then
		return false, `Reach level {Progression.GetRequiredLevel(data)} to rebirth.`
	end
	if data.Rebirths >= 100000 then
		return false, "Rebirth limit reached."
	end
	data.Rebirths += 1
	data.Cash = 0
	data.Level = 1
	data.BlocksThisRun = 0
	for _, upgrade in Upgrades.All do
		data.Upgrades[upgrade.Id] = 0
	end
	return true, "Reborn! Your pickaxes and slots are kept; luck is permanently stronger."
end

return Progression
