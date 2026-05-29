-- init.lua
-- Created by: RedFrog
-- Original creation date: 3/04/2023
-- Version: 0.19
-- 0.19: Bone Chips (NEC/SHD) via Guild Lobby; reagent buy target capped at 20 (axes stack 100 on EMU)
-- 0.18: Player standing position for nav (not NPC coords); reagent buying (MAG/ENC/BER); autorun arg for group mode
-- 0.17: Group mode sends DanNet commands at each buy step (nav/target/open/buy/close) - no script needed on members
-- 0.16: Group toggle (animated grey-to-green, right-aligned on Run line); DanNet /dgge fires group on Run
-- 0.15: HuntBuddy themes (Burnt/Lime/MonoChrome/Grape/Red); StyleVar rounding for MonoChrome; full AStone 3-element inset panel
-- 0.14: Full per-theme ImGuiCol coverage (buttons/frames/title/separators); DrawList inset panel behind inventory counts
-- 0.13: Theme dropdown (Default/Rustic Tavern/Turnip Purple/Root Cellar/River Market) with live preview; saved to config
-- 0.12: Fix Save crash (ImGui style stack corruption — capture dirty flag before button, use same value for push and pop)
-- 0.11: Save button blinks amber on unsaved changes; Default button (right-aligned, light red) resets to Perago/Turnip/Water Flask
-- 0.10: Vendor Pick button inline (captures name + coords from target); Target stacks input wider; removed standalone Set from Target button
-- 0.9: Fix startup lag (removed os.execute/mkdir); merchant item picker buttons for food and drink
-- 0.8: GUI rewrite, dual EMU/Live support, configurable food/drink/vendor, stack-size-aware buying

local mq    = require('mq')
local imgui = require('ImGui')

local VERSION = '0.19'

-- State
local showUI   = true
local doRun    = false
local running  = false
local status   = 'Ready'
local groupMode = false
local groupAnim = 0.0

-- Config
local configFile = mq.configDir .. '/turnipbuy_settings.lua'

local defaults = {
    foodName       = 'Turnip',
    drinkName      = 'Water Flask',
    vendorName     = 'Perago Crotal',
    navY           = 14.27,
    navX           = 233.11,
    navZ           = -124.68,
    targetStacks   = 1,
    theme          = 'Default',
    reagentEnabled = false,
}

-- Reagent vendor standing positions (hardcoded — standard PoK on Live and EMU)
local REAGENT_VENDORS = {
    darius  = { name = 'Darius Gandril',      zone = 'poknowledge', navY =  52.24, navX = 1517.65, navZ = -124.68 },
    gaddi   = { name = 'Gaddi Buruca',         zone = 'poknowledge', navY = -83.84, navX =  810.87, navZ =    3.31 },
    bonechips = { name = 'A Vendor of Reagents', zone = 'guildlobby',  navY = 358.12, navX = -192.20, navZ =    0.09 },
}

local THEME_NAMES = { 'Default', 'Burnt', 'Lime', 'MonoChrome', 'Grape', 'Red' }
local THEMES = {
    ['Burnt'] = {
        colors = {
            { ImGuiCol.WindowBg,       0.000, 0.000, 0.000, 1.000 },
            { ImGuiCol.TitleBg,        0.000, 0.000, 0.000, 1.000 },
            { ImGuiCol.TitleBgActive,  0.055, 0.054, 0.053, 1.000 },
            { ImGuiCol.Button,         0.671, 0.348, 0.190, 0.400 },
            { ImGuiCol.ButtonHovered,  1.000, 0.582, 0.000, 1.000 },
            { ImGuiCol.ButtonActive,   0.980, 0.400, 0.060, 1.000 },
            { ImGuiCol.FrameBg,        0.249, 0.240, 0.230, 0.540 },
            { ImGuiCol.FrameBgHovered, 0.980, 0.690, 0.260, 0.400 },
            { ImGuiCol.Header,         0.980, 0.547, 0.260, 0.310 },
            { ImGuiCol.HeaderHovered,  0.980, 0.690, 0.260, 0.800 },
            { ImGuiCol.Separator,      1.000, 0.284, 0.000, 0.500 },
            { ImGuiCol.Border,         0.962, 0.470, 0.059, 0.500 },
            { ImGuiCol.PopupBg,        0.080, 0.080, 0.080, 0.940 },
        },
        accent = { 255, 72, 0, 180 },
    },
    ['Lime'] = {
        colors = {
            { ImGuiCol.WindowBg,       0.017, 0.133, 0.026, 1.000 },
            { ImGuiCol.TitleBg,        0.040, 0.040, 0.040, 1.000 },
            { ImGuiCol.TitleBgActive,  0.000, 0.000, 0.000, 1.000 },
            { ImGuiCol.Button,         0.176, 0.521, 0.052, 0.400 },
            { ImGuiCol.ButtonHovered,  0.103, 0.204, 0.071, 1.000 },
            { ImGuiCol.ButtonActive,   0.618, 0.980, 0.060, 1.000 },
            { ImGuiCol.FrameBg,        0.338, 0.621, 0.327, 0.540 },
            { ImGuiCol.FrameBgHovered, 0.697, 0.980, 0.260, 0.400 },
            { ImGuiCol.Header,         0.472, 0.980, 0.260, 0.310 },
            { ImGuiCol.HeaderHovered,  0.369, 0.980, 0.260, 0.800 },
            { ImGuiCol.Separator,      0.154, 0.905, 0.211, 0.500 },
            { ImGuiCol.Border,         0.376, 0.962, 0.059, 0.500 },
            { ImGuiCol.PopupBg,        0.080, 0.080, 0.080, 0.940 },
        },
        accent = { 40, 230, 55, 180 },
    },
    ['MonoChrome'] = {
        styles = {
            { ImGuiStyleVar.FrameRounding,     8 },
            { ImGuiStyleVar.WindowRounding,    8 },
            { ImGuiStyleVar.GrabRounding,      8 },
            { ImGuiStyleVar.ScrollbarRounding, 8 },
        },
        colors = {
            { ImGuiCol.WindowBg,       0.060, 0.060, 0.060, 0.848 },
            { ImGuiCol.TitleBg,        0.040, 0.040, 0.040, 1.000 },
            { ImGuiCol.TitleBgActive,  0.248, 0.253, 0.261, 1.000 },
            { ImGuiCol.Button,         0.376, 0.382, 0.389, 0.400 },
            { ImGuiCol.ButtonHovered,  0.036, 0.039, 0.043, 1.000 },
            { ImGuiCol.ButtonActive,   0.485, 0.499, 0.512, 1.000 },
            { ImGuiCol.FrameBg,        0.364, 0.368, 0.374, 0.540 },
            { ImGuiCol.FrameBgHovered, 0.636, 0.655, 0.678, 0.400 },
            { ImGuiCol.Header,         0.437, 0.444, 0.521, 0.310 },
            { ImGuiCol.HeaderHovered,  0.659, 0.674, 0.692, 0.800 },
            { ImGuiCol.Separator,      0.581, 0.581, 0.626, 0.500 },
            { ImGuiCol.Border,         0.430, 0.430, 0.500, 0.500 },
            { ImGuiCol.PopupBg,        0.080, 0.080, 0.080, 0.940 },
        },
        accent = { 148, 148, 160, 180 },
    },
    ['Grape'] = {
        colors = {
            { ImGuiCol.WindowBg,       0.017, 0.002, 0.047, 0.940 },
            { ImGuiCol.TitleBg,        0.103, 0.004, 0.194, 1.000 },
            { ImGuiCol.TitleBgActive,  0.354, 0.160, 0.480, 1.000 },
            { ImGuiCol.Button,         0.231, 0.102, 0.720, 0.400 },
            { ImGuiCol.ButtonHovered,  0.574, 0.260, 0.980, 1.000 },
            { ImGuiCol.ButtonActive,   0.479, 0.060, 0.980, 1.000 },
            { ImGuiCol.FrameBg,        0.263, 0.160, 0.480, 0.540 },
            { ImGuiCol.FrameBgHovered, 0.431, 0.260, 0.980, 0.400 },
            { ImGuiCol.Header,         0.570, 0.260, 0.980, 0.310 },
            { ImGuiCol.HeaderHovered,  0.643, 0.260, 0.980, 0.800 },
            { ImGuiCol.Separator,      0.322, 0.000, 1.000, 0.825 },
            { ImGuiCol.Border,         0.295, 0.153, 0.398, 0.500 },
            { ImGuiCol.PopupBg,        0.054, 0.012, 0.156, 0.940 },
        },
        accent = { 82, 0, 255, 180 },
    },
    ['Red'] = {
        colors = {
            { ImGuiCol.WindowBg,       0.000, 0.000, 0.000, 1.000 },
            { ImGuiCol.TitleBg,        0.000, 0.000, 0.000, 1.000 },
            { ImGuiCol.TitleBgActive,  0.055, 0.054, 0.053, 1.000 },
            { ImGuiCol.Button,         0.671, 0.190, 0.245, 0.400 },
            { ImGuiCol.ButtonHovered,  1.000, 0.582, 0.000, 1.000 },
            { ImGuiCol.ButtonActive,   0.980, 0.400, 0.060, 1.000 },
            { ImGuiCol.FrameBg,        0.249, 0.240, 0.230, 0.540 },
            { ImGuiCol.FrameBgHovered, 0.980, 0.690, 0.260, 0.400 },
            { ImGuiCol.Header,         0.943, 0.246, 0.103, 0.957 },
            { ImGuiCol.HeaderHovered,  0.980, 0.342, 0.260, 1.000 },
            { ImGuiCol.Separator,      1.000, 0.000, 0.125, 0.500 },
            { ImGuiCol.Border,         0.962, 0.059, 0.059, 0.500 },
            { ImGuiCol.PopupBg,        0.080, 0.080, 0.080, 0.940 },
        },
        accent = { 255, 0, 32, 180 },
    },
}

local settings = {}
for k, v in pairs(defaults) do settings[k] = v end

-- GUI temp vars for editable fields
local tmpFood   = settings.foodName
local tmpDrink  = settings.drinkName
local tmpVendor = settings.vendorName
local tmpNavY   = tostring(settings.navY)
local tmpNavX   = tostring(settings.navX)
local tmpNavZ   = tostring(settings.navZ)
local tmpStacks = settings.targetStacks
local tmpTheme  = settings.theme

-- Settings I/O

local function saveSettings()
    mq.pickle(configFile, settings)
end

local function hasUnsavedChanges()
    return tmpFood ~= settings.foodName
        or tmpDrink ~= settings.drinkName
        or tmpVendor ~= settings.vendorName
        or tmpStacks ~= settings.targetStacks
        or tmpTheme ~= settings.theme
        or (tonumber(tmpNavY) or settings.navY) ~= settings.navY
        or (tonumber(tmpNavX) or settings.navX) ~= settings.navX
        or (tonumber(tmpNavZ) or settings.navZ) ~= settings.navZ
end

local function syncTmpVars()
    tmpFood   = settings.foodName
    tmpDrink  = settings.drinkName
    tmpVendor = settings.vendorName
    tmpNavY   = tostring(settings.navY)
    tmpNavX   = tostring(settings.navX)
    tmpNavZ   = tostring(settings.navZ)
    tmpStacks = settings.targetStacks
    tmpTheme  = settings.theme
end

local function loadSettings()
    local loader = loadfile(configFile)
    if loader then
        local ok, result = pcall(loader)
        if ok and type(result) == 'table' then
            for k in pairs(defaults) do
                if result[k] ~= nil then settings[k] = result[k] end
            end
        end
    end
    -- Migrate: old configs stored NPC coords (11.0, 238.3) instead of player standing position
    if settings.navY == 11.0 and settings.navX == 238.3 then
        settings.navY = defaults.navY
        settings.navX = defaults.navX
        settings.navZ = defaults.navZ
        saveSettings()
    end
    syncTmpVars()
end

-- Helpers

local function tbPrint(msg)
    print(string.format("\ao[\agTurnipBuy\ao]\at %s", msg))
end

local function inPoK()
    return mq.TLO.Zone.ShortName() == 'poknowledge'
end

local function getCount(itemName)
    return mq.TLO.FindItemCount('=' .. itemName)() or 0
end

local function getStackSize(itemName)
    local sz = mq.TLO.FindItem('=' .. itemName).StackSize()
    return (sz and sz > 0) and sz or nil
end

local function getBerserkerAxeComponent()
    local level = mq.TLO.Me.Level() or 1
    if     level >= 116 then return 'Honed Axe Components'
    elseif level >= 101 then return 'Fine Axe Components'
    elseif level >= 96  then return 'Crafted Axe Components'
    elseif level >= 55  then return 'Balanced Axe Components'
    elseif level >= 30  then return 'Axe Components'
    else                     return 'Basic Axe Components'
    end
end

-- Buy Logic

local function buyItem(itemName, targetOverride)
    local stackSize = getStackSize(itemName)

    mq.TLO.Merchant.SelectItem('=' .. itemName)()
    mq.delay(500)

    if not mq.TLO.Merchant.SelectedItem() then
        tbPrint('\ar' .. itemName .. ' not found on merchant.')
        status = 'Not on merchant: ' .. itemName
        return
    end

    if not stackSize then
        stackSize = mq.TLO.Merchant.SelectedItem.StackSize() or 20
    end

    local target  = targetOverride or (settings.targetStacks * stackSize)
    local current = getCount(itemName)
    local deficit = math.max(0, target - current)

    if deficit == 0 then
        tbPrint(string.format('\ag%s: %d / %d - nothing to buy', itemName, current, target))
        return
    end

    status = 'Buying ' .. itemName .. '...'
    while deficit > 0 do
        if mq.TLO.Me.FreeInventory() < 1 then
            tbPrint('\arBag full - stopped buying ' .. itemName)
            status = 'Bag full'
            return
        end
        local batch = math.min(deficit, stackSize)
        mq.TLO.Merchant.Buy(batch)()
        deficit = deficit - batch
        mq.delay(500)
    end

    tbPrint(string.format('\ag%s: done, have %d', itemName, getCount(itemName)))
end

local function runBuy()
    running = true

    if groupMode then
        saveSettings()
        mq.cmd('/dgge /lua run turnipbuy autorun')
        mq.delay(2000)
    end

    status = 'Checking zone...'
    if not inPoK() then
        tbPrint('\arMust be in Plane of Knowledge.')
        status  = 'Not in PoK'
        running = false
        return
    end

    if mq.TLO.Cursor() then
        mq.cmd('/autoinventory')
        mq.delay(500)
    end

    mq.cmd('/removelev')
    mq.cmd('/makemevisible')

    status = 'Navigating...'
    mq.cmdf('/squelch /nav loc %.2f, %.2f, %.2f', settings.navY, settings.navX, settings.navZ)
    mq.delay(500)
    while mq.TLO.Navigation.Active() do mq.delay(200) end

    status = 'Opening merchant...'
    mq.cmdf('/target %s', settings.vendorName)
    mq.delay(1000)

    if not mq.TLO.Target() then
        tbPrint('\arCould not find vendor: ' .. settings.vendorName)
        status  = 'Vendor not found'
        running = false
        return
    end

    mq.cmd('/click right target')
    mq.delay(1500)

    if not mq.TLO.Merchant.Open() then
        tbPrint('\arMerchant did not open.')
        status  = 'Merchant failed to open'
        running = false
        return
    end

    buyItem(settings.foodName)
    buyItem(settings.drinkName)

    mq.cmd('/notify MerchantWnd MW_Done_Button leftmouseup')
    mq.delay(500)

    -- Reagent buying (self only — each toon detects own class)
    if settings.reagentEnabled then
        local class = mq.TLO.Me.Class.ShortName() or ''
        local reagentItem   = nil
        local reagentVendor = nil

        if class == 'MAG' then
            reagentItem   = 'Malachite'
            reagentVendor = REAGENT_VENDORS.darius
        elseif class == 'ENC' then
            reagentItem   = 'Tiny Dagger'
            reagentVendor = REAGENT_VENDORS.darius
        elseif class == 'BER' then
            reagentItem   = getBerserkerAxeComponent()
            reagentVendor = REAGENT_VENDORS.gaddi
        elseif class == 'NEC' or class == 'SHD' then
            reagentItem   = 'Bone Chips'
            reagentVendor = REAGENT_VENDORS.bonechips
        end

        if reagentItem and reagentVendor then
            -- Zone to Guild Lobby if vendor is there and we're not already
            if reagentVendor.zone == 'guildlobby' and mq.TLO.Zone.ShortName() ~= 'guildlobby' then
                status = 'Traveling to Guild Lobby...'
                mq.cmd('/easyfind guildlobby')
                mq.delay(1000)
                local waited = 0
                while mq.TLO.Zone.ShortName() ~= 'guildlobby' and waited < 30000 do
                    mq.delay(500)
                    waited = waited + 500
                end
                if mq.TLO.Zone.ShortName() ~= 'guildlobby' then
                    tbPrint('\arFailed to zone to Guild Lobby.')
                    status = 'Zone failed'
                    running = false
                    return
                end
                mq.delay(1000)
            end

            status = 'Navigating to reagent vendor...'
            mq.cmdf('/squelch /nav loc %.2f, %.2f, %.2f', reagentVendor.navY, reagentVendor.navX, reagentVendor.navZ)
            mq.delay(500)
            while mq.TLO.Navigation.Active() do mq.delay(200) end

            mq.cmdf('/target %s', reagentVendor.name)
            mq.delay(1000)

            if not mq.TLO.Target() then
                tbPrint('\arCould not find reagent vendor: ' .. reagentVendor.name)
                status = 'Reagent vendor not found'
            else
                mq.cmd('/click right target')
                mq.delay(1500)
                if mq.TLO.Merchant.Open() then
                    buyItem(reagentItem, 20)
                    mq.cmd('/notify MerchantWnd MW_Done_Button leftmouseup')
                    mq.delay(500)
                else
                    tbPrint('\arReagent merchant did not open.')
                    status = 'Reagent merchant failed'
                end
            end
        end
    end

    local finalFood  = getCount(settings.foodName)
    local finalDrink = getCount(settings.drinkName)
    status = string.format('Done - Food: %d | Drink: %d', finalFood, finalDrink)
    tbPrint(string.format('\agDone! %s: %d | %s: %d', settings.foodName, finalFood, settings.drinkName, finalDrink))
    running = false
end

-- GUI

local function renderGUI()
    local vp = imgui.GetMainViewport()
    imgui.SetNextWindowPos(vp.WorkPos.x + 200, vp.WorkPos.y + 200, ImGuiCond.FirstUseEver)
    local dt = imgui.GetIO().DeltaTime

    local tc = THEMES[tmpTheme]
    local tsLen = (tc and tc.styles) and #tc.styles or 0
    local tcLen = tc and #tc.colors or 0
    for i = 1, tsLen do
        local s = tc.styles[i]
        imgui.PushStyleVar(s[1], s[2])
    end
    for i = 1, tcLen do
        local e = tc.colors[i]
        imgui.PushStyleColor(e[1], ImVec4(e[2], e[3], e[4], e[5]))
    end

    local open, draw = imgui.Begin('TurnipBuy v' .. VERSION .. '###TurnipBuy', true, ImGuiWindowFlags.AlwaysAutoResize)
    if not open then showUI = false end

    if draw then
        -- DrawList inset panel behind inventory counts (AStone 3-element: fill + top highlight + bottom accent)
        local px, py = imgui.GetCursorScreenPos()
        local avW, _ = imgui.GetContentRegionAvail()
        local lh = imgui.GetTextLineHeight()
        local ph = lh * 2 + imgui.GetStyle().ItemSpacing.y + 4
        local rnd = imgui.GetStyle().FrameRounding
        local dl = imgui.GetWindowDrawList()
        dl:AddRectFilled(ImVec2(px, py - 2), ImVec2(px + avW, py + ph - 2), IM_COL32(0, 0, 0, 55), rnd)
        dl:AddLine(ImVec2(px + rnd, py - 2), ImVec2(px + avW - rnd, py - 2), IM_COL32(255, 255, 255, 30), 1)
        local ac = tc and tc.accent or { 160, 160, 160, 100 }
        dl:AddLine(ImVec2(px + rnd, py + ph - 2), ImVec2(px + avW - rnd, py + ph - 2), IM_COL32(ac[1], ac[2], ac[3], ac[4]), 1)

        -- Current inventory counts
        imgui.Text(string.format('Food  (%s): %d', settings.foodName, getCount(settings.foodName)))
        imgui.Text(string.format('Drink (%s): %d', settings.drinkName, getCount(settings.drinkName)))

        imgui.Separator()
        imgui.TextColored(ImVec4(0.85, 0.85, 0.3, 1), 'Status: ' .. status)
        imgui.Separator()

        -- Run button
        local canRun = inPoK() and not running
        if not canRun then
            imgui.PushStyleColor(ImGuiCol.Button, ImVec4(0.35, 0.35, 0.35, 1))
            imgui.PushStyleColor(ImGuiCol.ButtonHovered, ImVec4(0.35, 0.35, 0.35, 1))
            imgui.PushStyleColor(ImGuiCol.Text, ImVec4(0.5, 0.5, 0.5, 1))
            imgui.Button(running and 'Running...' or 'Run  (not in PoK)')
            imgui.PopStyleColor(3)
        else
            imgui.PushStyleColor(ImGuiCol.Button, ImVec4(0.18, 0.65, 0.18, 1))
            imgui.PushStyleColor(ImGuiCol.ButtonHovered, ImVec4(0.25, 0.85, 0.25, 1))
            if imgui.Button('Run') then doRun = true end
            imgui.PopStyleColor(2)
        end

        -- Group toggle: right-aligned on Run button line
        local maxX, _ = imgui.GetContentRegionMax()
        local grpW, _ = imgui.CalcTextSize('Group')
        local padX    = imgui.GetStyle().FramePadding.x
        imgui.SameLine(maxX - grpW - padX * 2)
        groupAnim = groupAnim + ((groupMode and 1.0 or 0.0) - groupAnim) * math.min(1.0, dt * 8)
        local ga = groupAnim
        local r, g, b = 0.25 - ga * 0.05, 0.25 + ga * 0.30, 0.25 - ga * 0.05
        imgui.PushStyleColor(ImGuiCol.Button,        ImVec4(r,       g,       b,       1))
        imgui.PushStyleColor(ImGuiCol.ButtonHovered, ImVec4(r + 0.1, g + 0.1, b + 0.1, 1))
        if imgui.Button('Group') then groupMode = not groupMode end
        imgui.PopStyleColor(2)
        if imgui.IsItemHovered() then
            imgui.BeginTooltip()
            imgui.Text(groupMode and 'Group ON' or 'Group OFF')
            imgui.Text('Run TurnipBuy on all group members via DanNet')
            imgui.EndTooltip()
        end

        imgui.Separator()

        -- Settings section
        if imgui.CollapsingHeader('Settings') then
            imgui.Text('Food item:')
            imgui.SetNextItemWidth(160)
            tmpFood = imgui.InputText('##food', tmpFood)
            imgui.SameLine()
            if imgui.Button('Pick##pfood') then
                if mq.TLO.Merchant.Open() and mq.TLO.Merchant.SelectedItem() then
                    tmpFood = mq.TLO.Merchant.SelectedItem.Name() or tmpFood
                end
            end
            if imgui.IsItemHovered() then
                imgui.BeginTooltip()
                imgui.Text('Open merchant, click your food item, then click Pick')
                imgui.EndTooltip()
            end

            imgui.Text('Drink item:')
            imgui.SetNextItemWidth(160)
            tmpDrink = imgui.InputText('##drink', tmpDrink)
            imgui.SameLine()
            if imgui.Button('Pick##pdrink') then
                if mq.TLO.Merchant.Open() and mq.TLO.Merchant.SelectedItem() then
                    tmpDrink = mq.TLO.Merchant.SelectedItem.Name() or tmpDrink
                end
            end
            if imgui.IsItemHovered() then
                imgui.BeginTooltip()
                imgui.Text('Open merchant, click your drink item, then click Pick')
                imgui.EndTooltip()
            end

            imgui.Text('Vendor:')
            imgui.SetNextItemWidth(160)
            tmpVendor = imgui.InputText('##vendor', tmpVendor)
            imgui.SameLine()
            if imgui.Button('Pick##pvendor') then
                local t = mq.TLO.Target
                if t() and t.Type() == 'NPC' then
                    tmpVendor = t.CleanName() or tmpVendor
                    tmpNavY   = string.format('%.2f', mq.TLO.Me.Y() or 0)
                    tmpNavX   = string.format('%.2f', mq.TLO.Me.X() or 0)
                    tmpNavZ   = string.format('%.2f', mq.TLO.Me.Z() or 0)
                end
            end
            if imgui.IsItemHovered() then
                imgui.BeginTooltip()
                imgui.Text('Stand in front of vendor, target them, then click Pick')
                imgui.EndTooltip()
            end

            imgui.Text('Target stacks:')
            imgui.SetNextItemWidth(90)
            tmpStacks, _ = imgui.InputInt('##stacks', tmpStacks, 1, 5)
            if tmpStacks < 1 then tmpStacks = 1 end

            imgui.Text('Coords (Y  X  Z):')
            imgui.SetNextItemWidth(72)
            tmpNavY = imgui.InputText('##ny', tmpNavY)
            imgui.SameLine()
            imgui.SetNextItemWidth(72)
            tmpNavX = imgui.InputText('##nx', tmpNavX)
            imgui.SameLine()
            imgui.SetNextItemWidth(72)
            tmpNavZ = imgui.InputText('##nz', tmpNavZ)

            imgui.Text('Theme:')
            imgui.SetNextItemWidth(160)
            if imgui.BeginCombo('##theme', tmpTheme) then
                for _, name in ipairs(THEME_NAMES) do
                    local selected = tmpTheme == name
                    if imgui.Selectable(name, selected) then
                        tmpTheme = name
                    end
                    if selected then imgui.SetItemDefaultFocus() end
                end
                imgui.EndCombo()
            end

            local newReg, regChanged = imgui.Checkbox('Buy Reagents', settings.reagentEnabled)
            if regChanged then
                settings.reagentEnabled = newReg
                saveSettings()
            end
            if imgui.IsItemHovered() then
                imgui.BeginTooltip()
                imgui.Text('MAG: Malachite  ENC: Tiny Dagger  BER: Axe Components (by level)')
                imgui.Text('NEC/SHD: Bone Chips (Live only - Guild Lobby vendor, no EMU equivalent)')
                imgui.EndTooltip()
            end

            imgui.Separator()

            -- Save button: blinks amber when unsaved changes exist
            -- Capture dirty state once — push and pop must use the same value
            local dirty = hasUnsavedChanges()
            if dirty then
                local t = (math.sin(mq.gettime() / 300) + 1) / 2
                imgui.PushStyleColor(ImGuiCol.Button,        ImVec4(0.6 + t * 0.3, 0.45 + t * 0.3, 0.05, 1))
                imgui.PushStyleColor(ImGuiCol.ButtonHovered, ImVec4(0.95, 0.8, 0.2, 1))
            end
            if imgui.Button('Save') then
                settings.foodName     = tmpFood
                settings.drinkName    = tmpDrink
                settings.vendorName   = tmpVendor
                settings.navY         = tonumber(tmpNavY) or settings.navY
                settings.navX         = tonumber(tmpNavX) or settings.navX
                settings.navZ         = tonumber(tmpNavZ) or settings.navZ
                settings.targetStacks = math.max(1, tmpStacks)
                settings.theme        = tmpTheme
                saveSettings()
                tbPrint('\agSettings saved.')
            end
            if dirty then imgui.PopStyleColor(2) end

            -- Default button: right-aligned, light red
            local maxX, _  = imgui.GetContentRegionMax()
            local labelW, _ = imgui.CalcTextSize('Default')
            local padX = imgui.GetStyle().FramePadding.x
            imgui.SameLine(maxX - labelW - padX * 2)
            imgui.PushStyleColor(ImGuiCol.Button,        ImVec4(0.6, 0.2, 0.2, 1))
            imgui.PushStyleColor(ImGuiCol.ButtonHovered, ImVec4(0.8, 0.35, 0.35, 1))
            if imgui.Button('Default') then
                for k, v in pairs(defaults) do settings[k] = v end
                syncTmpVars()
                saveSettings()
                tbPrint('\ayReset to defaults.')
            end
            imgui.PopStyleColor(2)
            if imgui.IsItemHovered() then
                imgui.BeginTooltip()
                imgui.Text('Reset to Perago Crotal, Turnip, Water Flask')
                imgui.EndTooltip()
            end
        end
    end

    imgui.End()
    if tcLen > 0 then imgui.PopStyleColor(tcLen) end
    if tsLen > 0 then imgui.PopStyleVar(tsLen) end
end

-- Init + main loop

local scriptArgs = {...}
local autoRun    = scriptArgs[1] == 'autorun'

loadSettings()
tbPrint('\apTurnipBuy v' .. VERSION .. ' loaded.')
mq.imgui.init('TurnipBuy', renderGUI)

if autoRun then doRun = true end

while showUI do
    mq.doevents()
    if doRun then
        doRun = false
        runBuy()
    end
    mq.delay(50)
end
