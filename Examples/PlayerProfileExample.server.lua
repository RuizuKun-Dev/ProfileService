local ProfileTemplate = {
    Cash = 0,
    Items = {},
    LogInTimes = 0,
}
local ProfileService = require(game.ServerScriptService.ProfileService)
local Players = game:GetService('Players')
local GameProfileStore = ProfileService.GetProfileStore('PlayerData', ProfileTemplate)
local Profiles = {}

local function GiveCash(profile, amount)
    if profile.Data.Cash == nil then
        profile.Data.Cash = 0
    end

    profile.Data.Cash = profile.Data.Cash + amount
end
local function DoSomethingWithALoadedProfile(player, profile)
    profile.Data.LogInTimes = profile.Data.LogInTimes + 1

    print(player.Name .. ' has logged in ' .. tostring(profile.Data.LogInTimes) .. ' time' .. ((profile.Data.LogInTimes > 1) and 's' or ''))
    GiveCash(profile, 100)
    print(player.Name .. ' owns ' .. tostring(profile.Data.Cash) .. ' now!')
end
local function PlayerAdded(player)
    local profile = GameProfileStore:LoadProfileAsync('Player_' .. player.UserId)

    if profile ~= nil then
        profile:AddUserId(player.UserId)
        profile:Reconcile()
        profile:ListenToRelease(function()
            Profiles[player] = nil

            player:Kick()
        end)

        if player:IsDescendantOf(Players) == true then
            Profiles[player] = profile

            DoSomethingWithALoadedProfile(player, profile)
        else
            profile:Release()
        end
    else
        player:Kick()
    end
end

for _, player in ipairs(Players:GetPlayers())do
    task.spawn(PlayerAdded, player)
end

Players.PlayerAdded:Connect(PlayerAdded)
Players.PlayerRemoving:Connect(function(player)
    local profile = Profiles[player]

    if profile ~= nil then
        profile:Release()
    end
end)
