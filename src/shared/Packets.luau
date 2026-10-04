--!strict

local Packet = require(script.Parent.Packet)

return table.freeze({
	Roll = Packet("RecoveryRoll"):RateLimit(2, 1),
	EquipBest = Packet("RecoveryEquipBest"):RateLimit(3, 1),
	Equip = Packet("RecoveryEquip", Packet.String, Packet.NumberU8):RateLimit(5, 1),
	BuyUpgrade = Packet("RecoveryBuyUpgrade", Packet.String):RateLimit(5, 1),
	BuyAll = Packet("RecoveryBuyAll"):RateLimit(1, 1),
	BuySlot = Packet("RecoveryBuySlot"):RateLimit(2, 1),
	Rebirth = Packet("RecoveryRebirth"):RateLimit(1, 2),
	SetAutoRoll = Packet("RecoverySetAutoRoll", Packet.Boolean8):RateLimit(2, 1),
	SetAutoEquip = Packet("RecoverySetAutoEquip", Packet.Boolean8):RateLimit(2, 1),
	SetIdle = Packet("RecoverySetIdle", Packet.Boolean8):RateLimit(2, 1),
	ClaimOffline = Packet("RecoveryClaimOffline"):RateLimit(1, 2),
	Notice = Packet("RecoveryNotice", Packet.String),
	RollResult = Packet("RecoveryRollResult", Packet.String),
})
