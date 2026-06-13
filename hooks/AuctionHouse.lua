-- hooks/AuctionHouse.lua
-- 경매장 검색 결과 한글화 모듈
-- items.lua 의 Normalize 함수를 그대로 사용

local ADDON_NAME = "TooltipKOR-wotlk"

--------------------------------------------------
-- # 설정 변수
--------------------------------------------------
TKOR_AH_ENABLED = TKOR_AH_ENABLED or true

--------------------------------------------------
-- # 캐시
--------------------------------------------------
local TKOR_AH_NameCache = {}
--------------------------------------------------
-- # items.lua 의 Normalize 함수를 그대로 사용
--------------------------------------------------
local function Normalize(str)
    if not str then return "" end
    return string.lower(string.gsub(str, "['\"%,.%s]+", ""))
end

local function CleanString(str)
    if not str or str == "" then return "" end
    str = string.gsub(str, "|c%x%x%x%x%x%x%x%x", "")
    str = string.gsub(str, "|r", "")
    str = string.gsub(str, "^%s+", "")
    str = string.gsub(str, "%s+$", "")
    return str
end

--------------------------------------------------
-- # TranslateItemName 함수
--------------------------------------------------
local function TranslateItemName(name)
    if not name or name == "" then return name end

    local cleanName = CleanString(name)
    if not cleanName or cleanName == "" then return name end

    local normName = Normalize(cleanName)
    local cacheKey = "list_" .. normName

    -- 캐시 확인
    if TKOR_AH_NameCache[cacheKey] then
        return TKOR_AH_NameCache[cacheKey]
    end

    -- ✅ items.lua 의 TKOR_eng_to_kor 사용
    local eng_to_kor = _G.TKOR_eng_to_kor
    if eng_to_kor and eng_to_kor[normName] then
        local translatedName = eng_to_kor[normName]
        TKOR_AH_NameCache[cacheKey] = translatedName
        return translatedName
    end

    return name
end

--------------------------------------------------
-- # GetAuctionItemInfo 후킹
--------------------------------------------------
local origGetAuctionItemInfo = _G.GetAuctionItemInfo

_G.GetAuctionItemInfo = function(connection, index, ...)
    if connection ~= "list" and connection ~= "bid" and connection ~= "buyout" then
        return origGetAuctionItemInfo(connection, index, ...)
    end

    if not index or index < 1 or index > 50 then
        return origGetAuctionItemInfo(connection, index, ...)
    end

    local name, texture, stackCount, cost, level, quality, numBids,
    timeLeft, owner, itemLink, canUse = origGetAuctionItemInfo(connection, index, ...)

    if name and name ~= "" then
        local translatedName = TranslateItemName(name)
        if translatedName and translatedName ~= name then
            name = translatedName
        end
    end

    return name, texture, stackCount, cost, level, quality, numBids,
        timeLeft, owner, itemLink, canUse
end

--------------------------------------------------
-- # 경매장 버튼 직접 수정
--------------------------------------------------
local function TKOR_ProcessAuctionButtons()
    if not TKOR_AH_ENABLED then return end

    for i = 1, 50 do
        local testConn = { "list", "bid", "buyout" }
        for _, conn in ipairs(testConn) do
            local name = _G.GetAuctionItemInfo(conn, i)
            if name and name ~= "" then
                local button = _G["AuctionHouseFrameAuctionButton" .. i]
                if button then
                    local buttonName = _G[button:GetName() .. "Name"]
                    if buttonName then
                        local currentText = buttonName:GetText()
                        if currentText and currentText ~= "" then
                            local translatedName = TranslateItemName(currentText)
                            if translatedName and translatedName ~= currentText then
                                buttonName:SetText(translatedName)
                            end
                        end
                    end
                end
            end
        end
    end
end

--------------------------------------------------
-- # 이벤트 리스너
--------------------------------------------------
local TKOR_AH_Frame = CreateFrame("Frame")
TKOR_AH_Frame:RegisterEvent("ADDON_LOADED")
TKOR_AH_Frame:RegisterEvent("AUCTION_HOUSE_SHOW")
TKOR_AH_Frame:RegisterEvent("AUCTION_HOUSE_UPDATE")
TKOR_AH_Frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == ADDON_NAME then
        TKOR_AH_ENABLED = true
    elseif event == "AUCTION_HOUSE_SHOW" then
        TKOR_ProcessAuctionButtons()
    elseif event == "AUCTION_HOUSE_UPDATE" then
        TKOR_ProcessAuctionButtons()
    end
end)
