--!strict
local TypeDef = require(game.ReplicatedStorage.Modules.TrackRenderer.TypeDefinitions)
local Actor = script.Parent
local dx = 0.01
local trackclass = {}
local activetracks = {}
trackclass.__index = trackclass

type Point = {
	number | boolean | {BasePart? | Vector3}?
}

type PrePoint = {
	Vector3 | BasePart
}

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

local function vector3tovector(v: Vector3): vector
	return vector.create(v.X, v.Y, v.Z)
end

local function vectortovector3(v: vector): Vector3
	return Vector3.new(v.x, v.y, v.z)
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

local function getlength(a: Vector3, b: Vector3): ( Point, number)
	local len = (b - a).Magnitude
	local data = {
		len,
		false,
		{a, b}
	} :: Point

	return data, len
end

local function getotallength(points: {Vector3 | PrePoint }): ({ Point }, number)
    local legnthtable = {}
    local totallength = 0

    for i = 1, #points - 1 do
		local currentPoint = points[i]
		local nextpoint = points[i + 1]
		if typeof(currentPoint) == "table" then
			local p1: Vector3 = currentPoint[1] :: Vector3
			local p2: Vector3 = currentPoint[2] :: Vector3
			local wheel: BasePart = currentPoint[3] :: BasePart
			local raidus = wheel.Size.Z / 2
			local v1 = vector.normalize(vector3tovector(p1) - vector3tovector(wheel.Position))
			local v2 = vector.normalize(vector3tovector(p2) - vector3tovector(wheel.Position))

			local angle = math.acos(vector.dot(v1, v2))
			local arcLength = angle * raidus
			local arcdata = {
				arcLength,
				true,
				{wheel, p1, p2} :: {BasePart | Vector3},
			} :: Point
			totallength += arcLength
			table.insert(legnthtable, arcdata)

			if typeof(nextpoint) == "table" then
				local data, len = getlength(p2, nextpoint[1] :: Vector3)
				table.insert(legnthtable, data)
        		totallength += len
			else
				local data, len = getlength(p2, nextpoint)
				table.insert(legnthtable, data)
        		totallength += len
			end
		else
			if typeof(nextpoint) == "table" then
				local data, len = getlength(currentPoint, nextpoint[1] :: Vector3)
				table.insert(legnthtable, data)
        		totallength += len
			else
				local data, len = getlength(currentPoint, nextpoint)
				table.insert(legnthtable, data)
        		totallength += len
			end
		end
    end

    return legnthtable, totallength
end

local function piecewiselerp(t: number, points: {Vector3 | PrePoint}, legnthtable : {Point}, totallength: number): Vector3
    local target = t * totallength

    local distance = 0
    for i = 1, #legnthtable do
        local length = legnthtable[i][1] :: number
		local isacurve = legnthtable[i][2] :: boolean
		local pointdata = legnthtable[i][3] :: {BasePart | Vector3}
        if distance + length >= target then
			local segmentT = (target - distance) / length
			if isacurve then
				local p1 = pointdata[2] :: Vector3
				local p2 = pointdata[3] :: Vector3
				local wheel = pointdata[1] :: BasePart
				local radius = wheel.Size.Z / 2	
				local arcPoint = createcirculararc(
					vector3tovector(wheel.Position),
					vector3tovector(p1),
					vector3tovector(p2),
					radius,
					vector3tovector(wheel.CFrame.RightVector),
					segmentT
				)
				return vectortovector3(arcPoint)
			else
				local p1 = pointdata[1] :: Vector3
				local p2 = pointdata[2] :: Vector3
				return p1:Lerp(p2 :: Vector3, segmentT)
			end
        end
        distance += length
    end
    return points[#points] :: Vector3
end


local function returnpoints(Wheels: { BasePart }): ({ Vector3 | PrePoint  }, Vector3)
	local Points: {Vector3 | PrePoint} = {}
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

		if WheelPoints[nextindex] then
			WheelPoints[nextindex].pos[2] = WheelPoints[nextindex].pos[1]
			WheelPoints[nextindex].pos[1] = Pos2
		else
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
				vectortovector3(PosTable.pos[1]),
				vectortovector3(PosTable.pos[2]),
				PosTable.pb,
			} :: PrePoint
			center += vectortovector3(PosTable.pos[1])
		else
			for _, Position in ipairs(PosTable.pos) do
				center += vectortovector3(Position)
				table.insert(Points, vectortovector3(Position))
			end
		end
	end

	table.insert(Points,vectortovector3(WheelPoints[1].pos[1]))
	center += vectortovector3(WheelPoints[1].pos[1])

	center /= #Points
	return Points, center
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
		local Points, center = returnpoints(self.variables.Wheels)
		local lengthtable, totallength = getotallength(Points)
		local numberofparts = math.ceil(totallength / self.track_settings.TrackLength)
		for segment = 1, numberofparts do
			local t1 = ((segment - 1) / numberofparts + self.variables.offset) % 1
			local t2 = ((segment / (numberofparts)) + self.variables.offset) % 1

			local TrackPart = self.track_settings.TrackModel
			TrackPart = TrackPart:Clone() :: Model
			TrackPart.Parent = workspace.Terrain
			TrackPart.Name = "TrackPart_" .. segment

			local Pos1 = piecewiselerp(t1, Points, lengthtable, totallength)
			local Pos2 = piecewiselerp(t2, Points, lengthtable, totallength)

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
				t1 = t1,
				t2 = t2
			}
		end
	end

	function trackclass:update(dt: number)
		local temp = {}
		debug.profilebegin("UpdateTrack")
		if self.IsActive then
			self.variables.offset = self.variables.offset :: number
			self.Speed = self.Speed :: number

			local speed = (self.Speed * dt) / self.track_settings.TrackLength
			self.variables.offset = (self.variables.offset + speed) % 1

			local Points, center = returnpoints(self.variables.Wheels)
			local lengthtable, totallength = getotallength(Points)
			for _, tread: {trackpart: BasePart, t1: number, t2: number} in ipairs(self.variables.Treads :: {{trackpart: BasePart, t1: number, t2: number}}) do
				local t1 = (tread.t1 + self.variables.offset) % 1
				local t2 = (tread.t2 + self.variables.offset) % 1

				local Pos1 = piecewiselerp(t1, Points, lengthtable, totallength)
				local Pos2 = piecewiselerp(t2, Points, lengthtable, totallength)
				local midpoint = (Pos1 + Pos2) / 2
				local direction = (Pos2 - Pos1).Unit
				local outward = (Pos1 - center).Unit

				if math.abs(direction:Dot(outward)) > 0.99 then
    				outward = direction:Cross(Vector3.new(0, 1, 0)).Unit
				end

				local targetCF = CFrame.lookAt(midpoint, Pos2, outward * -1)

				temp[tread.trackpart] = targetCF
			end
		end
		task.synchronize()

		for trackpart, targetCF in pairs(temp) do
			trackpart:PivotTo(targetCF)
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
		for _, v in pairs(track.variables.Treads) do
			if v.trackpart then
				v.trackpart:Destroy()
			end
		end
	end
end)

game:GetService("RunService").RenderStepped:Connect(function(dt)
	for _, track in pairs(activetracks) do
		track:update(dt)
	end
end)
