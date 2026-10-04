--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lifecycle = require(ReplicatedStorage:WaitForChild("Lifecycle"))
local systems = require(script.Parent.Registry)
local runtime = Lifecycle.new(systems)

script.Destroying:Connect(function()
	runtime:Destroy()
end)
runtime:Start()
script:SetAttribute("Ready", true)
print("[The Idle Mines] Client controllers ready")
