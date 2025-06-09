--Just for testing
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local prefix = "/"

Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(msg)
        if msg:sub(1,1) == prefix then

            local arguments = msg:split(" ")
            local command = arguments[1]:lower()
            table.remove(arguments, 1)
			ReplicatedStorage.Events.ev:FireClient(player, command, table.unpack(arguments))
        end
    end)
end)