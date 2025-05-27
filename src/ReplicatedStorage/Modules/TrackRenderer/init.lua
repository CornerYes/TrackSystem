--!strict

local TypeDef = require(script.TypeDefinitions)
local module = {}
module.__index = module

local uidcount = 0
local Actor = script.PoolActor
Actor.Parent = game.ReplicatedFirst

local function uid()
	uidcount += 1
	return "track_" .. tostring(uidcount)
end
function module.newsettings(): TypeDef.TrackSettings
	return {
		TrackModel = "",
		Trackpath = nil,
		TrackLength = 100,
	}
end

function module.new(track_settings: TypeDef.TrackSettings, Wheels: {BasePart})
	local object = {
		IsActive = false,
		Speed = 0,
		ID = uid(),
	}
	
	Actor:SendMessage("Init", object.ID, track_settings, Wheels)
	setmetatable(object, module)
	return object
end

function module:UpdatePool_PrivateFunction()
	Actor:SendMessage("change", self.ID, {Speed = self.Speed, IsActive = self.IsActive})
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
	Actor:SendMessage("destroying", self.ID)
end

return module
