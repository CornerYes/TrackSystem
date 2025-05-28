
local TrackRenderer = require(game.ReplicatedStorage.Modules.TrackRenderer)
local loaded = false
local Wheels = workspace.Track
while true do
    if Wheels:FindFirstChildWhichIsA("BasePart") then
        if not loaded then
            loaded = true
            print("Wheels loaded")
        end
        break
    end
    task.wait()
end
print("Tank client script started")

local tracksettings = TrackRenderer.newsettings()
local track = TrackRenderer.new(tracksettings, Wheels:GetChildren())
track:Render()