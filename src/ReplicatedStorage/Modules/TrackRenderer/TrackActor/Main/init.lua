local trackclass = {}
trackclass.__index = trackclass
local Camera = workspace.CurrentCamera
local Common = require(script.Common)
local TypeDefinitions = require(script.TypeDefinitions)


local function returnpoints(Wheels: { BasePart }): ({ Common.PrePoint  })
	local Points: {Common.PrePoint} = {}
	local lastpos: vector? = nil
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

		if Type[2] then
			if lastpos then
				Points[#Points + 1] = {
					lastpos,
					Pos1,
					wheel,
				} :: Common.PrePoint
				lastpos = Pos2
			else
				local lastindex = index - 1
				if lastindex < 1 then
					lastindex = #Wheels
				end
				local lastwheel = Wheels[lastindex]
				local _, pos2 = Common.getexternaltangentpoint(
					Common.vector3tovector(lastwheel.Position),
					lastwheel.Size.Z / 2,
					Common.vector3tovector(wheel.Position),
					wheel.Size.Z / 2,
					Common.vector3tovector(rightvector)
				)
				Points[#Points + 1] = {
					pos2,
					Pos1,
					wheel,
				} :: Common.PrePoint
			end
		end

		if not nexttype[2] then
			
			table.insert(Points, {Pos2, wheel} :: Common.PrePoint)
		end
		if index == #Wheels then
			local firstpoint = Points[1]
			if #firstpoint > 2 then
				table.insert(Points, {firstpoint[1], firstpoint[3]} )
			else
				table.insert(Points, {firstpoint[1], firstpoint[2]} )
			end
		end
		lastpos = Pos2
	end
	return Points
end


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
				local p1: vector = currentPoint[1] :: vector
				local p2: vector = currentPoint[2] :: vector
				local wheel: BasePart = currentPoint[3] :: BasePart
				local radius = wheel.Size.Z / 2
				local v1 = vector.normalize(p1 - Common.vector3tovector(wheel.Position))
				local v2 = vector.normalize(p2 - Common.vector3tovector(wheel.Position))
				local angle = math.acos(vector.dot(v1, v2))
				local arcLength = angle * radius
				local numberofpartscurve = math.ceil(arcLength / lodlengthcurve)
				for segment = 1, numberofpartscurve do
					local t1 = (segment - 1) / numberofpartscurve
					local t2 = segment / numberofpartscurve
					local pos1 = Common.createcirculararc(Common.vector3tovector(wheel.Position), p1, p2, radius, Common.vector3tovector(wheel.CFrame.RightVector), t1)
					local pos2 = Common.createcirculararc(Common.vector3tovector(wheel.Position), p1, p2, radius, Common.vector3tovector(wheel.CFrame.RightVector), t2)

					local midpoint = (pos1 + pos2) / 2
					local targetcf = CFrame.lookAt(Common.vectortovector3(midpoint), Common.vectortovector3(pos2), wheel.CFrame.RightVector)
					local LODPart = game.ReplicatedStorage.Tracks.LODPart:Clone() :: BasePart
					LODPart.Parent = workspace.Terrain
					LODPart.CFrame = targetcf
					LODPart.Size = Vector3.new(self.track_settings.LowDetailPartHeight :: number, self.track_settings.LowDetailPartWidth :: number, lodlengthcurve)
					Common.weldconstaint(LODPart, self.variables.MainPart :: BasePart)
					table.insert(self.variables.LODParts, LODPart)
					
				end

				local pos2 = nextpoint[1] :: vector
				local midpoint = (p2 + pos2) / 2
				local targetcf = CFrame.lookAt(Common.vectortovector3(midpoint), Common.vectortovector3(pos2), wheel.CFrame.RightVector)
				local LODPart = game.ReplicatedStorage.Tracks.LODPart:Clone() :: BasePart
				LODPart.Parent = workspace.Terrain
				LODPart.CFrame = targetcf
				LODPart.Size = Vector3.new(self.track_settings.LowDetailPartHeight :: number, self.track_settings.LowDetailPartWidth :: number, vector.magnitude(p2 - pos2))
				Common.weldconstaint(LODPart, self.variables.MainPart :: BasePart)
				table.insert(self.variables.LODParts, LODPart)
			else
				local p1 = currentPoint[1] :: vector
				local wheel = currentPoint[2] :: BasePart

				local pos2 = nextpoint[1] :: vector
				local midpoint = (p1 + pos2) / 2
				local targetcf = CFrame.lookAt(Common.vectortovector3(midpoint), Common.vectortovector3(pos2), wheel.CFrame.RightVector)
				local LODPart = game.ReplicatedStorage.Tracks.LODPart:Clone() :: BasePart
				LODPart.Parent = workspace.Terrain
				LODPart.CFrame = targetcf
				LODPart.Size = Vector3.new(self.track_settings.LowDetailPartHeight :: number, self.track_settings.LowDetailPartWidth :: number, vector.magnitude(p1 - pos2))
				Common.weldconstaint(LODPart, self.variables.MainPart :: BasePart)
				table.insert(self.variables.LODParts, LODPart)
			end
		end
	end

	function trackclass:update(dt: number)
		--benchmarks.start5 = os.clock()
		local temp: any = {}
		
		local bulkmove: {Parts: {BasePart}, CFrames: {CFrame}} = {
			Parts = {},
			CFrames = {},
		}

		if self.IsActive == true then
			local CameraPosition = Camera.CFrame.Position
			local distance = (CameraPosition - self.variables.MainPart.Position).Magnitude
			local currentGraphicsLevel = UserSettings().GameSettings.SavedQualityLevel
			if distance > self.LODDistance or currentGraphicsLevel == Enum.SavedQualitySetting.QualityLevel1  then
				if not self.variables.LodActivated then
					self.variables.LodActivated = true

					for _, lodtread in ipairs(self.variables.LODParts) do
						temp[lodtread] = 0
					end
					for _, tread in ipairs(self.variables.Treads) do

						if self.variables.IsAModel then
							local model = tread.trackpart :: Model
							table.insert(bulkmove.Parts, model.PrimaryPart :: BasePart)
						else
							table.insert(bulkmove.Parts, tread.trackpart :: BasePart)
						end

						table.insert(bulkmove.CFrames, CFrame.new(0,-50,0))
					end
				end
			else
				if self.variables.LodActivated then
					self.variables.LodActivated = false
					
					for _, lodtread in ipairs(self.variables.LODParts) do
						temp[lodtread] = 1
					end
				end
			end
			
			if not self.variables.LodActivated then
				--benchmarks.start1 = os.clock()
				local Points = returnpoints(self.variables.Wheels)
				--benchmarks.end1 = os.clock()
				--benchmarks.start3 = os.clock()
				local lengthtable, totallength = Common.getotallength(Points)
				--benchmarks.end3 = os.clock()
				local numberofparts = math.ceil(totallength / self.track_settings.TrackLength)
				local PartstoMake = math.clamp(numberofparts - #self.variables.Treads,0, 50)
				local speed = (self.Speed :: number * dt) / totallength
				self.variables.offset = (self.variables.offset :: number + speed :: number) % 1

				for _ = 1, PartstoMake do
					local data = {
						trackpart = "create",
					 }
					table.insert(self.variables.Treads, data)
				end
				--benchmarks.list = {}
				--benchmarks.start2 = os.clock()
				for segment, tread : {trackpart: Model | string | BasePart} in ipairs(self.variables.Treads) do
					if segment <= numberofparts then
						--[[local test = {
							start1 = 0,
							end1 = 0,
						}]]
						local t1 = ( ( (segment - 1) / numberofparts) + self.variables.offset) % 1
						local t2 = ( (segment / numberofparts) + self.variables.offset) % 1

						--test.start1 = os.clock()
						local Pos1, Face = Common.lerpthroughpoints(t1, Points, lengthtable, totallength)
						local Pos2 = Common.lerpthroughpoints(t2, Points, lengthtable, totallength)
						--test.end1 = os.clock()
						--table.insert(benchmarks.list, test)
						local midpoint = (Pos1 + Pos2) / 2
						local targetCF = CFrame.lookAt(midpoint, Pos2, Face)
						if typeof(tread.trackpart) ~= "string" then
							if self.variables.IsAModel then
								local model = tread.trackpart :: Model
								table.insert(bulkmove.Parts, model.PrimaryPart :: BasePart)
							elseif typeof(tread.trackpart) == "string" and tread.trackpart == "create" then
								local part = tread.trackpart :: BasePart
								table.insert(bulkmove.Parts, part :: BasePart)
							end
						else
							temp[tread.trackpart] = {targetCF, segment} :: {CFrame | number}
						end
						table.insert(bulkmove.CFrames, targetCF)
					else
						temp[tread.trackpart] = {"destroy", segment} :: {string | number}
						table.remove(self.variables.Treads, segment)
					end
				end
				--benchmarks.end2 = os.clock()
			end
		end
		task.synchronize()
		
		for value, data in pairs(temp) do
			if typeof(data) == "table" then
				if typeof(data[1]) == "CFrame" then
					local segment = data[2] :: number

					local TrackPart = self.track_settings.TrackModel:Clone() :: any
					TrackPart.Parent = workspace.Terrain
					TrackPart.Name = "trackpart_"..tostring(segment)

					if self.variables.IsAModel then
						
						local model = TrackPart :: Model
						table.insert(bulkmove.Parts, model.PrimaryPart :: BasePart)
					else
						
						table.insert(bulkmove.Parts, TrackPart :: BasePart)
					end
					local treadlist = self.variables.Treads :: {{trackpart: Instance | BasePart | Model | string}}
					treadlist[segment].trackpart = TrackPart
					
				elseif typeof(data[1]) == "string" then
					if data[1] == "destroy" then
						if typeof(value) ~= "string" then
							value:Destroy()
						else
							table.remove(self.variables.Treads, data[2])
						end
					end
				end
			elseif typeof(data) == "number" then
				value.Transparency = data
			end
		end
		--benchmarks.start4 = os.clock()
		if #bulkmove.CFrames == #bulkmove.Parts then
			workspace:BulkMoveTo(bulkmove.Parts, bulkmove.CFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	--benchmarks.end4 = os.clock()
	--benchmarks.end5 = os.clock()
end


return trackclass