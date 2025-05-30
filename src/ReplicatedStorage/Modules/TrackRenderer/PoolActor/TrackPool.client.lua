--!strict
local TypeDef = require(game.ReplicatedStorage.Modules.TrackRenderer.TypeDefinitions)
local Actor = script.Parent
local trackclass = {}
local activetracks = {}
trackclass.__index = trackclass

local function getexternaltangentpoint(c1pos: vector, radi1: number, c2pos: vector, radi2: number, rv: vector): (vector, vector)
	local dir = c1pos - c2pos
	local distance = vector.magnitude(dir)

	if distance < math.abs(radi1 - radi2) then
		return vector.create(0,0,0), vector.create(0,0,0)
	end
	local u = vector.normalize(dir)
	local costheta = (radi1 - radi2) / distance
	local sinthera = math.sqrt(1 - costheta^2)
	local n0 = vector.normalize(vector.cross(rv, u))
	local n = u * costheta + n0 * sinthera
	local t1 = c1pos - radi1 * n
	local t2 = c2pos - radi2 * n
	return t1, t2
end

local function createpart(name: string, size: Vector3, position: Vector3, color: Color3): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Anchored = true
	part.CanCollide = false
	part.Parent = workspace
	return part
end

local function getotallength(points: {Vector3}): ({number}, number)
    local legnthtable = {}
    local totallength = 0

    for i = 1, #points - 1 do
        local len = (points[i+1] - points[i]).Magnitude
        table.insert(legnthtable, len)
        totallength += len
    end

    return legnthtable, totallength
end

local function createcirculararc(center: vector, point1: vector, point2: vector, radius: number, lookVector: vector, t): vector
	lookVector = lookVector * -1
	local v1 = vector.normalize(point1 - center)
	local v2 = vector.normalize(point2 - center)
	local angle = -math.acos(vector.dot(v1, v2))
	local cross = vector.cross(v1, v2)
	if vector.dot(cross, lookVector) < 0 then
		angle = -angle
	end
	local theta = angle * t
	local rotatedPoint = center + (v1 * radius * math.cos(theta)) + (vector.cross(v1, lookVector) * radius * math.sin(theta))
	return rotatedPoint
end

local function parametriclinearLerp(t: number, points: {Vector3}): Vector3
    local count = #points
    if count < 2 then
        return points[1] or Vector3.zero
    end

    t = math.clamp(t, 0, 1)

    local legnthtable, totallength = getotallength(points)
    local target = t * totallength

    local distance = 0
    for i = 1, #legnthtable do
        local length = legnthtable[i]
        if distance + length >= target then
            local segmentT = (target - distance) / length
            return points[i]:Lerp(points[i + 1], segmentT), totallength
        end
        distance += length
    end

    return points[#points]
end

local function vector3tovector(v: Vector3): vector
	return vector.create(v.X, v.Y, v.Z)
end

local function vectortovector3(v: vector): Vector3
	return Vector3.new(v.x, v.y, v.z)
end

local function returnpoints(Wheels: { BasePart }): {Vector3}
	local Points = {}
	local WheelPoints = {}
	for index, wheel in ipairs(Wheels) do
			local nextindex = index + 1
			if nextindex > #Wheels then
				nextindex = 1
			end
			local nextwheel = Wheels[nextindex]
			local Type = wheel.Name:split("_")
			local rightvector = wheel.CFrame.RightVector

			local Pos1, Pos2 = getexternaltangentpoint(
				vector3tovector(wheel.Position),
				wheel.Size.Z / 2,
				vector3tovector(nextwheel.Position),
				nextwheel.Size.Z / 2,
				vector3tovector(rightvector)
			)

			WheelPoints[nextindex] = {
				pb = nextwheel,
				pos = {Pos2}
			}
			if Type[2] then
				if Type[2] == "curve" then
					WheelPoints[index].pb = wheel
					table.insert(WheelPoints[index].pos, Pos1)
				end
			end
		end

		for _, PosTable in ipairs(WheelPoints) do
			if #PosTable.pos > 1 then
					table.insert(Points, vectortovector3(PosTable.pos[1]))
					local v1 = vector.normalize(PosTable.pos[1] - vector3tovector(PosTable.pb.Position))
					local v2 = vector.normalize(PosTable.pos[2] - vector3tovector(PosTable.pb.Position))

					local angle = math.acos(vector.dot(v1, v2))
					local arcLength = angle * PosTable.pb.Size.Z / 2
					local totalsegments = math.ceil(arcLength/0.5)

					for segment = 1, totalsegments do 
						local t = (segment - 1) / totalsegments
						local arcPoint = createcirculararc(
							vector3tovector(PosTable.pb.Position),
							PosTable.pos[1],
							PosTable.pos[2],
							PosTable.pb.Size.Z / 2,
							vector3tovector(PosTable.pb.CFrame.RightVector),
							t
						)
						table.insert(Points, vectortovector3(arcPoint))
					end
					table.insert(Points, vectortovector3(PosTable.pos[2]))
				else
				for _, Position in ipairs(PosTable.pos) do
					table.insert(Points, vectortovector3(Position))
				end
			end
		end
	table.insert(Points, vectortovector3(WheelPoints[1].pos[1]))
	return Points
end

do
	function trackclass.new(track_settings: TypeDef.TrackSettings)
		local object = {
			IsActive = false,
			Speed = 0 :: number,
			track_settings = track_settings,
			variables = {
				offset = 0 :: number,
				Wheels = {} :: { BasePart },
				Treads = {} :: {trackpart: BasePart, t1: number, t2: number} ,
				MainPart = nil :: BasePart?
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
		local Points = returnpoints(self.variables.Wheels)
		
		local _, totallength = getotallength(Points)
		local numberofparts = math.ceil(totallength / self.track_settings.TrackLength)
		for segment = 1, numberofparts do
			local t1 = ((segment - 1) / numberofparts + self.variables.offset) % 1
			local t2 = ((segment / numberofparts) + self.variables.offset) % 1

			local TrackPart = self.track_settings.TrackModel
			if not TrackPart then
				return
			end

			TrackPart = TrackPart:Clone() :: Model
			TrackPart.Parent = workspace.Terrain
			local Pos1 = parametriclinearLerp(t1, Points)
			local Pos2 = parametriclinearLerp(t2, Points)
			local targetCF = CFrame.lookAt(Pos1, Pos2, self.variables.MainPart.CFrame.UpVector)
			TrackPart:PivotTo(targetCF)

			self.variables.Treads[segment] = {
				trackpart = TrackPart,
				t1 = t1,
				t2 = t2
			}
		end
	end

	function trackclass:update(dt: number)
		if self.IsActive then
			self.variables.offset = self.variables.offset :: number
			self.Speed = self.Speed :: number
			local speed = (self.Speed * dt) / self.track_settings.TrackLength
			self.variables.offset = (self.variables.offset + speed) % 1
			print(self.variables.offset)
			local Points = returnpoints(self.variables.Wheels)
			for segment, tread in ipairs(self.variables.Treads) do
				local t1 = (tread.t1 + self.variables.offset) % 1
				local t2 = (tread.t2 + self.variables.offset) % 1

				local Pos1 = parametriclinearLerp(t1, Points)
				local Pos2 = parametriclinearLerp(t2, Points)

				local targetCF = CFrame.lookAt(Pos1, Pos2, self.variables.MainPart.CFrame.UpVector)
				tread.trackpart:PivotTo(targetCF)
			end
		end
	end

	function trackclass:destroying()
		
	end
end

Actor:BindToMessage("Init", function(ID, track_settings: TypeDef.TrackSettings, Wheels)
	local track = trackclass.new(track_settings)
	activetracks[ID] = track
	track:Init(Wheels)
end)  	 	

Actor:BindToMessage("change", function(ID, newdata: { IsActive: boolean, Speed: number })
	local track = activetracks[ID]
	track.Speed = newdata.Speed
	track.IsActive = newdata.IsActive
end)

Actor:BindToMessage("destroying", function(ID) 
	local track = activetracks[ID]
	if track then
		track:destroying()
		activetracks[ID] = nil
	end
end)

game:GetService("RunService").RenderStepped:Connect(function(dt)
	for _, track in pairs(activetracks) do
		track:update(dt)
	end
end)
