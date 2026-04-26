-- mcli / ui.lua
-- Терминал GUI. Требует pkg-manager.lua (mcli глобал) уже загруженным.

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local HttpService      = game:GetService("HttpService")
local mcli = getgenv().mcli
assert(mcli, "ui.lua: pkg-manager.lua must be loaded first")
local MIN_W, MIN_H = 400, 200
local DEF_W, DEF_H = 900, 500
local TITLE_H      = 20
local BTN_SIZE     = 10
local BTN_MARGIN   = 6
local PREFS_PATH = "mjs/terminal/preferences.json"
local prefs = {
    nickname        = "nickname",
    Transparent     = 0,
    BackgroundImage = "",
    HideKeybind     = "F5",
}

local function validatePrefs()
    local warns = {}
    local t = tonumber(prefs.Transparent)
    if not t or t < 0 or t > 1.0 then
        table.insert(warns, "Invalid Transparent in preferences.json (0 - 1.0)")
        prefs.Transparent = 0
    else
        prefs.Transparent = t
    end

    local bg = tostring(prefs.BackgroundImage or "")
    if bg ~= "" and not bg:match("^rbxassetid://") then
        table.insert(warns, "Invalid BackgroundImage in preferences.json (rbxassetid)")
        prefs.BackgroundImage = ""
    end

    local validKeys = {
        F1=true,F2=true,F3=true,F4=true,F5=true,F6=true,
        F7=true,F8=true,F9=true,F10=true,F11=true,F12=true,
    }
    local hk = tostring(prefs.HideKeybind or "F5")
    if not validKeys[hk] then
        table.insert(warns, "Invalid HideKeybind in preferences.json (F1-F12)")
        prefs.HideKeybind = "F5"
    end

    return warns
end

local function loadPrefs()
    local ok, raw = pcall(readfile, PREFS_PATH)
    if ok and raw then
        local ok2, t = pcall(HttpService.JSONDecode, HttpService, raw)
        if ok2 then for k, v in pairs(t) do prefs[k] = v end end
    end
    return validatePrefs()
end

local function savePrefs()
    pcall(writefile, PREFS_PATH, HttpService:JSONEncode(prefs))
end

local startupWarns = loadPrefs()

local function loadFont(path)
    local ok, res = pcall(Font.new, "rbxasset://" .. path)
    return ok and res or Font.new(Enum.Font.Code)
end

local termFont = loadFont("mjs/terminal/assets/terminal.ttf")
local uiFont   = loadFont("mjs/terminal/assets/ui.ttf")

local function assetImg(name)
    local ok, id = pcall(getcustomasset, "mjs/terminal/assets/" .. name)
    return ok and id or ""
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "MClientTerminal"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent         = game:GetService("CoreGui")

local Wrapper = Instance.new("Frame")
Wrapper.Name                   = "Wrapper"
Wrapper.Size                   = UDim2.new(0, DEF_W, 0, DEF_H)
Wrapper.Position               = UDim2.new(0.5, -DEF_W/2, 0.5, -DEF_H/2)
Wrapper.BackgroundColor3       = Color3.fromHex("#111111")
Wrapper.BackgroundTransparency = prefs.Transparent
Wrapper.BorderSizePixel        = 0
Wrapper.ClipsDescendants       = true
Wrapper.Parent                 = ScreenGui
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = Wrapper end

local BgImage
if prefs.BackgroundImage ~= "" then
    BgImage = Instance.new("ImageLabel")
    BgImage.Size = UDim2.new(1,0,1,0); BgImage.BackgroundTransparency = 1
    BgImage.Image = prefs.BackgroundImage; BgImage.ScaleType = Enum.ScaleType.Crop
    BgImage.ZIndex = 0; BgImage.Parent = Wrapper
end

local TitleClip = Instance.new("Frame")
TitleClip.Size                   = UDim2.new(1, 0, 0, TITLE_H)
TitleClip.BackgroundTransparency = 1
TitleClip.ClipsDescendants       = true
TitleClip.ZIndex                 = 5
TitleClip.Parent                 = Wrapper

local TitleBar = Instance.new("Frame")
TitleBar.Size                   = UDim2.new(1, 0, 0, TITLE_H + 20)
TitleBar.BackgroundColor3       = Color3.fromHex("#1a1a1a")
TitleBar.BackgroundTransparency = math.min(1, prefs.Transparent + 0.1)
TitleBar.BorderSizePixel        = 0
TitleBar.ZIndex                 = 5
TitleBar.Parent                 = TitleClip
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = TitleBar end

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size                   = UDim2.new(1, -(BTN_SIZE * 2 + BTN_MARGIN * 3 + 8), 0, TITLE_H)
TitleLabel.Position               = UDim2.new(0, 7, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text                   = "Terminal"
TitleLabel.TextColor3             = Color3.fromHex("#888888")
TitleLabel.TextSize               = 10
TitleLabel.FontFace               = uiFont
TitleLabel.TextXAlignment         = Enum.TextXAlignment.Left
TitleLabel.TextYAlignment         = Enum.TextYAlignment.Center
TitleLabel.ZIndex                 = 6
TitleLabel.Parent                 = TitleBar

local function makeBtn(name, asset, rightOffset)
    local btn = Instance.new("ImageButton")
    btn.Name                   = name
    btn.Size                   = UDim2.new(0, BTN_SIZE, 0, BTN_SIZE)
    btn.Position               = UDim2.new(1, rightOffset, 0, (TITLE_H - BTN_SIZE) / 2)
    btn.BackgroundTransparency = 1
    btn.Image                  = assetImg(asset)
    btn.ZIndex                 = 6
    btn.Parent                 = TitleBar
    if btn.Image == "" then
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
        lbl.Text = (name == "CloseBtn") and "×" or "−"
        lbl.TextColor3 = Color3.fromHex("#666666"); lbl.TextSize = 11
        lbl.TextYAlignment = Enum.TextYAlignment.Center
        lbl.FontFace = uiFont; lbl.ZIndex = 7; lbl.Parent = btn
    end
    return btn
end

local CloseBtn = makeBtn("CloseBtn", "close.png", -(BTN_MARGIN + BTN_SIZE))
local HideBtn  = makeBtn("HideBtn",  "hide.png",  -(BTN_MARGIN * 2 + BTN_SIZE * 2))
local ResizeBtn = Instance.new("ImageButton")
ResizeBtn.Size               = UDim2.new(0, 14, 0, 14)
ResizeBtn.Position           = UDim2.new(1, -16, 1, -16)
ResizeBtn.BackgroundTransparency = 1
ResizeBtn.Image              = assetImg("resize.png")
ResizeBtn.ZIndex             = 10
ResizeBtn.Parent             = Wrapper
if ResizeBtn.Image == "" then
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
    lbl.Text = "⤡"; lbl.TextColor3 = Color3.fromHex("#444444")
    lbl.TextSize = 11; lbl.FontFace = uiFont; lbl.ZIndex = 11; lbl.Parent = ResizeBtn
end


local OutputFrame = Instance.new("ScrollingFrame")
OutputFrame.Size                 = UDim2.new(1, 0, 1, -TITLE_H)
OutputFrame.Position             = UDim2.new(0, 0, 0, TITLE_H)
OutputFrame.BackgroundTransparency = 1
OutputFrame.BorderSizePixel      = 0
OutputFrame.ScrollBarThickness   = 2
OutputFrame.ScrollBarImageColor3 = Color3.fromHex("#2a2a2a")
OutputFrame.ClipsDescendants     = true
OutputFrame.AutomaticCanvasSize  = Enum.AutomaticSize.Y
OutputFrame.CanvasSize           = UDim2.new(0, 0, 0, 0)
OutputFrame.Parent               = Wrapper

do
    local l = Instance.new("UIListLayout")
    l.SortOrder = Enum.SortOrder.LayoutOrder; l.Padding = UDim.new(0, 0); l.Parent = OutputFrame
    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0, 7); p.PaddingRight = UDim.new(0, 7)
    p.PaddingTop = UDim.new(0, 4); p.PaddingBottom = UDim.new(0, 4)
    p.Parent = OutputFrame
end


local lineCount = 0
local function writeLine(text, color)
    lineCount += 1
    local lbl = Instance.new("TextLabel")
    lbl.Name               = "L" .. lineCount
    lbl.Size               = UDim2.new(1, 0, 0, 0)
    lbl.AutomaticSize      = Enum.AutomaticSize.Y
    lbl.BackgroundTransparency = 1
    lbl.Text               = text
    lbl.TextColor3         = color or Color3.fromHex("#e0e0e0")
    lbl.TextSize           = 12
    lbl.FontFace           = termFont
    lbl.TextXAlignment     = Enum.TextXAlignment.Left
    lbl.TextWrapped        = true
    lbl.LayoutOrder        = lineCount
    lbl.TextTransparency   = 1
    lbl.Parent             = OutputFrame

    TweenService:Create(lbl, TweenInfo.new(0.1, Enum.EasingStyle.Linear), {
        TextTransparency = 0
    }):Play()

    task.defer(function()
        OutputFrame.CanvasPosition = Vector2.new(
            0, math.max(0, OutputFrame.AbsoluteCanvasSize.Y - OutputFrame.AbsoluteSize.Y)
        )
    end)

    return lbl
end

mcli.su._setWriter(writeLine)

local InputRow = Instance.new("Frame")
InputRow.Name               = "InputRow"
InputRow.Size               = UDim2.new(1, 0, 0, 18)
InputRow.BackgroundTransparency = 1
InputRow.LayoutOrder        = 999999
InputRow.ZIndex             = 4
InputRow.Parent             = OutputFrame

local Prefix = Instance.new("TextLabel")
Prefix.Size              = UDim2.new(0, 0, 1, 0)
Prefix.AutomaticSize     = Enum.AutomaticSize.X
Prefix.Position          = UDim2.new(0, 0, 0, 0)
Prefix.BackgroundTransparency = 1
Prefix.Text              = prefs.nickname .. ": "
Prefix.TextColor3        = Color3.fromHex("#555555")
Prefix.TextSize          = 12
Prefix.FontFace          = termFont
Prefix.TextXAlignment    = Enum.TextXAlignment.Left
Prefix.TextYAlignment    = Enum.TextYAlignment.Center
Prefix.ZIndex            = 5
Prefix.Parent            = InputRow

local InputBox = Instance.new("TextBox")
InputBox.BackgroundTransparency = 1
InputBox.Text              = ""
InputBox.PlaceholderText   = ""
InputBox.TextColor3        = Color3.fromHex("#e0e0e0")
InputBox.TextSize          = 12
InputBox.FontFace          = termFont
InputBox.TextXAlignment    = Enum.TextXAlignment.Left
InputBox.TextYAlignment    = Enum.TextYAlignment.Center
InputBox.ClearTextOnFocus  = false
InputBox.ZIndex            = 5
InputBox.Parent            = InputRow

local function updateInputLayout()
    local pw = Prefix.AbsoluteSize.X
    InputBox.Position = UDim2.new(0, pw, 0, 0)
    InputBox.Size     = UDim2.new(1, -pw, 1, 0)
end
Prefix:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateInputLayout)
task.defer(updateInputLayout)

local function bumpInputRow()
    InputRow.LayoutOrder = lineCount + 1
end

local SPINNER = {"⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏"}
local function spinnerLine(text)
    local lbl  = writeLine(SPINNER[1] .. " " .. text, Color3.fromHex("#777777"))
    local idx  = 1
    local conn = RunService.Heartbeat:Connect(function()
        idx = (idx % #SPINNER) + 1
        lbl.Text = SPINNER[idx] .. " " .. text
    end)
    return function(result, color)
        conn:Disconnect()
        lbl.Text = result
        lbl.TextColor3 = color or Color3.fromHex("#e0e0e0")
    end
end

local history    = {}
local histIdx    = 0
local currentBuf = ""
local function historyUp()
    if #history == 0 then return end
    if histIdx == 0 then
        currentBuf = InputBox.Text
    end
    histIdx = math.min(histIdx + 1, #history)
    InputBox.Text = history[#history - histIdx + 1]
    InputBox.CursorPosition = #InputBox.Text + 1
end

local function historyDown()
    if histIdx == 0 then return end
    histIdx = histIdx - 1
    if histIdx == 0 then
        InputBox.Text = currentBuf
    else
        InputBox.Text = history[#history - histIdx + 1]
    end
    InputBox.CursorPosition = #InputBox.Text + 1
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if not InputBox:IsFocused() then return end
    if input.KeyCode == Enum.KeyCode.Up then
        historyUp()
    elseif input.KeyCode == Enum.KeyCode.Down then
        historyDown()
    end
end)

local function applyPrefs()
    Wrapper.BackgroundTransparency  = prefs.Transparent
    TitleBar.BackgroundTransparency = math.min(1, prefs.Transparent + 0.1)
    Prefix.Text = prefs.nickname .. ": "
    task.defer(updateInputLayout)

    if prefs.BackgroundImage ~= "" then
        if not BgImage then
            BgImage = Instance.new("ImageLabel")
            BgImage.Size = UDim2.new(1,0,1,0); BgImage.BackgroundTransparency = 1
            BgImage.ScaleType = Enum.ScaleType.Crop; BgImage.ZIndex = 0; BgImage.Parent = Wrapper
        end
        BgImage.Image = prefs.BackgroundImage
    elseif BgImage then
        BgImage:Destroy(); BgImage = nil
    end
end

local commands = {}
commands["install"] = function(args)
    local author, target = args[1], args[2]
    if not author or not target then
        writeLine("  usage: install <author> <repo[/branch[/folder]]>", Color3.fromHex("#ff5555"))
        return
    end
    bumpInputRow()
    local stop = spinnerLine("installing " .. author .. "/" .. target)
    bumpInputRow()
    task.spawn(function()
        local ok, err = pcall(mcli.get, author, target)
        if ok then
            stop("✓ installed " .. author .. "/" .. target, Color3.fromHex("#66ff88"))
        else
            stop("✗ " .. tostring(err), Color3.fromHex("#ff5555"))
        end
        bumpInputRow()
    end)
end

commands["termpref"] = function(args)
    local sub = args[1]
    if not sub then
        local ok, app = pcall(mcli.get, "mcli", "notepad")
        if ok then
            if type(app) == "function" then app({ filepath = PREFS_PATH })
            elseif type(app) == "table" and app.open then app.open({ filepath = PREFS_PATH }) end
        else
            writeLine("  mcli/notepad not installed — use: termpref edit <key> <value>", Color3.fromHex("#777777"))
        end
        return
    end

    if sub == "edit" then
        local key, val = args[2], args[3]
        if not key or not val then
            writeLine("  usage: termpref edit <key> <value>", Color3.fromHex("#ff5555"))
            return
        end
        prefs[key] = tonumber(val) or val
        local warns = validatePrefs()
        for _, w in ipairs(warns) do writeLine("⚠ " .. w, Color3.fromHex("#ffaa33")) end
        savePrefs()
        applyPrefs()
        writeLine("  " .. key .. " = " .. tostring(prefs[key]), Color3.fromHex("#66aaff"))
    else
        writeLine("  usage: termpref [edit <key> <value>]", Color3.fromHex("#777777"))
    end
end

commands["clear"] = function()
    for _, c in ipairs(OutputFrame:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
    lineCount = 0
    bumpInputRow()
end

commands["help"] = function()
    for _, l in ipairs({
        "  install <author> <repo[/branch[/folder]]>  — установить пакет",
        "  termpref                                   — открыть preferences",
        "  termpref edit <key> <value>                — изменить настройку",
        "    nickname        — имя в строке ввода",
        "    Transparent     — прозрачность фона (0 - 1.0)",
        "    BackgroundImage — rbxassetid://...",
        "    HideKeybind     — клавиша показа/скрытия (F1-F12)",
        "  clear                                      — очистить терминал",
        "  ↑ / ↓                                      — история команд",
    }) do writeLine(l, Color3.fromHex("#555555")) end
end

local function runCommand(raw)
    if raw == "" then return end
    if #history == 0 or history[#history] ~= raw then
        table.insert(history, raw)
    end
    histIdx    = 0
    currentBuf = ""

    writeLine(prefs.nickname .. ": " .. raw, Color3.fromHex("#dddddd"))
    bumpInputRow()

    local args = {}
    for w in raw:gmatch("%S+") do table.insert(args, w) end
    local cmd = table.remove(args, 1):lower()
    if commands[cmd] then
        commands[cmd](args)
    else
        writeLine("  unknown: " .. cmd, Color3.fromHex("#ff5555"))
    end
    bumpInputRow()
end

InputBox.FocusLost:Connect(function(enter)
    if enter then
        local t = InputBox.Text
        InputBox.Text = ""
        runCommand(t)
        task.defer(function() InputBox:CaptureFocus() end)
    end
end)

local dragging, dragStart, startPos
TitleBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = i.Position; startPos = Wrapper.Position
    end
end)

UserInputService.InputChanged:Connect(function(i)
    if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = i.Position - dragStart
        local targetPos = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y
        )
        TweenService:Create(Wrapper, TweenInfo.new(0.04, Enum.EasingStyle.Linear), {
            Position = targetPos
        }):Play()
    end
end)

UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

local resizing, resizeStart, startSize
ResizeBtn.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        resizing = true; resizeStart = i.Position
        startSize = Vector2.new(Wrapper.AbsoluteSize.X, Wrapper.AbsoluteSize.Y)
    end
end)

UserInputService.InputChanged:Connect(function(i)
    if resizing and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = i.Position - resizeStart
        Wrapper.Size = UDim2.new(
            0, math.max(MIN_W, startSize.X + d.X),
            0, math.max(MIN_H, startSize.Y + d.Y)
        )
    end
end)

UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then resizing = false end
end)

CloseBtn.MouseButton1Click:Connect(function()
    TweenService:Create(Wrapper, TweenInfo.new(0.15), {
        Size = UDim2.new(0, Wrapper.AbsoluteSize.X, 0, 0)
    }):Play()
    task.delay(0.2, function() ScreenGui:Destroy() end)
end)

local minimized   = false
local savedSize   = Vector2.new(DEF_W, DEF_H)
local function setMinimized(state)
    minimized = state
    OutputFrame.Visible = not minimized
    if minimized then
        savedSize = Vector2.new(Wrapper.AbsoluteSize.X, Wrapper.AbsoluteSize.Y)
        TweenService:Create(Wrapper, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            Size = UDim2.new(0, savedSize.X, 0, TITLE_H)
        }):Play()
    else
        TweenService:Create(Wrapper, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            Size = UDim2.new(0, savedSize.X, 0, savedSize.Y)
        }):Play()
        task.delay(0.15, function() InputBox:CaptureFocus() end)
    end
end

HideBtn.MouseButton1Click:Connect(function()
    setMinimized(not minimized)
end)

-- Keybind скрытия/показа из preferences
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    local keyName = input.KeyCode.Name  -- "F5", "F6" итд
    if keyName == prefs.HideKeybind then
        setMinimized(not minimized)
    end
end)

writeLine("Terminal  —  'help' for commands", Color3.fromHex("#3a3a3a"))
for _, w in ipairs(startupWarns) do
    writeLine("⚠ " .. w, Color3.fromHex("#ffaa33"))
end
bumpInputRow()
task.defer(function() InputBox:CaptureFocus() end)