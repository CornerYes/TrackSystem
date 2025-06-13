# Procedural Tank Track System

A Roblox module for generating and animating procedural tank tracks based on wheel positions and runtime parameters. This system is designed for flexibility and performance, making it easy to add realistic, moving treads to your vehicles.

## Features
- Procedural generation of tank tracks from wheel layout
- Real-time animation of treads based on speed and direction
- Modular, reusable code structure
- Clean-up and resource management

## Installation
1. Copy the contents of the `src/ReplicatedStorage/Modules/TrackRenderer/TrackActor/TrackPool` folder into your Roblox project.
2. Require the main module in your client scripts as needed.

## Usage
1. Prepare your tank model with wheels (BaseParts) named in the format `1`, `2`, ..., or `1_curve`, `2_curve`, etc.
2. Provide a track model (the mesh/part to be used for each tread segment).
3. Use the system's API to initialize and control the tracks:

```lua
local TrackPool = require(path.to.TrackPool)

-- Example initialization (pseudo-code):
local trackSettings = {
    TrackLength = 2, -- Length of each tread segment
    TrackModel = myTrackPartModel,
}

local wheels = {wheel1, wheel2, wheel3, ...}
local track = TrackPool.new(trackSettings)
track:Init(wheels)
track.IsActive = true
track.Speed = 10
```

## API
- `TrackPool.new(trackSettings)` — Create a new track instance.
- `track:Init(wheels)` — Initialize with an array of wheel BaseParts.
- `track.IsActive` — Set to `true` to animate, `false` to pause.
- `track.Speed` — Set the speed of the treads.
- `track:destroying()` — Clean up and destroy all track parts.

## Events
- The system is designed to work with Roblox Actor messaging for multiplayer/networked games.

## License
MIT License (or specify your own)

---
Feel free to modify this documentation to better fit your project's needs!
