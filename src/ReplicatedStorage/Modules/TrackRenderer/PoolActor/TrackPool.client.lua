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

local function vector3tovector(v: Vector3): vector
	return vector.create(v.X, v.Y, v.Z)
end

do
	function trackclass.new(track_settings: TypeDef.TrackSettings)
		local object = {
			IsActive = false,
			Speed = 0,
			track_settings = track_settings,
			variables = {
				Wheels = {} :: { BasePart },
				Points = {} :: { vector },
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

		for index, wheel in ipairs(self.variables.Wheels) do
			local nextindex = index + 1
			local nextwheel = self.variables.Wheels[nextindex] or self.variables.Wheels[1]
			print(wheel, nextwheel)
			local rightvector = wheel.CFrame.RightVector

			local Pos1, Pos2 = getexternaltangentpoint(
				vector3tovector(wheel.Position),
				wheel.Size.Z / 2,
				vector3tovector(nextwheel.Position),
				nextwheel.Size.Z / 2,
				vector3tovector(rightvector)
			)
			local size = Vector3.new(0.3,0.3,0.3)
			local p1 = createpart("test", size, Vector3.new(Pos1.x, Pos1.y, Pos1.z), Color3.new(1,0,0))
			local p2 = createpart("test", size, Vector3.new(Pos2.x, Pos2.y, Pos2.z), Color3.new(0,1,0))
			wheel.Color = Color3.new(0,1,0)
			nextwheel.Color = Color3.new(1,0,0)
			task.wait(1)
		end
	end

	function trackclass:update(dt)

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
