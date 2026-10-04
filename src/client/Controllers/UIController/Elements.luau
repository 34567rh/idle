--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local Catalog = require(ReplicatedStorage.Utils.Catalog)
local Types = require(script.Parent.Types)

local Elements = {}

function Elements.Get(root: Instance, path: string): Instance?
	local current: Instance? = root
	for _, name in string.split(path, ".") do
		current = if current then current:FindFirstChild(name) else nil
	end
	return current
end

function Elements.Text(root: Instance, path: string, text: string)
	local target = Elements.Get(root, path)
	if target and target:IsA("TextLabel") then
		target.Text = text
	elseif target and target:IsA("TextButton") then
		target.Text = text
	end
end

function Elements.Pair(root: Instance, path: string, text: string)
	Elements.Text(root, path, text)
	Elements.Text(root, path .. "Bg", text)
end

function Elements.Visible(root: Instance, path: string, value: boolean)
	local target = Elements.Get(root, path)
	if target and target:IsA("GuiObject") then
		target.Visible = value
	end
end

function Elements.Bind(screen: Types.Screen, path: string, callback: () -> ())
	local button = Elements.Get(screen.Gui, path)
	if button and button:IsA("GuiButton") then
		button.Active = true
		button.Interactable = true
		screen.Trove:Add(button.Activated:Connect(callback))
	else
		warn(`[UIController] Expected button {screen.Gui:GetFullName()}.{path}`)
	end
end

function Elements.PickArt(root: Instance, path: string, id: string)
	local art = Elements.Get(root, path)
	if not art then
		return
	end
	for _, image in art:GetDescendants() do
		if image:IsA("ImageLabel") then
			if image.Name == "Image" or image.Name == "Shadow" then
				image.Image = Catalog.GetImage(id)
				image.ImageColor3 = if image.Name == "Shadow"
					then Color3.new(0, 0, 0)
					else Color3.new(1, 1, 1)
			elseif image.Name == "Shine" then
				image.Visible = false
			end
		end
	end
end

function Elements.New(context: Types.Context, gui: GuiObject, name: string, modal: boolean): Types.Screen
	local trove = Trove.new()
	local screen: Types.Screen = {
		Gui = gui,
		Modal = modal,
		StartsOpen = not modal,
		Trove = trove,
		Open = function()
			gui.Visible = true
		end,
		Close = function()
			gui.Visible = false
		end,
		Destroy = function()
			trove:Destroy()
		end,
	}
	for _, instance in gui:GetDescendants() do
		if
			instance:IsA("GuiButton")
			and (
				instance.Name == "CloseButton"
				or instance.Name == "Close"
				or (instance.Name == "Scrim" and name ~= "Roller")
			)
		then
			trove:Add(instance.Activated:Connect(function()
				context.Close(name)
			end))
		end
	end
	return screen
end

return Elements
