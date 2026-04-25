local HttpService = game:GetService("HttpService")
local PREFS_PATH = "mjs/terminal/preferences.json"
local DEFAULTS = {
    nickname        = "nickname",
    Transparent     = 0,
    BackgroundImage = "",
    keybind_show    = "F5",
}

local Preferences = {}
Preferences.__index = Preferences

function Preferences.new()
    local self = setmetatable({}, Preferences)
    self.data  = {}
    for k, v in pairs(DEFAULTS) do self.data[k] = v end
    self._warns = {}
    return self
end

function Preferences:load()
    self._warns = {}
    local ok, raw = pcall(readfile, PREFS_PATH)
    if ok and raw and raw ~= "" then
        local ok2, t = pcall(HttpService.JSONDecode, HttpService, raw)
        if ok2 and type(t) == "table" then
            for k, v in pairs(t) do self.data[k] = v end
        else
            table.insert(self._warns, "preferences.json: invalid JSON, using defaults")
        end
    else
        self:save()
    end
    self:_validate()
    return self._warns
end

function Preferences:_validate()

    local t = tonumber(self.data.Transparent)
    if not t or t < 0 or t > 1.0 then
        table.insert(self._warns, "Invalid Transparent in preferences.json (0 - 1.0)")
        self.data.Transparent = 0
    else
        self.data.Transparent = t
    end

    local bg = tostring(self.data.BackgroundImage or "")
    if bg ~= "" and not bg:match("^rbxassetid://") then
        table.insert(self._warns, "Invalid BackgroundImage in preferences.json (rbxassetid)")
        self.data.BackgroundImage = ""
    end

    if type(self.data.keybind_show) ~= "string" or self.data.keybind_show == "" then
        self.data.keybind_show = "F5"
    end
end

function Preferences:save()
    pcall(writefile, PREFS_PATH, HttpService:JSONEncode(self.data))
end

function Preferences:get(key)
    return self.data[key]
end

function Preferences:set(key, val)
    self.data[key] = tonumber(val) or val
    local warns = {}
    if key == "Transparent" then
        local t = tonumber(self.data.Transparent)
        if not t or t < 0 or t > 1.0 then
            table.insert(warns, "Invalid Transparent in preferences.json (0 - 1.0)")
            self.data.Transparent = 0
        else
            self.data.Transparent = t
        end
    elseif key == "BackgroundImage" then
        local bg = tostring(self.data.BackgroundImage or "")
        if bg ~= "" and not bg:match("^rbxassetid://") then
            table.insert(warns, "Invalid BackgroundImage in preferences.json (rbxassetid)")
            self.data.BackgroundImage = ""
        end
    end
    self:save()
    return warns
end

return Preferences