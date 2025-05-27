
--!strict
local TypeDef = require(game.ReplicatedStorage.Modules.TrackRenderer.TypeDefinitions)
local Actor = script.Parent
local trackclass = {}
local activetracks = {}
trackclass.__index = trackclass

function trackclass.new(track_settings: TypeDef.TrackSettings)
	local object = {
		IsActive = false,
		Speed = 0,
		track_settings = track_settings,
		variables = {
			Wheels = {},  
			Points = {},
		}
	}
	setmetatable(object, trackclass)
	return object
end

function trackclass:Init(WheelParts: {BasePart})
	for i, v in ipairs(WheelParts) do
		local Names = v.Name:split("_")
		self.variables.Wheels[Names[1]] = v
	end
end

function trackclass:update(dt)
	print("hello")
end

function trackclass:destroying()
	
end

Actor:BindToMessage("Init", function(ID, track_settings: TypeDef.TrackSettings, Wheels)
	local track = trackclass.new(track_settings)
	activetracks[ID] = track
	track:Init(Wheels)
end)

Actor:BindToMessage("change", function(ID, newdata: {IsActive: boolean, Speed: number})
	local track = activetracks[ID]
	track.Speed = newdata.Speed
	track.IsActive = newdata.IsActive
end)

Actor:BindToMessage("destroying", function(ID)
	
end)

game:GetService("RunService").RenderStepped:Connect(function(dt)
	for _, track in pairs(activetracks) do
		track:update(dt)
	end
end)

