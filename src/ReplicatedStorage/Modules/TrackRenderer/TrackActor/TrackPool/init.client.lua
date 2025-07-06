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

Actor:BindToMessage("change", function(ID, newdata: { IsActive: boolean?, Speed: number?, LODDistance: number?, Sagging: number? })
	local track = activetracks[ID]
	if track then

		for name, value in pairs(newdata) do
			if track[name] ~= nil then
				track[name] = value
			end
		end

		if track.IsActive == true then
			if track.variables.LodActivated then
				for _, lodtread in ipairs(track.variables.LODParts) do
					lodtread.Transparency = 0
				end
			end
			for _, tread in ipairs(track.variables.Treads) do
				local trackpart = tread.trackpart :: Model | BasePart
				if typeof(trackpart) ~= "string" then
					if trackpart:IsA("Model") then
						for _, parts in ipairs(trackpart:GetDescendants()) do
							if parts:IsA("BasePart") then
								parts.Transparency = 0
							end
						end
					else
						trackpart.Transparency = 0
					end
				end
			end
		else
			for _, lodtread in ipairs(track.variables.LODParts) do
				lodtread.Transparency = 1
			end
			for _, tread in ipairs(track.variables.Treads) do
				local trackpart = tread.trackpart :: Model | BasePart
				if typeof(trackpart) ~= "string" then
					if trackpart:IsA("Model") then
						for _, parts in ipairs(trackpart:GetDescendants()) do
							if parts:IsA("BasePart") then
								parts.Transparency = 1
							end
						end
					else
						trackpart.Transparency = 1
					end
				end
			end
		end
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
		if track.track_settings.SeparateActor then
			script.Parent:Destroy()
		end
	end
end)