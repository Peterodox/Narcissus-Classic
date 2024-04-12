local colors = {
    green = {r = 124, g = 197, b = 118},
    red = {r = 255, g = 80, b = 80},
    yellow = {r = 218, g = 199, b = 7},
    grey = {r = 128, g = 128, b = 128},
};

local function GetColorPresetRGB(name)
    if colors[name] then
        return colors[name].r/255, colors[name].g/255, colors[name].b/255
    else
        return 1, 1, 1
    end
end

NarciAPI.GetColorPresetRGB = GetColorPresetRGB;