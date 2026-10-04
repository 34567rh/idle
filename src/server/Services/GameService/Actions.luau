--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Packets)
local Upgrades = require(ReplicatedStorage.Config.Upgrades)
local Config = require(ReplicatedStorage.Config.GameConfig)
local Progression = require(script.Parent.Parent.Parent.Data.Progression)
local PlayerData = require(script.Parent.Parent.Parent.Data.PlayerData)

local Actions = {}

local function apply(data: PlayerData.Data, action: string, first: any, second: any): (boolean, string)
	if action == "BuyUpgrade" then
		if type(first) ~= "string" or #first > 64 then
			return false, "Invalid upgrade."
		end
		return Progression.BuyUpgrade(data, first)
	elseif action == "BuyAll" then
		local bought = 0
		for _ = 1, 50 do
			local changed = false
			for _, upgrade in Upgrades.All do
				if Progression.BuyUpgrade(data, upgrade.Id) then
					changed = true
					bought += 1
				end
			end
			if not changed then
				break
			end
		end
		return bought > 0, if bought > 0 then `{bought} upgrades purchased!` else "No affordable upgrades."
	elseif action == "BuySlot" then
		return Progression.BuySlot(data)
	elseif action == "EquipBest" then
		Progression.EquipBest(data)
		return true, "Your best pickaxes are equipped."
	elseif action == "Equip" then
		if type(first) ~= "string" or #first > 80 or type(second) ~= "number" then
			return false, "Invalid pickaxe or slot."
		end
		return Progression.Equip(data, first, second)
	elseif action == "Rebirth" then
		return Progression.Rebirth(data)
	elseif action == "ClaimOffline" then
		if data.OfflineCash <= 0 then
			return false, "No offline coins to claim."
		end
		data.Cash = math.min(Config.MaxCash, data.Cash + data.OfflineCash)
		data.OfflineCash = 0
		return true, "Offline coins claimed!"
	elseif action == "SetAutoRoll" or action == "SetAutoEquip" or action == "SetIdle" then
		if type(first) ~= "boolean" then
			return false, "Invalid setting."
		end
		if action == "SetAutoRoll" then
			data.AutoRoll = first
		elseif action == "SetAutoEquip" then
			data.AutoEquipBest = first
			if first then
				Progression.EquipBest(data)
			end
		else
			data.Idle = first
		end
		return true, if first then "Enabled." else "Disabled."
	end
	return false, "Unknown action."
end

function Actions.Apply(
	services: { [string]: any },
	player: Player,
	action: string,
	first: any,
	second: any
): (boolean, string)
	local current = services.DataService:GetData(player)
	if not current then
		return false, "Your data is still loading."
	end
	local data = PlayerData.Clone(current)
	local success, message = apply(data, action, first, second)
	if success then
		if not services.GameService:Commit(player, data) then
			return false, "Your data session is unavailable. Please rejoin."
		end
		if action == "Rebirth" then
			services.MineService:Reset(player)
		end
	end
	return success, message
end

function Actions.Notify(player: Player, message: string)
	Packets.Notice:FireClient(player, message)
end

return Actions
