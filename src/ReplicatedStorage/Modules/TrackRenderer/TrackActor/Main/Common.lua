local module = {}

export type Point = {
	number | boolean | {BasePart? | vector}?
}

export type PrePoint = {
	vector | BasePart
}

function module.getvectorintersection(pos1, d1, pos2, d2, over): vector?
	local cross = vector.cross(d1, d2)
	local dot = vector.dot(d1, d2)
	if vector.magnitude(cross) < 1e-6 then
		return nil
	end

	if over == nil then
		if dot > 0.9  then
			return nil
		end
	end

	local p1p2 = pos2 - pos1
	local t = vector.magnitude(vector.cross(p1p2, d2)) / vector.magnitude(cross)
	local intersection = pos1 + d1 * t
	return intersection
end

function module.debugsphere(name, pos, color, radius)
	if workspace.Terrain.Adorments:FindFirstChild(name) then
		local adore: SphereHandleAdornment = workspace.Terrain.Adorments[name]
		adore.CFrame = pos
	else
		module.createadornment(name, radius, pos, color)
	end
end

function module.debugarrow(name, pos: vector, dir: vector, color, length: number)
	if workspace.Terrain.Adorments:FindFirstChild(name) then
		local adore: Part = workspace.Terrain.Adorments[name]
		local newdir = vector.normalize(dir) * length
		local newpos = pos + newdir
		local midpoint = (pos + newpos) / 2

		adore.CFrame = CFrame.lookAt(module.vectortovector3(midpoint), module.vectortovector3(newpos))
	else
		module.createarrow(name, pos, dir, color, length)
	end
end

function module.createpart()
	local part = Instance.new("Part")
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Parent = workspace.Terrain
	part.Color = Color3.new(0,0,0)
	return part
end

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

function module.weldconstaint(p0: BasePart, p1: BasePart): WeldConstraint
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = p0
	weld.Part1 = p1
	weld.Parent = p0
	return weld
end

--mainly used for debugging
function module.createadornment(name: string, raidus: number, CF: CFrame, color: Color3): BasePart
	local SphereAdornment = Instance.new("SphereHandleAdornment")
	SphereAdornment.Name = name
	SphereAdornment.Radius = raidus
	SphereAdornment.Adornee = workspace.Terrain
	SphereAdornment.Parent = workspace.Terrain.Adorments
	SphereAdornment.CFrame = CF
	SphereAdornment.Color3 = color
	SphereAdornment.ZIndex = 1
	SphereAdornment.Transparency = 0.5
	SphereAdornment.AlwaysOnTop = true
	return SphereAdornment
end

function module.createarrow(name: string, pos, dir, color: Color3, length): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(0.1,0.1,length)
	part.CFrame = CFrame.new(pos, pos + dir)
	part.Color = color
	part.Anchored = true
	part.CanCollide = false
	part.Parent = workspace.Terrain.Adorments
	return part
end

function module.vector3tovector(v: Vector3): vector
	return vector.create(v.X, v.Y, v.Z)
end

function module.vectortovector3(v: vector): Vector3
	return Vector3.new(v.x, v.y, v.z)
end

function module.returnpoints(Wheels: { BasePart }): { PrePoint }
	local Points: { PrePoint } = {}
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

		local Pos1, Pos2 = module.getexternaltangentpoint(
			module.vector3tovector(wheel.Position),
			wheel.Size.Z / 2,
			module.vector3tovector(nextwheel.Position),
			nextwheel.Size.Z / 2,
			module.vector3tovector(rightvector)
		)

		if Type[2] then
			if lastpos then
				Points[#Points + 1] = {
					lastpos,
					Pos1,
					wheel,
					nextwheel,
				} :: PrePoint
				lastpos = Pos2
			else
				local lastindex = index - 1
				if lastindex < 1 then
					lastindex = #Wheels
				end
				local lastwheel = Wheels[lastindex]
				local _, pos2 = module.getexternaltangentpoint(
					module.vector3tovector(lastwheel.Position),
					lastwheel.Size.Z / 2,
					module.vector3tovector(wheel.Position),
					wheel.Size.Z / 2,
					module.vector3tovector(rightvector)
				)

				Points[#Points + 1] = {
					pos2,
					Pos1,
					wheel,
					lastwheel,
				} :: PrePoint
			end
		end

		if not nexttype[2] then
			table.insert(Points, { Pos2, wheel } :: PrePoint)
		end
		if index == #Wheels then
			local firstpoint = Points[1]
			if #firstpoint > 2 then
				table.insert(Points, { firstpoint[1], firstpoint[3] })
			else
				table.insert(Points, { firstpoint[1], firstpoint[2] })
			end
		end
		lastpos = Pos2
	end
	return Points
end

function module.createcirculararc(center: vector, point1: vector, point2: vector, radius: number, lookVector: vector, t, longway: boolean?): vector
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

function getlength(a: vector, b: vector, c: BasePart): ( Point, number)
	local len = vector.magnitude(b - a)
	local data = {
		len,
		false,
		{a, b, c}
	} :: Point

	return data, len
end

function module.getotallength(points: {PrePoint}): ({ Point }, number)
    local legnthtable = {}
    local totallength = 0

    for i = 1, #points - 1 do
		local currentPoint = points[i]
		local nextpoint = points[i + 1]
		if #currentPoint > 2 then
			local p1: vector = currentPoint[1] :: vector
			local p2: vector = currentPoint[2] :: vector
			local wheel: BasePart = currentPoint[3] :: BasePart
			local nextwheel: BasePart = currentPoint[4] :: BasePart
			local raidus = wheel.Size.Z / 2

			local v1 = vector.normalize(p1 - module.vector3tovector(wheel.Position))
			local v2 = vector.normalize(p2 - module.vector3tovector(wheel.Position))

			local angle = math.acos(vector.dot(v1, v2))
			local arcLength = angle * raidus

			local arcdata = {
				arcLength,
				true,
				{wheel, p1, p2, nextwheel} :: {BasePart | vector},
			} :: Point

			if arcLength ~= arcLength then
				arcLength = 0
			end

			totallength += arcLength
			table.insert(legnthtable, arcdata)

			if #nextpoint > 2 then
				local data, len = getlength(p2, nextpoint[1] :: vector, nextpoint[3])
				table.insert(legnthtable, data)
        		totallength += len
			else
				local data, len = getlength(p2, nextpoint[1], nextpoint[2])
				table.insert(legnthtable, data)
        		totallength += len
			end
		else
			if #nextpoint > 2 then
				local data, len = getlength(currentPoint[1], nextpoint[1] :: vector, nextpoint[3])
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

function module.lerpthroughpoints(t: number, lengthtable : {Point}, totallength: number): (Vector3, Vector3)
    local target = t * totallength

    local distance = 0
    for i = 1, #lengthtable do
        local length = lengthtable[i][1] :: number
		local isacurve = lengthtable[i][2] :: boolean
		local pointdata = lengthtable[i][3] :: {BasePart | vector}
        if distance + length >= target then
			local segmentT = (target - distance) / length
			if isacurve then
				local p1 = pointdata[2] :: vector
				local p2 = pointdata[3] :: vector
				local wheel = pointdata[1] :: BasePart
				local nextwheel = pointdata[4] :: BasePart

				local radius = wheel.Size.Z / 2	
				local nextwheelradius = nextwheel.Size.Z / 2

				local arcPoint = module.createcirculararc(
					module.vector3tovector(wheel.Position),
					p1,
					p2,
					radius,
					module.vector3tovector(wheel.CFrame.RightVector),
					segmentT
				)
				
				return module.vectortovector3(arcPoint), wheel.CFrame.RightVector
			else
				local p1 = pointdata[1] :: vector
				local p2 = pointdata[2] :: vector
				local wheel = pointdata[3] :: BasePart
				return p1:Lerp(p2 :: vector, segmentT), wheel.CFrame.RightVector
			end
        end
        distance += length
    end
	
    return  Vector3.zero, Vector3.zero
end

return module