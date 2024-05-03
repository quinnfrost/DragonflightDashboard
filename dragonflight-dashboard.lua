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

-- Make main frame, maybe refactor to what's done in https://www.curseforge.com/wow/addons/dragonriding-speedrun
local MainFrame = {}
MainFrame = CreateFrame("frame", "FlightDash", UIParent, "BackdropTemplate")
MainFrame:SetBackdrop(backdropInfo)
MainFrame:SetClampedToScreen(true)

local Font = CreateFont("FlightDashFont")
local hasInit = false
local varLoaded = false

local function print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("FlightDash: " .. tostring(msg))
end

-- tweak frame size according to text
function Dash_UpdateSize()
    MainFrame:SetWidth(MainFrame.Text:GetWidth() + 10)
    MainFrame:SetHeight(MainFrame.Text:GetHeight() + 10)
end

-- from addon SpeedO with api fixed
function Dash_InitFrame()
    isValid = Font:SetFont("Interface\\addons\\dragonflight-dashboard\\DejaVuSansMono-Bold.ttf", 12, "")
    Font:SetShadowColor(0, 0, 0)
    Font:SetShadowOffset(2, -2)
    Font:SetTextColor(0.75, 0.75, 0)

    -- setup MainFrame
    MainFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", DragonDash_Global_Settings.Left, DragonDash_Global_Settings.Top)
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
    hasInit = true
end

-- from addon SpeedO with flying speed adapted to dragon flight
function Dash_OnUpdate(Self, Elapsed)
    if varLoaded == true and hasInit == true then
        MainFrame.LastUpdate = MainFrame.LastUpdate + Elapsed
        if (MainFrame.LastUpdate > MainFrame.UpdateInterval) then
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
            local isGlidingLowSpeed = (isGliding and floor(((base / 7) * 100) + .5) < 200) or false

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
            SpeedPercent = floor(((Speed / 7) * 100) + .5) -- Blizzard measures speeds based on running being 100%.  Running is 7 yards/sec which is Blizzards 100% speed.
            HeadDeg = HeadRad * 180 / math.pi              -- radians to degrees
            HeadDeg = 360 - HeadDeg                        -- make clockwise positive instead of counter clockwise
            MapX = PositionX * 100                         -- convert map coordinates to whole numbers 1-100
            MapY = PositionY * 100                         -- convert map coordinates to whole numbers 1-100

            --round and pad values
            SpeedPercent = format("%3.0f", SpeedPercent)
            MapX = format("%5.1f", MapX)
            MapY = format("%5.1f", MapY)
            HeadDeg = format("%3.0f", HeadDeg)

            -- results to display
            local Msg = ""
            Msg = Msg .. MapX .. "x" .. MainFrame.Divider .. MapY .. "y" .. MainFrame.SpacerBreak

            if isGlidingHighSpeed and isGlidingGround then
                -- Thrill + Skimming -> purple
                Msg = Msg .. "|cffa335ee" .. SpeedPercent .. "%" .. MainFrame.Divider
            elseif isGlidingHighSpeed and not isGlidingGround then
                -- Thrill -> green
                Msg = Msg .. "|cff1eff00" .. SpeedPercent .. "%" .. MainFrame.Divider
            elseif isGlidingGround and not isGlidingHighSpeed then
                -- Skimming -> blue
                Msg = Msg .. "|cff2aa2ff" .. SpeedPercent .. "%" .. MainFrame.Divider
            elseif isGlidingLowSpeed then
                -- Stall -> red
                Msg = Msg .. "|cffff0000" .. SpeedPercent .. "%" .. MainFrame.Divider
            else
                Msg = Msg .. SpeedPercent .. "%" .. MainFrame.Divider
            end
            -- stop giving color to text
            Msg = Msg .. "|r"

            Msg = Msg .. HeadDeg .. "d"

            FlightDashText:SetText(Msg)

            -- resize frame if needed
            if floor(MainFrame.Text:GetWidth()) ~= floor((MainFrame:GetWidth() - 10)) or floor(MainFrame.Text:GetHeight()) ~= floor((MainFrame:GetHeight() - 10)) then
                Dash_UpdateSize()
            end
        end
    end
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
        MainFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", DragonDash_Global_Settings.Left, DragonDash_Global_Settings.Top)
    else
        print('Unknown option.')
    end
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
SLASH_FlightDash1 = "/flightdash"

print("loaded.")
