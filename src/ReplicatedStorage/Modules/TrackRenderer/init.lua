--!strict
local version = "1.0.2"
local OrigActor = script.TrackActor

local TypeDef = require(OrigActor.Main.TypeDefinitions)
local track = require(OrigActor.Main)

local module = {}
module.__index = module

local uidcount = 0

local Folder = Instance.new("Folder")
Folder.Name = "TrackRenders"
Folder.Parent = game.ReplicatedFirst

local function uid()
	uidcount += 1
	return "track_" .. tostring(uidcount)
end

function module.newsettings(): TypeDef.TrackSettings
	return {
		TrackModel = nil,
		TrackLength = 100,
		ParallelLua = false,
		LowDetailPartWidth = 1,
		LowDetailPartHeight = 1,
		MiddleTrack = nil,
	}
end

function module.new(track_settings: TypeDef.TrackSettings, Wheels: { Instance })
	local actortouse = nil
	local trackclass = nil

	if track_settings.ParallelLua then
		actortouse = OrigActor:Clone()
		actortouse.Parent = Folder
	else
		trackclass = track.new(track_settings)
	end

	local object = {
		IsActive = false,
		Speed = 0,
		LODDistance = 100,
		ID = uid(),
		actor = actortouse,
		event = nil,
		track = trackclass,
		Wheels = Wheels,
	}

	task.spawn(function()
		if actortouse then
			task.wait(0.1)
			object.actor:SendMessage("Init", object.ID, track_settings, Wheels)
		else
			object.track:Init(Wheels)
			object.event = game:GetService("RunService").RenderStepped:Connect(function(dt)
				object.track:update(dt, false)
			end)
		end
	end)

	setmetatable(object, module)
	return object
end

function module:UpdatePool_PrivateFunction(data)
	if self.actor then
		self.actor:SendMessage("change", self.ID, data)
	else
		self.track:dataupdate(data)
	end
end

function module:SetSpeed(number)
	self.Speed = number
	self:UpdatePool_PrivateFunction({ Speed = number })
end

function module:SetLODDistance(number)
	self.LODDistance = number
	self:UpdatePool_PrivateFunction({ LODDistance = number })
end

function module:Render()
	self.IsActive = true
	self:UpdatePool_PrivateFunction({ IsActive = true })
end

function module:StopRendering()
	self.IsActive = false
	self:UpdatePool_PrivateFunction({ IsActive = false })
end

function module:Destroy()
	if self.actor then
		self.actor:SendMessage("destroying", self.ID)
	else
		if self.event then
			self.event:Disconnect()
			self.event = nil :: any
		end
		self.track:destroy()
	end
end

function module.version()
	return version
end

return module
