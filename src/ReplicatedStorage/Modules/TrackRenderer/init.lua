--!strict

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
		TrackModel = nil,
		TrackLength = 100,
		SeperateActor = false,
	}
end

function module.new(track_settings: TypeDef.TrackSettings, Wheels: {BasePart})
	local actortouse = Actor

	if track_settings.SeperateActor then
		actortouse = Actor:Clone()
		actortouse.Parent = Folder
	end

	local object = {
		IsActive = false,
		Speed = 0,
		ID = uid(),
		trackActor = actortouse,
	}
	actortouse.Name = "Track"
	task.spawn(function()
		task.wait()
		object.trackActor:SendMessage("Init", object.ID, track_settings, Wheels)
	end)

	setmetatable(object, module)
	return object
end

function module:UpdatePool_PrivateFunction()
	self.trackActor:SendMessage("change", self.ID, {Speed = self.Speed, IsActive = self.IsActive})
end

function module:SetSpeed(number)
	self.Speed = number
	self:UpdatePool_PrivateFunction()
end

function module:Render()
	self.IsActive = true
	self:UpdatePool_PrivateFunction()
end

function module:StopRendering()
	self.IsActive = false
	self:UpdatePool_PrivateFunction()
end

function module:Destroy()
	self.trackActor:SendMessage("destroying", self.ID)
end



return module
