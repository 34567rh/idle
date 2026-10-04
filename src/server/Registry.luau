--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lifecycle = require(ReplicatedStorage.Lifecycle)

local systems: { Lifecycle.System } = {
	require(script.Parent.Services.DataService),
	require(script.Parent.Services.MineService),
	require(script.Parent.Services.GameService),
}

return systems
