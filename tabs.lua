local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")
local TABS_DIR   = "mjs/terminal/tabs/"
local ASSET_DIR  = "mjs/terminal/assets/"
local MAX_TABS   = 12
local TAB_SIZE   = 36
local TAB_GAP    = 4
local TAB_PAD    = 3
local PANEL_W    = TAB_SIZE + TAB_PAD * 2 + 2
local HIDE_DELAY = 3
local SLIDE_TIME = 0.25
local function ensureDir()
    pcall(makefolder, "mjs")
    pcall(makefolder, "mjs/terminal")
    pcall(makefolder, TABS_DIR)
end

local function saveMeta(id, name, icon)
    ensureDir()
    local ok = pcall(writefile, TABS_DIR .. id .. ".json",
        HttpService:JSONEncode({ name = name, icon = icon }))
    return ok
end

local function loadMeta(id)
    local ok, raw = pcall(readfile, TABS_DIR .. id .. ".json")
    if not ok then return nil end
    local ok2, t = pcall(HttpService.JSONDecode, HttpService, raw)
    return ok2 and t or nil
end

local function deleteMeta(id)
    pcall(delfile, TABS_DIR .. id .. ".json")
end

local function listSaved()
    local ok, files = pcall(listfiles, TABS_DIR)
    if not ok then return {} end
    local result = {}
    for _, f in ipairs(files) do
        local id = f:match("([^/\\]+)%.json$")
        if id then table.insert(result, id) end
    end
    table.sort(result)
    return result
end

local function assetImg(name)
    local ok, id = pcall(getcustomasset, ASSET_DIR .. name)
    return ok and id or ""
end
local defaultTabImg   = assetImg("tab.png")
local createTabImg    = assetImg("create-tab.png")
local tabs         = {}
local activeTabId  = nil
local contextMenu  = nil
local panelVisible = true
local hideTimer    = nil
local Wrapper, ScreenGui, uiFont, termFont
local onTabSwitch
local Panel
local TabList
local CreateBtn
local function buildPanel()
    Panel = Instance.new("Frame")
    Panel.Name                   = "TabPanel"
    Panel.Size                   = UDim2.new(0, PANEL_W, 1, 0)
    Panel.Position               = UDim2.new(1, 0, 0, 0)
    Panel.BackgroundColor3       = Color3.fromHex("#111111")
    Panel.BackgroundTransparency = 0
    Panel.BorderSizePixel        = 0
    Panel.ZIndex                 = 8
    Panel.ClipsDescendants       = true
    Panel.Parent                 = Wrapper
    do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = Panel end

    TabList = Instance.new("ScrollingFrame")
    TabList.Name                 = "TabList"
    TabList.Size                 = UDim2.new(1, 0, 1, -(TAB_SIZE + TAB_GAP + TAB_PAD))
    TabList.Position             = UDim2.new(0, 0, 0, TAB_PAD)
    TabList.BackgroundTransparency = 1
    TabList.BorderSizePixel      = 0
    TabList.ScrollBarThickness   = 0
    TabList.AutomaticCanvasSize  = Enum.AutomaticSize.Y
    TabList.CanvasSize           = UDim2.new(0,0,0,0)
    TabList.ClipsDescendants     = true
    TabList.ZIndex               = 9
    TabList.Parent               = Panel

    do
        local l = Instance.new("UIListLayout")
        l.SortOrder = Enum.SortOrder.LayoutOrder
        l.Padding   = UDim.new(0, TAB_GAP)
        l.HorizontalAlignment = Enum.HorizontalAlignment.Center
        l.Parent    = TabList
    end

    CreateBtn = Instance.new("ImageButton")
    CreateBtn.Name               = "CreateBtn"
    CreateBtn.Size               = UDim2.new(0, TAB_SIZE, 0, TAB_SIZE)
    CreateBtn.Position           = UDim2.new(0.5, -TAB_SIZE/2, 1, -(TAB_SIZE + TAB_PAD))
    CreateBtn.BackgroundColor3   = Color3.fromHex("#1a1a1a")
    CreateBtn.BorderSizePixel    = 0
    CreateBtn.Image              = createTabImg
    CreateBtn.ZIndex             = 9
    CreateBtn.Parent             = Panel
    do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,4); c.Parent = CreateBtn end

    if createTabImg == "" then
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
        lbl.Text = "+"; lbl.TextColor3 = Color3.fromHex("#666666")
        lbl.TextSize = 16; lbl.ZIndex = 10; lbl.Parent = CreateBtn
    end

    CreateBtn.MouseButton1Click:Connect(function()
        createTab()
    end)
end

local function showPanel()
    panelVisible = true
    TweenService:Create(Panel, TweenInfo.new(SLIDE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(1, -PANEL_W, 0, 0)
    }):Play()
end

local function hidePanel()
    if contextMenu then return end
    panelVisible = false
    TweenService:Create(Panel, TweenInfo.new(SLIDE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(1, 0, 0, 0)
    }):Play()
end

local function resetHideTimer()
    if hideTimer then
        task.cancel(hideTimer)
        hideTimer = nil
    end
    hideTimer = task.delay(HIDE_DELAY, function()
        if not contextMenu then
            hidePanel()
        end
    end)
end

local function startHoverDetection()
    RunService = game:GetService("RunService")
    RunService.Heartbeat:Connect(function()
        if not Panel or not Panel.Parent then return end
        local mouse = UserInputService:GetMouseLocation()
        local abs   = Panel.AbsolutePosition
        local size  = Panel.AbsoluteSize
        local triggerX = Wrapper.AbsolutePosition.X + Wrapper.AbsoluteSize.X - PANEL_W - 20
        local inArea = mouse.X > triggerX
            and mouse.Y > Wrapper.AbsolutePosition.Y
            and mouse.Y < Wrapper.AbsolutePosition.Y + Wrapper.AbsoluteSize.Y

        if inArea and not panelVisible then
            showPanel()
            if hideTimer then task.cancel(hideTimer); hideTimer = nil end
        elseif not inArea and panelVisible then
            if not hideTimer then
                resetHideTimer()
            end
        end
    end)
end

local function closeContextMenu()
    if contextMenu then
        contextMenu:Destroy()
        contextMenu = nil
    end
end

local function openContextMenu(tabData, tabFrame)
    closeContextMenu()

    local menu = Instance.new("Frame")
    menu.Name                = "ContextMenu"
    menu.Size                = UDim2.new(0, 110, 0, 68)
    local px = Panel.AbsolutePosition.X - Wrapper.AbsolutePosition.X - 114
    local py = tabFrame.AbsolutePosition.Y - Wrapper.AbsolutePosition.Y
    menu.Position            = UDim2.new(0, px, 0, py)
    menu.BackgroundColor3    = Color3.fromHex("#1e1e1e")
    menu.BorderSizePixel     = 0
    menu.ZIndex              = 20
    menu.Parent              = Wrapper
    do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = menu end

    local function makeField(placeholder, currentVal, yPos)
        local box = Instance.new("TextBox")
        box.Size             = UDim2.new(1, -8, 0, 24)
        box.Position         = UDim2.new(0, 4, 0, yPos)
        box.BackgroundColor3 = Color3.fromHex("#2a2a2a")
        box.BorderSizePixel  = 0
        box.Text             = currentVal ~= placeholder and currentVal or ""
        box.PlaceholderText  = placeholder
        box.TextColor3       = Color3.fromHex("#e0e0e0")
        box.PlaceholderColor3 = Color3.fromHex("#555555")
        box.TextSize         = 11
        box.ClearTextOnFocus = false
        box.ZIndex           = 21
        box.Parent           = menu
        do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,4); c.Parent = box end
        return box
    end

    local nameBox = makeField("Name", tabData.name, 4)
    local iconBox = makeField("Icon", tabData.icon, 34)

    local function applyChanges()
        local newName = nameBox.Text ~= "" and nameBox.Text or tabData.name
        local newIcon = iconBox.Text ~= "" and iconBox.Text or tabData.icon
        tabData.name = newName
        tabData.icon = newIcon
        if tabData.iconImg then
            local img = assetImg(newIcon)
            tabData.iconImg.Image = img ~= "" and img or defaultTabImg
        end
        saveMeta(tabData.id, newName, newIcon)
    end

    nameBox.FocusLost:Connect(function() applyChanges() end)
    iconBox.FocusLost:Connect(function() applyChanges() end)
    contextMenu = menu
    local conn
    conn = UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local mx, my = input.Position.X, input.Position.Y
            local mp = menu.AbsolutePosition
            local ms = menu.AbsoluteSize
            if mx < mp.X or mx > mp.X + ms.X or my < mp.Y or my > mp.Y + ms.Y then
                applyChanges()
                closeContextMenu()
                conn:Disconnect()
            end
        end
    end)
end

local function buildTabFrame(tabData)
    local outer = Instance.new("Frame")
    outer.Name               = "Tab_" .. tabData.id
    outer.Size               = UDim2.new(0, TAB_SIZE + TAB_PAD*2, 0, TAB_SIZE + TAB_PAD*2)
    outer.BackgroundColor3   = Color3.fromHex("#111111")
    outer.BorderSizePixel    = 0
    outer.ZIndex             = 9
    outer.LayoutOrder        = tabData.order or 0
    outer.Parent             = TabList
    do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,5); c.Parent = outer end

    local stroke = Instance.new("UIStroke")
    stroke.Color     = Color3.fromHex("#ffffff")
    stroke.Thickness = 1
    stroke.Enabled   = false
    stroke.Parent    = outer

    local img = Instance.new("ImageLabel")
    img.Name               = "Icon"
    img.Size               = UDim2.new(1, -TAB_PAD*2, 1, -TAB_PAD*2)
    img.Position           = UDim2.new(0, TAB_PAD, 0, TAB_PAD)
    img.BackgroundTransparency = 1
    img.Image              = tabData.icon ~= "" and (assetImg(tabData.icon) ~= "" and assetImg(tabData.icon) or defaultTabImg) or defaultTabImg
    img.ZIndex             = 10
    img.Parent             = outer

    tabData.frame   = outer
    tabData.iconImg = img
    tabData.stroke  = stroke
    outer.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            switchTab(tabData.id)
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
            if UserInputService:IsKeyDown(Enum.KeyCode.F4) then
                closeTab(tabData.id)
            else
                openContextMenu(tabData, outer)
            end
        end
    end)

    return outer
end

local tabCounter = 0
function createTab(name, icon)
    if #tabs >= MAX_TABS then return nil end
    tabCounter += 1
    local id = "tab_" .. tabCounter
    local tabData = {
        id       = id,
        name     = name or ("Tab " .. tabCounter),
        icon     = icon or "tab.png",
        order    = tabCounter,
        outputLines = {},
        history     = {},
        histIdx     = 0,
        currentBuf  = "",
    }

    buildTabFrame(tabData)
    saveMeta(id, tabData.name, tabData.icon)
    table.insert(tabs, tabData)

    if not activeTabId then
        switchTab(id)
    end

    return tabData
end

function switchTab(id)
    if activeTabId and onTabSwitch then
        local current = getTabById(activeTabId)
        if current then
            current.outputLines = onTabSwitch("save")
        end
    end

    activeTabId = id
    for _, t in ipairs(tabs) do
        if t.stroke then
            t.stroke.Enabled = (t.id == id)
        end
    end
    local tabData = getTabById(id)
    if tabData and onTabSwitch then
        onTabSwitch("load", tabData)
    end
end

function closeTab(id)
    local idx
    for i, t in ipairs(tabs) do
        if t.id == id then idx = i; break end
    end
    if not idx then return end

    local tabData = tabs[idx]
    if tabData.frame then tabData.frame:Destroy() end
    deleteMeta(id)
    table.remove(tabs, idx)

    if activeTabId == id then
        activeTabId = nil
        if #tabs > 0 then
            switchTab(tabs[math.max(1, idx-1)].id)
        else
            createTab()
        end
    end
end

function getTabById(id)
    for _, t in ipairs(tabs) do
        if t.id == id then return t end
    end
    return nil
end

function getActiveTab()
    return getTabById(activeTabId)
end

local TabSystem = {
    init = function(refs)
        Wrapper   = refs.Wrapper
        ScreenGui = refs.ScreenGui
        uiFont    = refs.uiFont
        termFont  = refs.termFont
        onTabSwitch = refs.onTabSwitch
        buildPanel()
        startHoverDetection()
        local saved = listSaved()
        if #saved > 0 then
            for _, id in ipairs(saved) do
                local meta = loadMeta(id)
                if meta then
                    createTab(meta.name, meta.icon)
                end
            end
        else
            createTab("Terminal", "tab.png")
        end
        showPanel()
        resetHideTimer()
    end,

    createTab   = createTab,
    closeTab    = closeTab,
    switchTab   = switchTab,
    getActive   = getActiveTab,
    getAll      = function() return tabs end,
    showPanel   = showPanel,
    hidePanel   = hidePanel,
    getPanelW   = function() return PANEL_W end,
}

return TabSystem