local module = {}

export type Point = {
	number | boolean | {BasePart? | Vector3}?
}

export type PrePoint = {
	Vector3 | BasePart
}

function module.getexternaltangentpoint(c1pos: vector, radi1: number, c2pos: vector, radi2: number, rv: vector): (vector, vector)
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

--mainly used for debugging
function module.createadornment(name: string, raidus: number, CF: CFrame, color: Color3): BasePart
	local SphereAdornment = Instance.new("SphereHandleAdornment")
	SphereAdornment.Name = name
	SphereAdornment.Radius = raidus
	SphereAdornment.Adornee = workspace.Terrain
	SphereAdornment.Parent = workspace.Terrain
	SphereAdornment.CFrame = CF
	SphereAdornment.Color3 = color
	SphereAdornment.ZIndex = 1
	SphereAdornment.Transparency = 0.5
	SphereAdornment.AlwaysOnTop = true
	return SphereAdornment
end

function module.vector3tovector(v: Vector3): vector
	return vector.create(v.X, v.Y, v.Z)
end

function module.vectortovector3(v: vector): Vector3
	return Vector3.new(v.x, v.y, v.z)
end

function module.createcirculararc(center: vector, point1: vector, point2: vector, radius: number, lookVector: vector, t): vector
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

function getlength(a: Vector3, b: Vector3, c: BasePart): ( Point, number)
	local len = (b - a).Magnitude
	local data = {
		len,
		false,
		{a, b, c}
	} :: Point

	return data, len
end

function module.getotallength(points: {Vector3 | PrePoint }): ({ Point }, number)
    local legnthtable = {}
    local totallength = 0

    for i = 1, #points - 1 do
		local currentPoint = points[i]
		local nextpoint = points[i + 1]
		if #currentPoint > 2 then
			local p1: Vector3 = currentPoint[1] :: Vector3
			local p2: Vector3 = currentPoint[2] :: Vector3
			local wheel: BasePart = currentPoint[3] :: BasePart
			local raidus = wheel.Size.Z / 2
			local v1 = vector.normalize(module.vector3tovector(p1) - module.vector3tovector(wheel.Position))
			local v2 = vector.normalize(module.vector3tovector(p2) - module.vector3tovector(wheel.Position))

			local angle = math.acos(vector.dot(v1, v2))
			local arcLength = angle * raidus
			local arcdata = {
				arcLength,
				true,
				{wheel, p1, p2} :: {BasePart | Vector3},
			} :: Point
			totallength += arcLength
			table.insert(legnthtable, arcdata)

			if #nextpoint > 2 then
				local data, len = getlength(p2, nextpoint[1] :: Vector3, nextpoint[3])
				table.insert(legnthtable, data)
        		totallength += len
			else
				local data, len = getlength(p2, nextpoint[1], nextpoint[2])
				table.insert(legnthtable, data)
        		totallength += len
			end
		else
			if #nextpoint > 2 then
				local data, len = getlength(currentPoint[1], nextpoint[1] :: Vector3, nextpoint[3])
				table.insert(legnthtable, data)
        		totallength += len
			else
				local data, len = getlength(currentPoint[1], nextpoint[1], nextpoint[2])
				table.insert(legnthtable, data)
        		totallength += len
			end
		end
    end

    return legnthtable, totallength
end

function module.piecewiselerp(t: number, points: {Vector3 | PrePoint}, legnthtable : {Point}, totallength: number): (Vector3, Vector3)
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
				local arcPoint = module.createcirculararc(
					module.vector3tovector(wheel.Position),
					module.vector3tovector(p1),
					module.vector3tovector(p2),
					radius,
					module.vector3tovector(wheel.CFrame.RightVector),
					segmentT
				)
				return module.vectortovector3(arcPoint), wheel.CFrame.RightVector
			else
				local p1 = pointdata[1] :: Vector3
				local p2 = pointdata[2] :: Vector3
				local wheel = pointdata[3] :: BasePart
				return p1:Lerp(p2 :: Vector3, segmentT), wheel.CFrame.RightVector
			end
        end
        distance += length
    end
    return points[#points] :: Vector3, Vector3.zero
end

return module