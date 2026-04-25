local HttpService = game:GetService("HttpService")
local RAW_URL = "https://raw.githubusercontent.com/%s/%s/%s/%s"
local PkgManager = {}
local _cache = {}

-- Формат:
-- {
--   "name": "Pkg Name",
--   "author": "Author",
--   "package": "pkg.lua"
-- }

local function fetchPackageJson(author, repo, branch, folder)
    local path = (folder ~= "" and (folder .. "/") or "") .. "package.json"
    local url  = RAW_URL:format(author, repo, branch, path)
    local ok, raw = pcall(game.HttpGet, game, url, true)
    if not ok or raw:find("404") then
        return nil, "package.json not found at " .. url
    end
    local ok2, t = pcall(HttpService.JSONDecode, HttpService, raw)
    if not ok2 or type(t) ~= "table" then
        return nil, "package.json: invalid JSON"
    end
    if not t.package then
        return nil, "package.json: missing 'package' field"
    end
    return t, nil
end

local function parsePkgString(author, repoStr)
    local parts = {}
    for p in repoStr:gmatch("[^/]+") do table.insert(parts, p) end
    local repo   = parts[1] or repoStr
    local branch = parts[2] or "main"
    local folder = parts[3] or ""
    return author, repo, branch, folder
end

function PkgManager.fetch(author, repoStr)
    local repo, branch, folder = select(2, parsePkgString(author, repoStr))
    local parts = {}
    for p in repoStr:gmatch("[^/]+") do table.insert(parts, p) end
    repo   = parts[1] or repoStr
    branch = parts[2] or "main"
    folder = parts[3] or ""

    local cacheKey = author .. "/" .. repo .. "/" .. branch .. "/" .. folder
    if _cache[cacheKey] then return _cache[cacheKey], nil end

    local manifest, manifestErr = fetchPackageJson(author, repo, branch, folder)
    if not manifest then
        return nil, manifestErr
    end

    local entryPath = (folder ~= "" and (folder .. "/") or "") .. manifest.package
    local entryUrl  = RAW_URL:format(author, repo, branch, entryPath)
    local ok, src   = pcall(game.HttpGet, game, entryUrl, true)
    if not ok or src:find("404") then
        return nil, "entry file not found: " .. entryPath
    end

    local fn, err = loadstring(src)
    if not fn then
        return nil, "loadstring error: " .. tostring(err)
    end

    local result = fn()
    _cache[cacheKey] = result
    return result, nil
end

local writeLine
local su = {
    error = function(msg)
        if writeLine then writeLine("✗ " .. tostring(msg), Color3.fromHex("#ff5555")) end
    end,
    warn = function(msg)
        if writeLine then writeLine("⚠ " .. tostring(msg), Color3.fromHex("#ffaa33")) end
    end,
    print = function(msg)
        if writeLine then writeLine("  " .. tostring(msg), Color3.fromHex("#aaaaaa")) end
    end,
}

function PkgManager.injectWriteLine(fn)
    writeLine = fn
end

local assetsProxy = setmetatable({}, {
    __index = function(_, name)
        local res, _ = PkgManager.fetch("mcli", "assets")
        return (res and res[name]) or nil
    end
})

local appsProxy = setmetatable({}, {
    __index = function(_, appName)
        return function(opts)
            local app, err = PkgManager.fetch("mcli", appName)
            if app then
                if type(app) == "function" then app(opts)
                elseif type(app) == "table" and app.open then app.open(opts)
                else su.error("app has no entry: mcli/" .. appName) end
            else
                su.error("app not found: " .. tostring(err))
            end
        end
    end
})

local installProxy = setmetatable({}, {
    __index = function(_, author)
        return setmetatable({}, {
            __index = function(_, repoStr)
                local res, err = PkgManager.fetch(author, repoStr)
                if not res and err then
                    su.error(err)
                end
                return res
            end
        })
    end
})

getgenv().mcli = { su      = su, assets  = assetsProxy, apps    = appsProxy, install = installProxy,}

getgenv().mclient = getgenv().mcli 
PkgManager.su = su
return PkgManager