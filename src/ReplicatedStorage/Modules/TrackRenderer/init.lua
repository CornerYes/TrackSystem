--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TypeDef = require(script.TypeDefinitions)
local module = {}
module.__index = module

local uidcount = 0

local Folder = Instance.new("Folder")
Folder.Name = "TrackRenders"
Folder.Parent = game.ReplicatedFirst

local Actor = script.TrackActor
Actor.Parent = game.ReplicatedFirst

local function uid()
	uidcount += 1
	return "track_" .. tostring(uidcount)
end

function module.newsettings(): TypeDef.TrackSettings
	return {
		TrackModel = ReplicatedStorage.Tracks.Brick,
		TrackLength = 100,
		SeperateActor = false,
		LowDetailPartWidth = 1,
		LowDetailPartHeight = 1,
	}
end

function module.new(track_settings: TypeDef.TrackSettings, Wheels: {Instance})
	local actortouse = Actor

	if track_settings.SeperateActor then
		actortouse = Actor:Clone()
		actortouse.Parent = Folder
	end

	local object = {
		IsActive = false,
		Speed = 0,
		LODDistance = 100,
		ID = uid(),
		trackActor = actortouse,
	}

	task.spawn(function()
		if track_settings.SeperateActor then
			 task.wait()
		end
		object.trackActor:SendMessage("Init", object.ID, track_settings, Wheels)
	end)

	setmetatable(object, module)
	return object
end

function module:UpdatePool_PrivateFunction(data)
	self.trackActor:SendMessage("change", self.ID, data)
end

function module:SetSpeed(number)
	self.Speed = number
	self:UpdatePool_PrivateFunction({Speed = number})
end

function module:SetLODDistance(number)
	self.LODDistance = number
	self:UpdatePool_PrivateFunction({LODDistance = number})
end

function module:Render()
	self.IsActive = true
	self:UpdatePool_PrivateFunction({IsActive = true})
end

function module:StopRendering()
	self.IsActive = false
	self:UpdatePool_PrivateFunction({IsActive = false})
end

function module:Destroy()
	self.trackActor:SendMessage("destroying", self.ID)
end

return module
