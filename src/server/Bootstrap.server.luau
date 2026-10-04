--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lifecycle = require(ReplicatedStorage.Lifecycle)
local Packets = require(ReplicatedStorage.Packets)
local systems = require(script.Parent.Registry)
local runtime = Lifecycle.new(systems)

assert(Packets.Roll ~= nil)
game:BindToClose(function()
	runtime:Destroy()
end)
runtime:Start()
script:SetAttribute("Ready", true)
print("[The Idle Mines] Server services ready")
