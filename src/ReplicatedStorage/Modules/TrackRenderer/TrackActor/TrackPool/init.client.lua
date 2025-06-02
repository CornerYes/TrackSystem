--!strict
local TypeDef = require(game.ReplicatedStorage.Modules.TrackRenderer.TypeDefinitions)
local Common = require(script.Common)    
local Actor = script.Parent
local Camera = game.Workspace.CurrentCamera
local trackclass = {}
local activetracks = {}
trackclass.__index = trackclass



local function returnpoints(Wheels: { BasePart }): ({ Vector3 | Common.PrePoint  }, Vector3)
	local Points: {Vector3 | Common.PrePoint} = {}
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
	local center = Vector3.zero
	for _, PosTable in ipairs(WheelPoints) do
		if #PosTable.pos > 1 then
			Points[#Points + 1] = {
				Common.vectortovector3(PosTable.pos[1]),
				Common.vectortovector3(PosTable.pos[2]),
				PosTable.pb,
			} :: Common.PrePoint
			center += Common.vectortovector3(PosTable.pos[1])
		else
			for _, Position in ipairs(PosTable.pos) do
				center += Common.vectortovector3(Position)
				table.insert(Points, Common.vectortovector3(Position))
			end
		end
	end

	table.insert(Points,Common.vectortovector3(WheelPoints[1].pos[1]))
	center += Common.vectortovector3(WheelPoints[1].pos[1])

	center /= #Points
	return Points, center
end

do
	function trackclass.new(track_settings: TypeDef.TrackSettings)
		local object = {
			IsActive = false,
			Speed = 0 :: number,
			LODDistance = 100,
			track_settings = track_settings,
			Event = nil :: RBXScriptConnection?,
			variables = {
				offset = 0 :: number,
				Wheels = {} :: { BasePart },
				Treads = {} :: {{trackpart: Instance | BasePart | Model}},
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
			if wheel.Name == "Main" then
				self.variables.MainPart = wheel
				continue
			end
			local Names = wheel.Name:split("_")
			local currentindex: number = tonumber(Names[1]) or error("nil")
			self.variables.Wheels[currentindex] = wheel
		end
		local Points, center = returnpoints(self.variables.Wheels)
		local lengthtable, totallength = Common.getotallength(Points)
		local numberofparts = math.ceil(totallength / self.track_settings.TrackLength)
		for segment = 1, numberofparts do
			local t1 = ((segment - 1) / numberofparts + self.variables.offset) % 1
			local t2 = ((segment / (numberofparts)) + self.variables.offset) % 1

			local TrackPart = self.track_settings.TrackModel
			TrackPart = TrackPart:Clone() :: Model
			TrackPart.Parent = workspace.Terrain
			TrackPart.Name = "TrackPart_" .. segment

			local Pos1 = Common.piecewiselerp(t1, Points, lengthtable, totallength)
			local Pos2 = Common.piecewiselerp(t2, Points, lengthtable, totallength)

			local midpoint = (Pos1 + Pos2) / 2

			local direction = (Pos2 - Pos1).Unit
			local outward = (Pos1 - center).Unit

			if math.abs(direction:Dot(outward)) > 0.99 then
    			outward = direction:Cross(Vector3.new(0, 1, 0)).Unit
			end
			local targetCF = CFrame.lookAt(midpoint, Pos2, outward * -1)

			TrackPart:PivotTo(targetCF)

			self.variables.Treads[segment] = {
				trackpart = TrackPart,
			}
		end
	end

	function trackclass:update(dt: number)
		local temp: any = {}
		debug.profilebegin("UpdateTrack")
		if self.IsActive then
			local CameraPosition = Camera.CFrame.Position
			local distance = (CameraPosition - self.variables.MainPart.Position).Magnitude
			if distance > self.LODDistance then
				print("LOD true")
			end

			local speed = (self.Speed :: number * dt) / self.track_settings.TrackLength
			self.variables.offset = (self.variables.offset :: number + speed :: number) % 1

			local Points, center = returnpoints(self.variables.Wheels)
			local lengthtable, totallength = Common.getotallength(Points)
			local numberofparts = math.ceil(totallength / self.track_settings.TrackLength)
			for segment = 1, numberofparts do
				local tread: {trackpart: Instance} = self.variables.Treads[segment]
				if tread then
					if segment <= numberofparts then
						local t1 = ( ( (segment - 1) / numberofparts) + self.variables.offset) % 1
						local t2 = ( (segment / numberofparts) + self.variables.offset) % 1

						local Pos1 = Common.piecewiselerp(t1, Points, lengthtable, totallength)
						local Pos2 = Common.piecewiselerp(t2, Points, lengthtable, totallength)
						local midpoint = (Pos1 + Pos2) / 2
						local direction = (Pos2 - Pos1).Unit
						local outward = (Pos1 - center).Unit

						if math.abs(direction:Dot(outward)) > 0.99 then
    						outward = direction:Cross(Vector3.new(0, 1, 0)).Unit
						end

						local targetCF = CFrame.lookAt(midpoint, Pos2, outward * -1)
						temp[tread.trackpart] = targetCF
					else
						temp[tread.trackpart] = "destroy"
						table.remove(self.variables.Treads, segment)
					end
				else

				end
			end
            print(#self.variables.Treads, numberofparts)
		end
		debug.profileend()
		task.synchronize()

		for value, data in pairs(temp) do
			if typeof(data) == "CFrame" then
				value:PivotTo(data)
			elseif typeof(data) == "string" then
				if data == "destroy" then
					value:Destroy()
				end
			end
		end
	end
end

Actor:BindToMessage("Init", function(ID, track_settings: TypeDef.TrackSettings, Wheels)
	local track = trackclass.new(track_settings)
	activetracks[ID] = track
	track:Init(Wheels)
	track.Event = game:GetService("RunService").RenderStepped:ConnectParallel(function(dt)
		track:update(dt)
	end)
end)  	 	

Actor:BindToMessage("change", function(ID, newdata: { IsActive: boolean?, Speed: number?, LODDistance: number? })
	local track = activetracks[ID]
	if track then
		print(newdata)
		track.Speed = newdata.Speed or track.Speed
		track.IsActive = newdata.IsActive or track.IsActive
		track.LODDistance = newdata.LODDistance or track.LODDistance
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
				v.trackpart:Destroy()
			end
		end
		if track.track_settings.SeperateActor then
			script.Parent:Destroy()
		end
	end
end)
