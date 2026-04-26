local Base      = "https://raw.githubusercontent.com/odesseu/terminal/master/"
local AssetFolder = "mjs/terminal/assets/"
local function downloadFile(url, localPath)
    if isfile(localPath) then return end
    local ok, data = pcall(game.HttpGet, game, url, true)
    if ok then writefile(localPath, data)
    else warn("mcli: failed to download: " .. url) end
end

local function loadURL(url)
    local fn = loadstring(game:HttpGet(url, true))
    assert(fn, "mcli: parse error: " .. url)
    return fn()
end

pcall(makefolder, "mjs")
pcall(makefolder, "mjs/terminal")
pcall(makefolder, AssetFolder)
downloadFile(Base .. "assets/terminal.ttf", AssetFolder .. "terminal.ttf")
downloadFile(Base .. "assets/ui.ttf",       AssetFolder .. "ui.ttf")
downloadFile(Base .. "assets/close.png",    AssetFolder .. "close.png")
downloadFile(Base .. "assets/hide.png",     AssetFolder .. "hide.png")
downloadFile(Base .. "assets/resize.png",   AssetFolder .. "resize.png")
loadURL(Base .. "pkg-manager.lua")
loadURL(Base .. "ui.lua")