--Testing script for the tank track renderer
local TrackRenderer = require(game.ReplicatedStorage.Modules.TrackRenderer)
task.wait(3)
print("Tank client script started")

local tracks = {}

for _, v: Model in ipairs(workspace.Thing:GetChildren()) do
    if v:IsA("Model") then
        local tracksettings = TrackRenderer.newsettings()
        tracksettings.TrackLength = 1
        tracksettings.TrackModel = game.ReplicatedStorage.Tracks.SimpleTrack
        tracksettings.SeperateActor = false
        local track = TrackRenderer.new(tracksettings, v:GetChildren())
        
        track:Render()
        track:SetSpeed(0.05)
        table.insert(tracks, track)
    end
end

--Commands for testing
local client_commands = {
    ["/speed"] = function(speed)
        local newSpeed = tonumber(speed)
        if newSpeed then
            for _, track in ipairs(tracks) do
                if track and track.SetSpeed then
                    track:SetSpeed(newSpeed)
                end
            end
        end
    end,

    ["/render"] = function()
       for _, v in ipairs(tracks) do
            v:Render()
       end
    end,

    ["/stoprendering"] = function()
       for _, v in ipairs(tracks) do
            v:StopRendering()
            print("stop?")
       end
    end,
}

game.ReplicatedStorage.Events.ev.OnClientEvent:Connect(function(command, ...)
    if client_commands[command] then
        client_commands[command](...)
    end
end)