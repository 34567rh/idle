--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lifecycle = require(ReplicatedStorage.Lifecycle)

local systems: { Lifecycle.System } = {
	require(script.Parent.Controllers.DataController),
	require(script.Parent.Controllers.OrbitController),
	require(script.Parent.Controllers.UIController),
}

return systems
