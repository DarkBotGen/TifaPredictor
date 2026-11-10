-- Open accepts every account. Set to "Whitelist" and add numeric Roblox user IDs to restrict this build.
do
    local mode = "Open"
    local allowedUserIds = {
        -- [123456789] = true,
    }
    assert(mode == "Open" or mode == "Whitelist", "Unknown Predictor access mode")
    if mode == "Whitelist" then
        local player = game:GetService("Players").LocalPlayer
        if not player or not allowedUserIds[player.UserId] then
            warn("Predictor access denied")
            return
        end
    end
end
