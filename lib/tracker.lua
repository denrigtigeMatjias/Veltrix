local HIT_URL = "https://countapi.mileshilliard.com/api/v1/hit/veltrix_hub"

local function track()
    task.spawn(function()
        pcall(function()
            game:HttpGet(HIT_URL)
        end)
    end)
end

return { track = track }
