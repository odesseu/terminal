local HttpService = game:GetService("HttpService")
local RAW_URL = "https://raw.githubusercontent.com/%s/%s/%s/%s"
local function httpGet(url)
    local ok, res = pcall(game.HttpGet, game, url, true)
    assert(ok, "mcli: http error: " .. tostring(res))
    return res
end

local function parseJSON(raw)
    local ok, t = pcall(HttpService.JSONDecode, HttpService, raw)
    assert(ok, "mcli: json parse error: " .. tostring(t))
    return t
end

local function parseTarget(author, target)
    local parts = {}
    for p in target:gmatch("[^/]+") do
        table.insert(parts, p)
    end

    local repo   = parts[1]
    local branch = parts[2] or "main"
    local folderParts = {}
    for i = 3, #parts do table.insert(folderParts, parts[i]) end
    local folder = #folderParts > 0 and table.concat(folderParts, "/") or ""

    assert(repo, "mcli: repo not specified")
    return { author = author, repo = repo, branch = branch, folder = folder }
end

local function pkgUrl(t, filename)
    local path = t.folder ~= "" and (t.folder .. "/" .. filename) or filename
    return RAW_URL:format(t.author, t.repo, t.branch, path)
end

local REQUIRED_FIELDS = { "name", "author", "package" }
local function fetchManifest(t)
    local url = pkgUrl(t, "package.json")
    local raw = httpGet(url)
    local manifest = parseJSON(raw)

    -- валидация полей
    for _, field in ipairs(REQUIRED_FIELDS) do
        assert(
            manifest[field] ~= nil,
            ("mcli: package.json missing field '%s' in %s/%s"):format(field, t.author, t.repo)
        )
    end

    return manifest
end

local _cache = {}
local function cacheKey(t)
    return t.author .. "/" .. t.repo .. "@" .. t.branch ..
           (t.folder ~= "" and ("/" .. t.folder) or "")
end

local function fetchPkg(author, target)
    local t   = parseTarget(author, target)
    local key = cacheKey(t)
    if _cache[key] then return _cache[key] end
    local manifest = fetchManifest(t)
    local entryUrl = pkgUrl(t, manifest.package)
    local src      = httpGet(entryUrl)
    local fn, err = loadstring(src)
    assert(fn, "mcli: loadstring error in " .. manifest.package .. ": " .. tostring(err))

    local result  = fn()
    _cache[key]   = result
    return result
end

local _writeLine = nil
local su = {
    error = function(msg)
        if _writeLine then _writeLine("✗ " .. tostring(msg), Color3.fromHex("#ff5555")) end
        warn("[mcli.su.error] " .. tostring(msg))
    end,
    warn = function(msg)
        if _writeLine then _writeLine("⚠ " .. tostring(msg), Color3.fromHex("#ffaa33")) end
        warn("[mcli.su.warn] " .. tostring(msg))
    end,
    print = function(msg)
        if _writeLine then _writeLine("  " .. tostring(msg), Color3.fromHex("#aaaaaa")) end
    end,
    _setWriter = function(fn)
        _writeLine = fn
    end,
}

local assetsProxy = setmetatable({}, {
    __index = function(_, name)
        local ok, pkg = pcall(fetchPkg, "mcli", "assets")
        return (ok and type(pkg) == "table" and pkg[name]) or nil
    end
})

local appsProxy = setmetatable({}, {
    __index = function(_, appName)
        return function(opts)
            local ok, app = pcall(fetchPkg, "mcli", appName)
            if ok then
                if     type(app) == "function"                    then app(opts)
                elseif type(app) == "table" and app.open          then app.open(opts)
                else   su.error("app has no entry: mcli/" .. appName) end
            else
                su.error("app not found: mcli/" .. appName)
            end
        end
    end
})

local installProxy = setmetatable({}, {
    __index = function(_, author)
        return setmetatable({}, {
            __index = function(_, target)
                return fetchPkg(author, target)
            end
        })
    end
})

getgenv().mcli = {
    su      = su,
    assets  = assetsProxy,
    apps    = appsProxy,
    install = installProxy,
    get = fetchPkg,
}

getgenv().mclient = getgenv().mcli 
return getgenv().mcli