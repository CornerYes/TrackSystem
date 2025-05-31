--Testing script for the tank track renderer
local TrackRenderer = require(game.ReplicatedStorage.Modules.TrackRenderer)
local player = game.Players.LocalPlayer
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
task.wait(1)
print("Tank client script started")

local tracksettings = TrackRenderer.newsettings()
tracksettings.TrackLength = 1
tracksettings.TrackModel = game.ReplicatedStorage.Tracks.SimpleTrack
local track = TrackRenderer.new(tracksettings, Wheels:GetChildren())
track:Render()
track:SetSpeed(0.05)

local client_commands = {
    ["/speed"] = function(speed)
        local newSpeed = tonumber(speed)
        if newSpeed then
            track:SetSpeed(newSpeed)
            print("Track speed set to " .. newSpeed)
        else
            print("Invalid speed value")
        end
    end,
}

game.ReplicatedStorage.Events.ev.OnClientEvent:Connect(function(command, ...)
    print("Executing command: " .. command)
    if client_commands[command] then
        client_commands[command](...)
    end
end)