-- UI position setting saved per character
DragonDash_Global_Settings = {
    Vertical = false,
    Left = 0,
    Top = 0
}

-- backdrop info required after 9.0.1
local backdropInfo = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = {
        left = 4,
        right = 4,
        top = 4,
        bottom = 4
    }
}

-- A simple queue implementation from https://stackoverflow.com/questions/18843610/fast-implementation-of-queues-in-lua
List = {}
function List.new()
    return { first = 0, last = -1 }
end

function List.clear(list)
    for i = list.first, list.last do
        list[i] = nil -- to allow garbage collection
    end
    list.first = 0
    list.last = -1
end

function List.pushleft(list, value)
    local first = list.first - 1
    list.first = first
    list[first] = value
end

function List.pushright(list, value)
    local last = list.last + 1
    list.last = last
    list[last] = value
end

function List.popleft(list)
    local first = list.first
    if first > list.last then error("list is empty") end
    local value = list[first]
    list[first] = nil -- to allow garbage collection
    list.first = first + 1
    return value
end

function List.popright(list)
    local last = list.last
    if list.first > last then error("list is empty") end
    local value = list[last]
    list[last] = nil -- to allow garbage collection
    list.last = last - 1
    return value
end

function List.tostring(list)
    if type(list) == 'table' then
        local s = '{ '
        for k, v in pairs(list) do
            if type(k) ~= 'number' then k = '"' .. k .. '"' end
            s = s .. '[' .. k .. '] = ' .. List.tostring(v) .. ','
        end
        return s .. '} '
    else
        return tostring(list)
    end
end

function List.means(list)
    local sum = 0
    for i = list.first, list.last do
        sum = sum + list[i]
    end
    return sum / (list.last - list.first + 1)
end

function List.sum(list)
    local sum = 0
    for i = list.first, list.last do
        sum = sum + list[i]
    end
    return sum
end

function List.max(list)
    local max = -math.huge
    for i = list.first, list.last do
        max = math.max(max, list[i])
    end
    return max
end

function List.min(list)
    local min = math.huge
    for i = list.first, list.last do
        min = math.min(min, list[i])
    end
    return min
end

function List.count(list)
    return list.last - list.first + 1
end

local lastSecSpeedAvgList = List.new()
local lastSecIntervalList = List.new()

-- Make main frame, maybe refactor to what's done in https://www.curseforge.com/wow/addons/dragonriding-speedrun
local MainFrame = {}
MainFrame = CreateFrame("frame", "FlightDash", UIParent, "BackdropTemplate")
MainFrame:SetBackdrop(backdropInfo)
MainFrame:SetClampedToScreen(true)

local Font = CreateFont("FlightDashFont")
local hasInit = false
local varLoaded = false

-- local function print(msg)
--     DEFAULT_CHAT_FRAME:AddMessage("FlightDash: " .. tostring(msg))
-- end

local function getContinentID()
    local mapID = C_Map.GetBestMapForUnit("player")
    if (mapID) then
        local info = C_Map.GetMapInfo(mapID)
        if (info) then
            while (info['mapType'] and info['mapType'] > 2) do
                info = C_Map.GetMapInfo(info['parentMapID'])
            end
            if (info['mapType'] == 2) then
                return info['mapID']
            end
        end
    end
end

-- tweak frame size according to text
function Dash_UpdateSize()
    MainFrame:SetWidth(MainFrame.Text:GetWidth() + 10)
    MainFrame:SetHeight(MainFrame.Text:GetHeight() + 10)
end

-- from addon SpeedO with api fixed
function Dash_InitFrame()
    isValid = Font:SetFont("Interface\\addons\\DragonflightDashboard-main\\DejaVuSansMono-Bold.ttf", 12, "")
    Font:SetShadowColor(0, 0, 0)
    Font:SetShadowOffset(2, -2)
    Font:SetTextColor(0.75, 0.75, 0)

    -- setup MainFrame
    MainFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", DragonDash_Global_Settings.Left, DragonDash_Global_Settings
        .Top)
    -- deprecated in 9.0.1, ref:https://wowpedia.fandom.com/wiki/XML/Backdrop
    -- MainFrame:SetBackdrop({
    --     bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    --     edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    --     tile = true,
    --     tileSize = 10,
    --     edgeSize = 10,
    --     insets = { left = 4, right = 4, top = 4, bottom = 4 }
    -- })
    -- MainFrame:SetBackdropColor(.75, .75, .75)
    -- MainFrame:SetBackdropBorderColor(1, 1, 1, 1)
    MainFrame:EnableMouse(true)
    MainFrame:SetMovable(true)
    MainFrame.LastUpdate = 0
    MainFrame.LastSpeed = 0
    MainFrame.LastYaw = 0
    MainFrame.LastPitch = 0
    MainFrame.LastSecAvg = 0
    MainFrame.LastPositiveAcc = 0
    MainFrame.UpdateInterval = .1
    MainFrame.VarsLoaded = false
    if DragonDash_Global_Settings.Vertical == true then
        MainFrame.SpacerBreak = "\r"
        MainFrame.Divider = "||"
        MainFrame.Justify = "CENTER"
    else
        MainFrame.SpacerBreak = " "
        MainFrame.Divider = " "
        MainFrame.Justify = "CENTER"
    end
    MainFrame.Text = MainFrame:CreateFontString("FlightDashText")
    if DragonDash_Global_Settings.Vertical == true then
        MainFrame.Text:SetPoint("CENTER", MainFrame, "CENTER", 0, 0)
    else
        MainFrame.Text:SetPoint("CENTER", MainFrame, "CENTER", 0, 0)
    end
    MainFrame.Text:SetJustifyH(MainFrame.Justify)
    MainFrame.Text:SetFontObject("FlightDashFont")
    MainFrame.Text:SetText("---")

    Dash_UpdateSize()

    print("initialized.")
    print("Last saved pitch:" .. GetCVar("cameraSavedPitch"))
    -- print("Current continent:" .. C_Map.GetMapInfo(getContinentID()).name .. "(" .. getContinentID() .. ")")10.834259
    SetConsoleKey("F7")
    print("Console key set to F7")
    hasInit = true
end

-- from addon SpeedO with flying speed adapted to dragon flight
function Dash_OnUpdate(Self, Elapsed)
    if varLoaded == true and hasInit == true then
        MainFrame.LastUpdate = MainFrame.LastUpdate + Elapsed
        if (MainFrame.LastUpdate > MainFrame.UpdateInterval) then
            local interval = MainFrame.LastUpdate
            MainFrame.LastUpdate = 0

            -- raw data variables
            local Speed, MapID, PositionX, PositionY, HeadRad --, PitchRad
            -- calculated variables
            local SpeedPercent, HeadDeg, MapX, MapY           --, HorizSpeed, PitchDeg


            -- API calls for raw data
            -- snippet from wowpedia
            local isGliding, canGlide, forwardSpeed = C_PlayerInfo.GetGlidingInfo()
            local base = isGliding and forwardSpeed or GetUnitSpeed("player")
            local movespeed = Round(base / BASE_MOVEMENT_SPEED * 100)
            -- speed flag to display hints of current speed
            local isGlidingGround = isGliding and C_UnitAuras.GetPlayerAuraBySpellID(404184) ~= nil or false
            local isGlidingHighSpeed = isGliding and C_UnitAuras.GetPlayerAuraBySpellID(377234) ~= nil or false
            local isGlidingLowSpeed = (isGliding and floor(((base / 7) * 100) + .5) < 230) or false

            local isRacing = (C_UnitAuras.GetPlayerAuraBySpellID(439238) ~= nil or C_UnitAuras.GetPlayerAuraBySpellID(369968) ~= nil) or
                false

            local pitchNeutral = -5.3515
            local terminalSpeed = 929 - 1
            -- if getContinentID() == 1978 then
                
            -- end
            local stallSpeed = 114 + 1

            Speed = base or 0 -- get speed
            MapID = C_Map.GetBestMapForUnit("player")
            if (MapID) then
                local posObject = C_Map.GetPlayerMapPosition(MapID, "player") -- get position in zone (0.0 to 1.0). With different size maps, coordinate system varies in scale between zones.
                if posObject then
                    PositionX, PositionY = posObject:GetXY()
                end
            end
            PositionX = PositionX or 0               -- validate value
            PositionY = PositionY or 0               -- validate value
            HeadRad = GetPlayerFacing("Player") or 0 -- get heading

            -- convert all values gathered to alternate units (user friendly data)
            -- SpeedPercent = floor(((Speed / 7) * 100) + .5) -- Blizzard measures speeds based on running being 100%.  Running is 7 yards/sec which is Blizzards 100% speed.
            -- SpeedPercent = ((Speed / 7) * 100) -- Blizzard measures speeds based on running being 100%.  Running is 7 yards/sec which is Blizzards 100% speed.
            SpeedPercent = Speed
            HeadDeg = HeadRad * 180 / math.pi  -- radians to degrees
            HeadDeg = 360 - HeadDeg            -- make clockwise positive instead of counter clockwise
            MapX = PositionX * 100             -- convert map coordinates to whole numbers 1-100
            MapY = PositionY * 100             -- convert map coordinates to whole numbers 1-100

            EstPitch = Dash_GetPitchBasedOnAccPerSec2((SpeedPercent - MainFrame.LastSpeed))
            -- if EstPitch > 88 then
            --     EstPitch = 88
            -- elseif EstPitch < -88 then
            --     EstPitch = -88
            -- end
            DeltaPitch = (EstPitch - MainFrame.LastPitch) / interval
            MainFrame.LastPitch = EstPitch

            strEstPitch = format("%.1f", EstPitch)
            strDeltaPitch = format("%.1f", DeltaPitch)

            DeltaSpeed = (SpeedPercent - MainFrame.LastSpeed) --/ interval
            MainFrame.LastSpeed = SpeedPercent

            if math.abs(DeltaSpeed) > math.abs(MainFrame.LastPositiveAcc) then
                MainFrame.LastPositiveAcc = DeltaSpeed
            end

            DeltaYaw = (HeadDeg - MainFrame.LastYaw) / interval
            MainFrame.LastYaw = HeadDeg

            --round and pad values
            local strSpeedPercent = format("%f", SpeedPercent)
            MapX = format("%5.1f", MapX)
            MapY = format("%5.1f", MapY)
            HeadDeg = format("%3.0f", HeadDeg)

            DeltaSpeedPercent = format("%f", DeltaSpeed)
            DeltaYaw = format("%.1f", DeltaYaw)

            -- results to display
            local Msg = ""

            Msg = Msg .. GetCVar("cameraSavedPitch") .. MainFrame.Divider

            Msg = Msg .. MapX .. "x" .. MainFrame.Divider .. MapY .. "y" .. MainFrame.SpacerBreak

            if isGlidingHighSpeed and isGlidingGround then
                -- Thrill + Skimming -> purple
                Msg = Msg .. "|cffa335ee" .. strSpeedPercent .. "%"
            elseif isGlidingLowSpeed then
                -- Stall -> red
                Msg = Msg .. "|cffff0000" .. strSpeedPercent .. "%"
            elseif isGlidingHighSpeed and not isGlidingGround then
                -- Thrill -> green
                Msg = Msg .. "|cff1eff00" .. strSpeedPercent .. "%"
            elseif isGlidingGround and not isGlidingHighSpeed then
                -- Skimming -> blue
                Msg = Msg .. "|cff2aa2ff" .. strSpeedPercent .. "%"
            else
                Msg = Msg .. strSpeedPercent .. "%"
            end
            Msg = Msg .. "(" .. DeltaSpeedPercent .. ")" .. MainFrame.Divider
            -- stop giving color to text
            Msg = Msg .. "|r"

            Msg = Msg .. format("%f", MainFrame.LastPositiveAcc) .. MainFrame.Divider

            List.pushright(lastSecSpeedAvgList, DeltaSpeed)
            List.pushright(lastSecIntervalList, interval)
            if List.count(lastSecSpeedAvgList) > 40 then
                MainFrame.LastSecAvg = List.sum(lastSecSpeedAvgList) / List.sum(lastSecIntervalList)
                -- MainFrame.LastSecAvg = (List.max(lastSecSpeedAvgList) + List.min(lastSecSpeedAvgList)) / 2
                -- List.popleft(lastSecSpeedAvgList)
                -- List.popleft(lastSecIntervalList)
                List.clear(lastSecSpeedAvgList)
                List.clear(lastSecIntervalList)

                MainFrame.LastPositiveAcc = DeltaSpeed
            end
            Msg = Msg .. MainFrame.LastSecAvg .. "(" .. List.count(lastSecSpeedAvgList) .. ")" .. MainFrame.Divider

            Msg = Msg .. HeadDeg .. "d" .. "(" .. DeltaYaw .. ")" .. MainFrame.Divider


            -- if not isGliding or SpeedPercent >= terminalSpeed or SpeedPercent <= stallSpeed then
            --     Msg = Msg .. "----"
            -- else
                if EstPitch <= pitchNeutral then
                    Msg = Msg .. "|cff1eff00" .. strEstPitch
                else
                    Msg = Msg .. "|cffff0000" .. strEstPitch
                end
                Msg = Msg .. "(" .. strDeltaPitch .. ")" .. MainFrame.Divider
            -- end

            Msg = Msg .. "|r" .. MainFrame.Divider

            Msg = Msg .. MainFrame.Divider

            FlightDashText:SetText(Msg)

            -- resize frame if needed
            if floor(MainFrame.Text:GetWidth()) ~= floor((MainFrame:GetWidth() - 10)) or floor(MainFrame.Text:GetHeight()) ~= floor((MainFrame:GetHeight() - 10)) then
                Dash_UpdateSize()
            end
        end
    end
end

function Dash_GetPitchBasedOnAccPerSec(acceleration)
    return -1 * (1 / 1086443 * math.pow(acceleration, 3)
        + 3 / 50677 * math.pow(acceleration, 2)
        + 367 / 1464 * acceleration
        + 883 / 165)
end

function Dash_GetPitchBasedOnAccPerSec2(acceleration)
    return -1 * (927/416 * math.pow(acceleration, 3)
        + 808/579 * math.pow(acceleration, 2)
        + 4587/128 * acceleration
        + 883/165)
end

function Dash_GetPitchBasedOnAccPerSecPlain(acceleration)
    local baseAngle = -5.351511
    local baseAccFactor = -1.5
    return -(baseAngle / baseAccFactor) * acceleration + baseAngle
end

function Dash_OnMouseDown()
    local ButtonName = GetMouseButtonClicked()
    if IsShiftKeyDown() and ButtonName == "LeftButton" then
        MainFrame:StartMoving()
    elseif IsShiftKeyDown() and ButtonName == "RightButton" then
        Dash_Command('reset')
    end
    GameTooltip:Hide()
end

function Dash_OnMouseUp()
    MainFrame:StopMovingOrSizing()
    DragonDash_Global_Settings.Left = MainFrame:GetLeft()
    DragonDash_Global_Settings.Top = MainFrame:GetTop()
end

function Dash_OnEnter()
    local Msg = ""
    GameTooltip:SetOwner(MainFrame, "ANCHOR_CURSOR")
    -- GameTooltip:SetBackdropBorderColor(0,0,0,0)
    -- GameTooltip:SetBackdropColor(0,0,0,1)
    Msg = Msg .. "Shift+left click to drag. Shift+right click reset to default position."
    GameTooltip:SetText(Msg)
    GameTooltip:Show()
end

function Dash_OnLeave()
    GameTooltip:Hide()
end

function Dash_OnLoad(self)
end

function Dash_Command(Msg)
    Msg = strlower(Msg)
    if Msg == '' then
        print('Use "reset" to position Dash at 0,0 screen coordinates.')
    elseif Msg == 'reset' then
        DragonDash_Global_Settings.Left = 0
        DragonDash_Global_Settings.Top = 0
        MainFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", DragonDash_Global_Settings.Left,
            DragonDash_Global_Settings.Top)
    elseif Msg == 'r' then
        CenterCamera()
    elseif Msg == 'l' then
        Dash_ViewPitch_To(0, 1)
    elseif Msg == 'ld' then
        Dash_ViewPitch_Updown_To(0, 1)
    elseif Msg == 'u' then
        Dash_ViewPitch_Move_Within(180, 0.1)
    elseif Msg == 'd' then
        Dash_ViewPitch_Move_Within(-180, 0.1)
    elseif Msg == 'n' then
        Dash_ViewPitch_Neutral(1)
    elseif Msg == 'nd' then
        Dash_ViewPitch_Neutral_Updown(1)
    elseif Msg == 'l45' then
        Dash_ViewYaw_Move(-45)
    elseif Msg == 'r45' then
        Dash_ViewYaw_Move(45)
    elseif Msg == 'u45' then
        Dash_ViewPitch_Move(45)
    elseif Msg == 'd45' then
        Dash_ViewPitch_Move(-45)
    elseif Msg == 'l90' then
        Dash_ViewYaw_Move(-90)
    elseif Msg == 'r90' then
        Dash_ViewYaw_Move(90)
    elseif Msg == 'u90' then
        Dash_ViewPitch_Move(90)
    elseif Msg == 'd90' then
        Dash_ViewPitch_Move(-90)
    elseif Msg == 'u90d' then
        Dash_ViewPitch_Move_After(90, 0.2)
    elseif Msg == 'd90d' then
        Dash_ViewPitch_Move_After(-90, 0.2)
    elseif Msg == 'u10' then
        Dash_ViewPitch_Move(10)
    elseif Msg == 'd10' then
        Dash_ViewPitch_Move(-10)
    else
        print('Unknown option.')
    end
end

local viewMoveTime = 0.1

function Dash_ViewYaw_Move(dYawDeg)
    Dash_ViewYaw_Move_Within(dYawDeg, viewMoveTime)
end

function Dash_ViewPitch_Move(dPitchDeg)
    Dash_ViewPitch_Move_Within(dPitchDeg, viewMoveTime)
end

function Dash_ViewYaw_Move_After(dYawDeg, delay)
    local timer = C_Timer.NewTimer(delay, function()
        Dash_ViewYaw_Move(dYawDeg)
    end)
end

function Dash_ViewPitch_Move_After(dYawDeg, delay)
    local timer = C_Timer.NewTimer(delay, function()
        Dash_ViewPitch_Move(dYawDeg)
    end)
end

function Dash_ViewYaw_Move_Within(dYawDeg, time)
    local yawSpeed = tonumber(GetCVar("cameraYawMoveSpeed"))
    local isYawNegative = dYawDeg < 0
    dYawSpeed = abs(dYawDeg) / time
    local startTime = GetTime()

    -- if isYawNegative then
    --     MoveViewRightStart(dYawDeg / yawSpeed)
    -- else
    --     MoveViewLeftStart(dYawDeg / yawSpeed)
    -- end
    local timer = C_Timer.NewTimer(0, function()
        startTime = GetTime()
        if isYawNegative then
            MoveViewRightStart(dYawSpeed / yawSpeed)
        else
            MoveViewLeftStart(dYawSpeed / yawSpeed)
        end
    end)

    local timer2 = C_Timer.NewTimer(time + 0.005, function()
        if isYawNegative then
            MoveViewRightStop()
        else
            MoveViewLeftStop()
        end
        local elapsed = GetTime() - startTime
        print("Real:", elapsed * dYawSpeed, "Delta:", elapsed - time)
    end)
end

function Dash_ViewPitch_Move_Within(dPitchDeg, time)
    local pitchSpeed = tonumber(GetCVar("cameraPitchMoveSpeed"))
    local isPitchNegative = dPitchDeg < 0
    dPitchSpeed = abs(dPitchDeg) / time
    local startTime = GetTime()

    -- if isPitchNegative then
    --     MoveViewUpStart(dPitchDeg / pitchSpeed)
    -- else
    --     MoveViewDownStart(dPitchDeg / pitchSpeed)
    -- end
    local timer = C_Timer.NewTimer(0, function()
        startTime = GetTime()
        if isPitchNegative then
            MoveViewUpStart(dPitchSpeed / pitchSpeed)
        else
            MoveViewDownStart(dPitchSpeed / pitchSpeed)
        end
    end)

    local timer2 = C_Timer.NewTimer(time + 0.005, function()
        if isPitchNegative then
            MoveViewUpStop()
        else
            MoveViewDownStop()
        end
        local elapsed = GetTime() - startTime
        print("Real:", elapsed * dPitchSpeed, "Delta:", elapsed - time)
    end)
end

function Dash_ViewPitch_To(absPitch, time)
    local pitchSpeed = tonumber(GetCVar("cameraPitchMoveSpeed")) * time

    MoveViewUpStart(5)
    local timer2 = C_Timer.NewTimer(time, function()
        MoveViewUpStop()
        Dash_ViewPitch_Move_Within(88 + absPitch, time)
    end)
end

function Dash_ViewPitch_Updown_To(absPitch, time)
    local pitchSpeed = tonumber(GetCVar("cameraPitchMoveSpeed")) * time

    MoveViewDownStart(5)
    local timer2 = C_Timer.NewTimer(time, function()
        MoveViewDownStop()
        Dash_ViewPitch_Move_Within(-88 + absPitch, time)
    end)
end

function Dash_ViewPitch_Neutral(time)
    local pitchSpeed = tonumber(GetCVar("cameraPitchMoveSpeed")) * time

    MoveViewUpStart(5)
    local timer2 = C_Timer.NewTimer(time, function()
        MoveViewUpStop()
        Dash_ViewPitch_Move_Within(82.6484879, time)
    end)
end

function Dash_ViewPitch_Neutral_Updown(time)
    local pitchSpeed = tonumber(GetCVar("cameraPitchMoveSpeed")) * time

    MoveViewDownStart(5)
    local timer2 = C_Timer.NewTimer(time, function()
        MoveViewDownStop()
        Dash_ViewPitch_Move_Within(82.6484879 - 176, time)
    end)
end

function Dash_OnEvent(Self, Event, ...)
    if Event == "PLAYER_LOGIN" then
        Dash_InitFrame()
    elseif Event == "ADDON_LOADED" then
        varLoaded = true
    end
end

MainFrame:SetScript("OnEvent", Dash_OnEvent)
MainFrame:SetScript("OnUpdate", Dash_OnUpdate)
MainFrame:SetScript("OnMouseDown", Dash_OnMouseDown)
MainFrame:SetScript("OnMouseUp", Dash_OnMouseUp)
MainFrame:SetScript("OnEnter", Dash_OnEnter)
MainFrame:SetScript("OnLeave", Dash_OnLeave)
MainFrame:RegisterEvent("PLAYER_LOGIN")
MainFrame:RegisterEvent("ADDON_LOADED")

SlashCmdList["FlightDash"] = Dash_Command
SLASH_FlightDash1 = "/fl"

print("loaded.")
