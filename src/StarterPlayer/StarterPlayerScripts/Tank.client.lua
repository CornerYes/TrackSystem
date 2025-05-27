
local TrackRenderer = require(game.ReplicatedStorage.Modules.TrackRenderer)

task.wait(1)
local Wheels = workspace.Track
local tracksettings = TrackRenderer.newsettings()
local track = TrackRenderer.new(tracksettings, Wheels:GetChildren())
track:Render()