--!strict
local TypeDefinitions = require(script.Parent.Main.TypeDefinitions)
local trackclass = require(script.Parent.Main)
local Actor = script.Parent
local activetracks = {}

Actor:BindToMessage("Init", function(ID, track_settings: TypeDefinitions.TrackSettings, Wheels)
	local track = trackclass.new(track_settings)
	activetracks[ID] = track
	track:Init(Wheels)
	track.Event = game:GetService("RunService").RenderStepped:ConnectParallel(function(dt)
		track:update(dt, true)
	end)
end) 

Actor:BindToMessage("change", function(ID, newdata)
	local track = activetracks[ID]
	if track then
		track:dataupdate(newdata)
	end
end)

Actor:BindToMessage("destroying", function(ID) 
	local track = activetracks[ID]
	if track then
		if track.Event then
			track.Event:Disconnect()
			track.Event = nil
		end
		activetracks[ID] = nil
		for _, v in pairs(track.variables.Treads) do
			if v.trackpart then
				if typeof(v.trackpart) ~= "string" then
                    v.trackpart:Destroy()
                end
			end
		end
		if track.track_settings.ParallelLua then
			script.Parent:Destroy()
		end
	end
end)