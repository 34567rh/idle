--!strict

local Harness = require("./Harness")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local fs = require("@lune/fs")
local harness = Harness.New()
local load = harness.Load
local storage = harness.Place.ReplicatedStorage
local dataFolder = harness.Place.ServerScriptService.Data
local PlayerData = load(dataFolder.PlayerData)
local Progression = load(dataFolder.Progression)
local Config = load(storage.Config.GameConfig)
local Upgrades = load(storage.Config.Upgrades)
local Catalog = load(storage.Utils.Catalog)
local passed = 0
local function test(name, callback)
	local ok, message = pcall(callback)
	assert(ok, `{name}: {message}`)
	passed += 1
	print(`PASS {name}`)
end
local function fresh()
	return PlayerData.Clone(PlayerData.Template)
end

test("Recovered catalogue has 200 distinct picks with art and valid damage", function()
	assert(#Catalog.All == 200)
	local seen = {}
	for _, pick in Catalog.All do
		assert(not seen[pick.Id] and pick.BaseDamage > 0 and pick.OneIn >= 1)
		assert(Catalog.GetImage(pick.Id) ~= "")
		seen[pick.Id] = true
	end
end)

test("First roll gives Coal and auto-equips it without changing another profile", function()
	local first, other = fresh(), fresh()
	assert(Progression.Roll(first, 0.7) == "Coal")
	assert(first.Rolls == 1 and first.Inventory.Coal == 1 and first.Loadout[1] == "Coal")
	assert(other.Inventory.Coal == nil and other.Loadout[1] == "Wooden")
	assert(PlayerData.Validate(first))
end)

test("Roll sampling stays within the catalogue and respects copy caps", function()
	local data = fresh()
	for index = 0, 999 do
		local id = Progression.Roll(data, index / 1000)
		assert(Catalog.Get(id) and data.Inventory[id] > 0)
	end
	assert(data.Rolls == 1000 and PlayerData.Validate(data))
	local invalid = pcall(Progression.Roll, data, 0 / 0)
	assert(not invalid)
end)

test("Upgrade purchases charge once, reject unknown ids, and stop at max level", function()
	local data = fresh()
	local upgrade = Upgrades.All[1]
	local cost = Progression.GetUpgradeCost(data, upgrade.Id)
	assert(not Progression.BuyUpgrade(data, upgrade.Id))
	assert(data.Cash == 0 and data.Upgrades[upgrade.Id] == 0)
	data.Cash = cost
	assert(Progression.BuyUpgrade(data, upgrade.Id))
	assert(data.Cash == 0 and data.Upgrades[upgrade.Id] == 1)
	assert(not Progression.BuyUpgrade(data, "Unknown"))
	data.Upgrades[upgrade.Id] = upgrade.MaxLevel
	assert(not Progression.BuyUpgrade(data, upgrade.Id))
end)

test("Loadouts reject unowned picks, fractional slots, duplicate copies, and locked slots", function()
	local data = fresh()
	assert(not Progression.Equip(data, "Coal", 1))
	assert(not Progression.Equip(data, "Wooden", 1.5))
	assert(not Progression.Equip(data, "Wooden", math.huge))
	assert(not Progression.Equip(data, "Wooden", 0 / 0))
	assert(not Progression.Equip(data, "Wooden", 2))
	data.Slots = 2
	assert(not Progression.Equip(data, "Wooden", 2))
	data.Inventory.Wooden = 2
	assert(Progression.Equip(data, "Wooden", 2))
	assert(PlayerData.Validate(data))
end)

test("EquipBest fills slots with owned copies ordered by damage", function()
	local data = fresh()
	data.Slots = 3
	data.Inventory.Coal = 2
	Progression.EquipBest(data)
	assert(table.concat(data.Loadout, ",") == "Coal,Coal,Wooden")
end)

test("Slots use server costs and stop at the configured cap", function()
	local data = fresh()
	assert(not Progression.BuySlot(data))
	for slot = 1, Config.MaxSlots - 1 do
		data.Cash = Config.SlotCosts[slot]
		assert(Progression.BuySlot(data) and data.Cash == 0 and data.Slots == slot + 1)
	end
	assert(not Progression.BuySlot(data))
	assert(PlayerData.Validate(data))
end)

test("Mining awards currency, advances levels, and caps balances", function()
	local data = fresh()
	for _ = 1, Config.BlocksPerLevel do
		Progression.AwardBlock(data, 10)
	end
	assert(data.Level == 2 and data.Cash == 10 * Config.BlocksPerLevel)
	data.Cash = Config.MaxCash - 1
	assert(Progression.AwardBlock(data, 100) == 1 and data.Cash == Config.MaxCash)
	assert(not pcall(Progression.AwardBlock, data, -1))
	assert(not pcall(Progression.AwardBlock, data, math.huge))
	assert(PlayerData.Validate(data))
end)

test("Rebirth gates progression, resets the run, and preserves picks and slots", function()
	local data = fresh()
	assert(not Progression.Rebirth(data))
	data.Level = Progression.GetRequiredLevel(data)
	data.Cash = 9999
	data.Slots = 2
	data.Inventory.Coal = 2
	data.Upgrades.Luck = 5
	Progression.EquipBest(data)
	assert(Progression.Rebirth(data))
	assert(data.Rebirths == 1 and data.Cash == 0 and data.Level == 1 and data.Upgrades.Luck == 0)
	assert(data.Slots == 2 and data.Inventory.Coal == 2 and data.Loadout[1] == "Coal")
	assert(Progression.GetLuck(data) > 1 and PlayerData.Validate(data))
end)

test("Profile validation rejects corrupt balances and illegal equipment", function()
	for _, value in { -1, math.huge, 0 / 0, 0.5, "100" } do
		local data = fresh()
		data.Cash = value
		assert(not PlayerData.Validate(data))
	end
	local data = fresh()
	data.Loadout[1] = "Coal"
	assert(not PlayerData.Validate(data))
	data = fresh()
	data.Upgrades.Unknown = 1
	assert(not PlayerData.Validate(data))
end)

local DataSessions = load(dataFolder.DataSessions)
local function sessionFixture()
	local profile = {
		Data = fresh(),
		LastSavedData = fresh(),
		Active = true,
		Saves = 0,
		Ends = 0,
		OnSessionEnd = Harness.Signal(),
		OnSave = Harness.Signal(),
	}
	function profile:IsActive()
		return self.Active
	end
	function profile:AddUserId(id)
		self.UserId = id
	end
	function profile:Reconcile() end
	function profile:EndSession()
		self.Active = false
		self.Ends += 1
		self.OnSessionEnd:Fire()
	end
	function profile:Save()
		self.OnSave:Fire()
		self.LastSavedData = PlayerData.Clone(self.Data)
		self.Saves += 1
	end
	local player = { UserId = 123, Present = true, Kicks = {} }
	function player:Kick(message)
		table.insert(self.Kicks, message)
	end
	local store = { Calls = 0 }
	function store:StartSessionAsync(key, options)
		self.Calls += 1
		self.Key = key
		self.Cancel = options.Cancel
		return profile
	end
	local sessions = DataSessions.new(store, function(candidate)
		return candidate.Present
	end)
	return sessions, player, profile, store
end

test("Data session loads once, saves timestamps, and releases without kicking", function()
	local sessions, player, profile, store = sessionFixture()
	sessions:Load(player)
	sessions:Load(player)
	assert(store.Calls == 1 and store.Key == "Player_123" and profile.UserId == 123)
	assert(sessions:RequestSave(player) and profile.Data.LastSeenAt > 0 and profile.Saves == 1)
	assert(sessions:WaitForSave(player, function(data)
		return data.LastSeenAt > 0
	end))
	sessions:Release(player)
	assert(profile.Ends == 1 and sessions:GetData(player) == nil and #player.Kicks == 0)
end)

test("Lost session prevents access and kicks; corrupt saves are preserved", function()
	local sessions, player, profile = sessionFixture()
	sessions:Load(player)
	profile:EndSession()
	assert(sessions:GetData(player) == nil and #player.Kicks == 1)
	local invalidSessions, invalidPlayer, invalidProfile = sessionFixture()
	invalidProfile.Data.Cash = -1
	invalidSessions:Load(invalidPlayer)
	assert(invalidProfile.Data.Cash == -1 and invalidProfile.Ends == 1 and #invalidPlayer.Kicks == 1)
end)

test("A player leaving during load releases the profile; shutdown cancels new loads", function()
	local sessions, player, profile, store = sessionFixture()
	function store:StartSessionAsync(_, options)
		player.Present = false
		assert(options.Cancel())
		return profile
	end
	sessions:Load(player)
	assert(profile.Ends == 1 and sessions:GetData(player) == nil)
	sessions:Destroy()
	player.Present = true
	sessions:Load(player)
	assert(profile.Ends == 1)
end)

test("Lifecycle starts in order and cleans up in reverse even after a failure", function()
	local Lifecycle = load(storage.Lifecycle)
	local trace = {}
	local function system(name, fail)
		return {
			Name = name,
			Init = function()
				table.insert(trace, name .. "I")
			end,
			Start = function()
				table.insert(trace, name .. "S")
				if fail then
					error("intentional failure")
				end
			end,
			Destroy = function()
				table.insert(trace, name .. "D")
			end,
		}
	end
	local lifecycle = Lifecycle.new({ system("A"), system("B") })
	lifecycle:Start()
	lifecycle:Destroy()
	lifecycle:Destroy()
	assert(table.concat(trace, ",") == "AI,BI,AS,BS,BD,AD")
	assert(not pcall(lifecycle.Start, lifecycle))
	table.clear(trace)
	assert(not pcall(function()
		Lifecycle.new({ system("A"), system("B", true) }):Start()
	end))
	assert(table.concat(trace, ",") == "AI,BI,AS,BS,BD,AD")
end)

test("Rate limits isolate players and reject burst spam", function()
	local RateLimit = load(storage.Utils.RateLimit)
	local limiter = RateLimit.new(2, 100)
	assert(limiter:Allow("A") and limiter:Allow("A") and not limiter:Allow("A"))
	assert(limiter:Allow("B"))
	limiter:Remove("A")
	assert(limiter:Allow("A"))
end)

test("Mine builder preserves ore art and isolates zones; orbit geometry matches cells", function()
	local mine = harness.Place.ServerScriptService.Services.MineService
	local Builder = load(mine.Builder)
	local Mining = load(mine.Mining)
	local parent = roblox.Instance.new("Folder")
	local first = Builder.Create(parent, { UserId = 1 }, 1)
	local second = Builder.Create(parent, { UserId = 2 }, 2)
	assert(first.Centre ~= second.Centre)
	assert(first.Folder:GetAttribute(load(storage.Config.Constants).ZONE_OWNER_ATTRIBUTE) == 1)
	assert((second.Centre - first.Centre).Magnitude >= Config.FloorSize)
	local random = {
		NextInteger = function(_, minimum)
			return minimum
		end,
	}
	Builder.Fill(first, 1, random)
	assert(first.Remaining == Config.MineColumns * Config.MineRows - 9)
	local position = Mining.GetPickPosition(roblox.Vector3.zero, 0, 0.55, 1, 1)
	assert(position.X == 6 and position.Y > 0 and position.Z == 0)
	local owned = fresh()
	owned.Inventory.Coal = 1
	owned.Loadout = { "Coal" }
	local body = {
		CFrame = roblox.CFrame.new(),
		IsA = function()
			return true
		end,
	}
	local character = {
		FindFirstChild = function()
			return body
		end,
		FindFirstChildOfClass = function()
			return { Health = 100 }
		end,
	}
	roblox.implementMethod("Workspace", "GetServerTimeNow", function()
		return 0
	end)
	local result, broken = Mining.Step(first, { Character = character }, owned, 1)
	assert(result and broken == 1 and result.Cash > owned.Cash and owned.Cash == 0)
	assert(second.Remaining == 0)
	assert(select(2, Mining.Step(first, { Character = character }, owned, 1)) == 0)
end)

test("Idle movement stands within orbit reach even when the last rock is beneath the player", function()
	local Mining = load(harness.Place.ServerScriptService.Services.MineService.Mining)
	local destination
	local position = roblox.Vector3.new(10, 3, 10)
	local root = {
		CFrame = roblox.CFrame.new(position),
		IsA = function()
			return true
		end,
	}
	local humanoid = {
		MoveTo = function(_, target)
			destination = target
		end,
	}
	local character = {
		FindFirstChild = function()
			return root
		end,
		FindFirstChildOfClass = function()
			return humanoid
		end,
	}
	local zone =
		{ Centre = roblox.Vector3.zero, Rocks = { { Part = { CFrame = roblox.CFrame.new(position) } } } }
	Mining.MoveIdle(zone, { Character = character })
	assert(
		destination
			and roblox.Vector2.new(destination.X - position.X, destination.Z - position.Z).Magnitude == 6
	)
end)

test("Server rolls enforce cooldowns and commit profile and replica together", function()
	local GameService = load(harness.Place.ServerScriptService.Services.GameService)
	local current = fresh()
	local replica = {
		Data = current,
		SetValues = function(self, _, values)
			for key, value in values do
				self.Data[key] = value
			end
		end,
	}
	local services = {
		DataService = {
			GetData = function()
				return current
			end,
			GetReplica = function()
				return replica
			end,
		},
	}
	GameService:Init(services)
	local player = {}
	assert(GameService:Roll(player, 100))
	assert(current.Rolls == 1 and current.Inventory.Coal == 1)
	assert(not GameService:Roll(player, 100.01))
	assert(current.Rolls == 1)
	assert(GameService:Roll(player, 100 + Progression.GetRollInterval(current)))
	assert(current.Rolls == 2 and #harness.Packets.RollResult.Calls == 2)
end)

test("Server actions validate inputs and consume an offline claim only once", function()
	local Actions = load(harness.Place.ServerScriptService.Services.GameService.Actions)
	local current = fresh()
	current.OfflineCash = 100
	local services = {
		DataService = {
			GetData = function()
				return current
			end,
		},
		GameService = {
			Commit = function(_, _, data)
				assert(PlayerData.Validate(data))
				current = data
				return true
			end,
		},
		MineService = { Reset = function() end },
	}
	assert(not Actions.Apply(services, {}, "SetIdle", "true"))
	assert(not Actions.Apply(services, {}, "Equip", "Divine", 1))
	assert(Actions.Apply(services, {}, "ClaimOffline"))
	assert(current.Cash == 100 and current.OfflineCash == 0)
	assert(not Actions.Apply(services, {}, "ClaimOffline"))
	assert(current.Cash == 100)
end)

test("All eight screens bind existing authored buttons and update real saved GUI assets", function()
	local uiController = harness.Place.StarterPlayer.StarterPlayerScripts.Controllers.UIController
	local Elements = load(uiController.Elements)
	local ui = storage.UITemplates
	local data = fresh()
	data.Inventory.Coal = 1
	local context = {
		Controllers = { DataController = {
			Get = function()
				return data
			end,
		} },
		Open = function() end,
		Close = function() end,
		Notify = function() end,
	}
	local paths = {
		Hud = "HUD",
		Roller = "Frames.Roller",
		Loadout = "Frames.Loadout",
		Upgrades = "Frames.UpgradeTree",
		Rebirth = "Frames.Rebirth",
		Settings = "Frames.Settings",
		Collection = "Frames.Index",
		OfflineClaim = "Frames.OfflineClaim",
	}
	local screens = {}
	for name, path in paths do
		local screen = load(uiController.Screens[name]).new(context, Elements.Get(ui, path))
		screens[name] = screen
		screen:Open()
		screen:Update(data)
		screen:Close()
	end
	assert(Elements.Get(ui, "HUD.Stage.Money.Amount").Text == "$0")
	local count =
		Elements.Get(ui, "Frames.Index.Main.Box.Content.Body.Content.Main.Progress.Content.Pickaxes.Found")
	assert(count.Text == "2")
	local roll = Elements.Get(ui, "HUD.Stage.ThumbRow.Roller")
	roll.Activated:Fire()
	assert(#harness.Packets.Roll.Calls == 1)
	assert(#harness.Warnings == 1, table.concat(harness.Warnings, "\n"))
	assert(string.find(harness.Warnings[1], "Unsupported or invalid data", 1, true))
	for _, screen in screens do
		screen:Destroy()
	end
end)

fs.writeFile(
	"build/test-results.json",
	serde.encode("json", { Passed = passed, Failed = 0, EnginePlaytests = 0 }, true)
)
print(`{passed} recovery tests passed; Roblox engine playtests still required.`)
