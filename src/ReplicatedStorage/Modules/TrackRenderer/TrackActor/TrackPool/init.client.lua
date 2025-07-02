--!strict
local benchmarks: any = {}
local TypeDefinitions = require(script.Parent.Main.TypeDefinitions)
local trackclass = require(script.Parent.Main)
local Actor = script.Parent
local activetracks = {}

Actor:BindToMessage("Init", function(ID, track_settings: TypeDefinitions.TrackSettings, Wheels)
	local track = trackclass.new(track_settings)
	activetracks[ID] = track
	track:Init(Wheels)
	track.Event = game:GetService("RunService").RenderStepped:ConnectParallel(function(dt)
		benchmarks = track:update(dt, true, benchmarks)
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

while true do
	if benchmarks["end1"] then
		local ms1 = (benchmarks.end1 - benchmarks.start1) * 1000
		local ms2 = (benchmarks.end2 - benchmarks.start2) * 1000
		local ms3 = (benchmarks.end3 - benchmarks.start3) * 1000
		local ms4 = (benchmarks.end4 - benchmarks.start4) * 1000
		local ui = game.Players.LocalPlayer.PlayerGui.ScreenGui.Frame
		ui.calc.Text = string.format("CalculatePoints: %.3f", ms1)
		ui.length.Text = string.format("GetLength: %.3f ", ms3)
		ui.set.Text = string.format("ApplyTread: %.3f ", ms2)
		ui.ms4.Text = string.format("BulkMove: %.3f", ms4)
		local added = 0
		for _, v in ipairs(benchmarks.list) do
			local times = (v.end1 - v.start1) * 1000
			added = added + times
		end
		local avg = added / #benchmarks.list
		ui.ltp.Text = string.format("LerpThroughPoints (AVG): %.6f", avg)
		local ms5 = (benchmarks.end5 - benchmarks.start5) * 1000
		ui.ms5.Text = string.format("update(): %.3f", ms5)
	end
	task.wait(0.5)
end
