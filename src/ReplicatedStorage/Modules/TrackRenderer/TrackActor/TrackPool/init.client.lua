--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TypeDefinitions = require(ReplicatedStorage.Modules.TrackRenderer.TypeDefinitions)
local Common = require(script.Common)    
local Actor = script.Parent
local Camera = game.Workspace.CurrentCamera
local trackclass = {}
local activetracks = {}
trackclass.__index = trackclass

local function returnpoints(Wheels: { BasePart }): ({ Common.PrePoint  })
	local Points: {Common.PrePoint} = {}
	local WheelPoints = {}
	for index, wheel in ipairs(Wheels) do
		local nextindex = index + 1
		if nextindex > #Wheels then
			nextindex = 1
		end
		local nextwheel = Wheels[nextindex]
		local Type = wheel.Name:split("_")
		local nexttype = nextwheel.Name:split("_")
		local rightvector = wheel.CFrame.RightVector

		local Pos1, Pos2 = Common.getexternaltangentpoint(
			Common.vector3tovector(wheel.Position),
			wheel.Size.Z / 2,
			Common.vector3tovector(nextwheel.Position),
			nextwheel.Size.Z / 2,
			Common.vector3tovector(rightvector)
		)

		if WheelPoints[nextindex] then
			WheelPoints[nextindex].pos[2] = WheelPoints[nextindex].pos[1]
			WheelPoints[nextindex].pos[1] = Pos2
		else
			if not nexttype[2] then
				local dir = vector.normalize(Pos2 - Common.vector3tovector(nextwheel.Position))
				local dot = vector.dot(dir, Common.vector3tovector(nextwheel.CFrame.UpVector))
				if dot < 0 then
					Pos2 = Common.vector3tovector(nextwheel.Position) - (Common.vector3tovector(nextwheel.CFrame.UpVector) * (nextwheel.Size.Z / 2))
				else
					Pos2 = Common.vector3tovector(nextwheel.Position) + (Common.vector3tovector(nextwheel.CFrame.UpVector) * (nextwheel.Size.Z / 2))
				end
			end

			WheelPoints[nextindex] = {
			pb = nextwheel,
			pos = {Pos2}
		}
		end
		if Type[2] then
			if Type[2] == "curve" then
				if not WheelPoints[index] then
					WheelPoints[index] = {
						pb = wheel,
						pos = {Pos1}
					}
				else
					WheelPoints[index].pb = wheel
					table.insert(WheelPoints[index].pos, Pos1)
				end
			end
		end
	end
	for _, PosTable in ipairs(WheelPoints) do
		if #PosTable.pos > 1 then
			Points[#Points + 1] = {
				Common.vectortovector3(PosTable.pos[1]),
				Common.vectortovector3(PosTable.pos[2]),
				PosTable.pb,
			} :: Common.PrePoint
		else
			for _, Position in ipairs(PosTable.pos) do
				table.insert(Points, {Common.vectortovector3(Position), PosTable.pb} :: Common.PrePoint)
			end
		end
	end

	table.insert(Points,{Common.vectortovector3(WheelPoints[1].pos[1]), WheelPoints[1].pb} :: Common.PrePoint)
	return Points
end

do
	function trackclass.new(track_settings: TypeDefinitions.TrackSettings)
		local object = {
			IsActive = false,
			Speed = 0 :: number,
			LODDistance = 100,
			track_settings = track_settings,
			Event = nil :: RBXScriptConnection?,
			variables = {
				IsAModel = track_settings.TrackModel:IsA("Model") :: boolean,
				offset = 0 :: number,
				Wheels = {} :: { BasePart },
				Treads = {} :: {{trackpart: Instance | BasePart | Model | string}},
				MainPart = nil :: BasePart?,
				LODParts = {} :: { BasePart },
				LodActivated = false :: boolean,
			},
		}
		setmetatable(object, trackclass)
		return object
	end

	function trackclass:Init(WheelParts: { BasePart })
		for _, wheel in ipairs(WheelParts) do
			if wheel:IsA("BasePart") then
				if wheel.Name == "Main" then
					self.variables.MainPart = wheel
					continue
				end
				local Names = wheel.Name:split("_")
				local currentindex: number = tonumber(Names[1]) or error("nil")
				self.variables.Wheels[currentindex] = wheel
			end
		end
		local Points = returnpoints(self.variables.Wheels)
		local _, totallength = Common.getotallength(Points)
		local numberofparts = math.ceil(totallength / self.track_settings.TrackLength)
		for segment = 1, numberofparts do
			local TrackPart = self.track_settings.TrackModel
			TrackPart = TrackPart:Clone() :: Model
			TrackPart.Parent = workspace.Terrain
			TrackPart.Name = "trackpart_"..tostring(segment)
			
			for _, v in ipairs(TrackPart:GetDescendants()) do
				if v:IsA("BasePart") then
					v.Transparency = 1
				end
			end

			self.variables.Treads[segment] = {
				trackpart = TrackPart,
			}
		end
		local lodlengthcurve = 1
		--generate LOD parts
		for i = 1, #Points - 1 do
			local currentPoint = Points[i]
			local nextpoint = Points[i + 1]
			
			if #currentPoint > 2 then
				local p1: Vector3 = currentPoint[1] :: Vector3
				local p2: Vector3 = currentPoint[2] :: Vector3
				local wheel: BasePart = currentPoint[3] :: BasePart
				local radius = wheel.Size.Z / 2
				local v1 = vector.normalize(Common.vector3tovector(p1) - Common.vector3tovector(wheel.Position))
				local v2 = vector.normalize(Common.vector3tovector(p2) - Common.vector3tovector(wheel.Position))
				local angle = math.acos(vector.dot(v1, v2))
				local arcLength = angle * radius
				local numberofpartscurve = math.ceil(arcLength / lodlengthcurve)
				for segment = 1, numberofpartscurve do
					local t1 = (segment - 1) / numberofpartscurve
					local t2 = segment / numberofpartscurve
					local pos1 = Common.createcirculararc(Common.vector3tovector(wheel.Position), Common.vector3tovector(p1), Common.vector3tovector(p2), radius, Common.vector3tovector(wheel.CFrame.RightVector), t1)
					local pos2 = Common.createcirculararc(Common.vector3tovector(wheel.Position), Common.vector3tovector(p1), Common.vector3tovector(p2), radius, Common.vector3tovector(wheel.CFrame.RightVector), t2)

					local midpoint = (pos1 + pos2) / 2
					local targetcf = CFrame.lookAt(Common.vectortovector3(midpoint), Common.vectortovector3(pos2), wheel.CFrame.RightVector)
					local LODPart = game.ReplicatedStorage.Tracks.LODPart:Clone() :: BasePart
					LODPart.Parent = workspace.Terrain
					LODPart.CFrame = targetcf
					LODPart.Size = Vector3.new(self.track_settings.LODPartHeight :: number, self.track_settings.LODPartWidth :: number, lodlengthcurve)
					Common.weldconstaint(LODPart, self.variables.MainPart :: BasePart)
					table.insert(LODPart :: any, self.variables.LODParts)
					
				end

				local pos2 = nextpoint[1] :: Vector3
				local midpoint = (p2 + pos2) / 2
				local targetcf = CFrame.lookAt(midpoint, pos2, wheel.CFrame.RightVector)
				local LODPart = game.ReplicatedStorage.Tracks.LODPart:Clone() :: BasePart
				LODPart.Parent = workspace.Terrain
				LODPart.CFrame = targetcf
				LODPart.Size = Vector3.new(self.track_settings.LODPartHeight :: number, self.track_settings.LODPartWidth :: number, (p2 - pos2).Magnitude)
				Common.weldconstaint(LODPart, self.variables.MainPart :: BasePart)
				table.insert(LODPart :: any, self.variables.LODParts)
			else
				local p1 = currentPoint[1] :: Vector3
				local wheel = currentPoint[2] :: BasePart

				local pos2 = nextpoint[1] :: Vector3
				local midpoint = (p1 + pos2) / 2
				local targetcf = CFrame.lookAt(midpoint, pos2, wheel.CFrame.RightVector)
				local LODPart = game.ReplicatedStorage.Tracks.LODPart:Clone() :: BasePart
				LODPart.Parent = workspace.Terrain
				LODPart.CFrame = targetcf
				LODPart.Size = Vector3.new(self.track_settings.LODPartHeight :: number, self.track_settings.LODPartWidth :: number, (p1 - pos2).Magnitude)
				Common.weldconstaint(LODPart, self.variables.MainPart :: BasePart)
				table.insert(LODPart :: any, self.variables.LODParts)
			end
		end
	end

	function trackclass:update(dt: number)
		local temp: any = {}
		
		local bulkmove: {Parts: {BasePart}, CFrames: {CFrame}} = {
			Parts = {},
			CFrames = {},
		}

		debug.profilebegin("UpdateTrack")
		if self.IsActive == true then
			local CameraPosition = Camera.CFrame.Position
			local distance = (CameraPosition - self.variables.MainPart.Position).Magnitude

			if distance > self.LODDistance then
				if not self.variables.LodActivated then
					self.variables.LodActivated = true
				end
			else
				if self.variables.LodActivated then
					self.variables.LodActivated = false
				end
			end

			if not self.variables.LodActivated then
				local Points = returnpoints(self.variables.Wheels)
				local lengthtable, totallength = Common.getotallength(Points)
				local numberofparts = math.ceil(totallength / self.track_settings.TrackLength)
				local PartstoMake = math.clamp(numberofparts - #self.variables.Treads,0, 50)

				local speed = (self.Speed :: number * dt) / totallength
				self.variables.offset = (self.variables.offset :: number + speed :: number) % 1
				for _ = 1, PartstoMake do
					table.insert(self.variables.Treads, {
						trackpart = "create",
					})
				end

				for segment, tread : {trackpart: Model | string | BasePart} in ipairs(self.variables.Treads) do
					if segment <= numberofparts then
						local t1 = ( ( (segment - 1) / numberofparts) + self.variables.offset) % 1
						local t2 = ( (segment / numberofparts) + self.variables.offset) % 1

						local Pos1, Face = Common.lerpthroughpoints(t1, Points, lengthtable, totallength)
						local Pos2 = Common.lerpthroughpoints(t2, Points, lengthtable, totallength)
						local midpoint = (Pos1 + Pos2) / 2
						
						local targetCF = CFrame.lookAt(midpoint, Pos2, Face)
						--temp[tread.trackpart] = {targetCF, segment} :: {CFrame | number}
						if typeof(tread.trackpart) ~= "string" then
							if self.variables.IsAModel then
								local model = tread.trackpart :: Model
								table.insert(bulkmove.Parts, model.PrimaryPart :: BasePart)
							else
								local part = tread.trackpart :: BasePart
								table.insert(bulkmove.Parts, part :: BasePart)
							end
						end
						table.insert(bulkmove.CFrames, targetCF)
					else
						temp[tread.trackpart] = {"destroy", segment} :: {string | number}
						table.remove(self.variables.Treads, segment)
					end
				end
			end
		end

		debug.profileend()
		task.synchronize()
		debug.profilebegin("UpdateCFrameTrackParts")

		for value, data in pairs(temp) do
			if typeof(data) == "table" then
				if typeof(data[1]) == "CFrame" then
					local CF = data[1] :: CFrame
					local segment = data[2] :: number
					if typeof(value) ~= "string" then
						value:PivotTo(CF)
					else
						local TrackPart = self.track_settings.TrackModel:Clone()
						TrackPart.Parent = workspace.Terrain
						TrackPart.Name = "trackpart_"..tostring(segment)

						if self.variables.IsAModel then
							local model = TrackPart :: Model
							table.insert(bulkmove.Parts, model.PrimaryPart :: BasePart)
						else
							table.insert(bulkmove.Parts, TrackPart :: BasePart)
						end
						table.insert(bulkmove.CFrames, CF)

						--TrackPart:PivotTo(CF)
						local treadlist = self.variables.Treads :: {{trackpart: Instance | BasePart | Model | string}}
						treadlist[segment].trackpart = TrackPart
					end
				elseif typeof(data[1]) == "string" then
					if data[1] == "destroy" then
						if typeof(value) ~= "string" then
							value:Destroy()
						else
							table.remove(self.variables.Treads, data[2])
						end
					end
				end
			end
		end
		workspace:BulkMoveTo(bulkmove.Parts, bulkmove.CFrames)
		debug.profileend()
	end
end

Actor:BindToMessage("Init", function(ID, track_settings: TypeDefinitions.TrackSettings, Wheels)
	local track = trackclass.new(track_settings)
	activetracks[ID] = track
	track:Init(Wheels)
	track.Event = game:GetService("RunService").RenderStepped:ConnectParallel(function(dt)
		track:update(dt)
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
		if track.track_settings.SeperateActor then
			script.Parent:Destroy()
		end
	end
end)
