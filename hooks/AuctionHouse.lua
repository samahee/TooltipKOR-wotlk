-- hooks/AuctionHouse.lua
-- 경매장 검색 결과 한글화 모듈
-- GetAuctionItemInfo() 후킹으로 모든 페이지에서 자동 적용
-- item_data 직접 사용 (items.lua 의 Normalize() 함수와 동일한 로직)

local ADDON_NAME = "TooltipKOR-wotlk"

--------------------------------------------------
-- # 설정 변수
--------------------------------------------------
TKOR_AH_ENABLED = TKOR_AH_ENABLED or true  -- 활성화 여부

--------------------------------------------------
-- # 캐시 (성능 최적화)
--------------------------------------------------
local TKOR_AH_NameCache = {}
local MAX_CACHE_SIZE = 5000
local cache_hit_count = 0
local cache_miss_count = 0

local function GetCacheSize()
    local size = 0
    for _ in pairs(TKOR_AH_NameCache) do
        size = size + 1
    end
    return size
end

local function CleanupCache()
    if GetCacheSize() > MAX_CACHE_SIZE then
        local items_to_keep = {}
        local current = 0
        for key, value in pairs(TKOR_AH_NameCache) do
            if current < 2500 then
                items_to_keep[key] = value
            end
            current = current + 1
        end
        for key in pairs(TKOR_AH_NameCache) do
            TKOR_AH_NameCache[key] = nil
        end
        for key, value in pairs(items_to_keep) do
            TKOR_AH_NameCache[key] = value
        end
    end
end

--------------------------------------------------
-- # 유틸 함수 (items.lua 의 Normalize() 과 동일)
--------------------------------------------------
local function Normalize(str)
    if not str then return "" end
    return string.lower(string.gsub(str, "['\"%,.\\s]+", ""))
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
    if TKOR_AH_NameCache[cacheKey] then
        cache_hit_count = cache_hit_count + 1
        return TKOR_AH_NameCache[cacheKey]
    end
    
    local item_data = _G.item_data
    if not item_data then
        return name
    end
    
    local translatedName = nil
    for id, data in pairs(item_data) do
        if type(data) == "table" and data[1] and data[2] then
            local engName = data[1]
            local normEng = Normalize(engName)
            if normEng == normName then
                translatedName = data[2]
                break
            end
        end
    end
    
    if translatedName then
        TKOR_AH_NameCache[cacheKey] = translatedName
        local lowerKey = "list_" .. string.lower(normName)
        if lowerKey ~= cacheKey then
            TKOR_AH_NameCache[lowerKey] = translatedName
        end
        
        cache_miss_count = cache_miss_count + 1
        
        if GetCacheSize() > MAX_CACHE_SIZE then
            CleanupCache()
        end
        
        return translatedName
    end
    
    return name
end

--------------------------------------------------
-- # GetAuctionItemInfo 후킹
--------------------------------------------------
local origGetAuctionItemInfo = GetAuctionItemInfo

function GetAuctionItemInfo(slot, connection, index)
    if connection ~= "list" then
        return origGetAuctionItemInfo(slot, connection, index)
    end
    
    if not slot or slot < 1 or slot > 50 then
        return origGetAuctionItemInfo(slot, connection, index)
    end
    
    local name, _, texture, stackCount, cost, level, quality, numBids, 
           timeLeft, owner, itemLink, canUse = origGetAuctionItemInfo(slot, connection, index)
    
    if name and name ~= "" then
        local translatedName = TranslateItemName(name)
        if translatedName and translatedName ~= name then
            name = translatedName
        end
    end
    
    return name, texture, stackCount, cost, level, quality, numBids, 
           timeLeft, owner, itemLink, canUse
end

_G.GetAuctionItemInfo_orig = _G.GetAuctionItemInfo_orig or GetAuctionItemInfo_orig
_G.GetAuctionItemInfo = GetAuctionItemInfo

--------------------------------------------------
-- # 경매장 버튼 업데이트
--------------------------------------------------
local TKOR_AH_UpdateFrame = CreateFrame("Frame")
TKOR_AH_UpdateFrame:SetScript("OnEvent", function(self, event, frame, ...)
    if event == "AUCTION_HOUSE_UPDATE" and TKOR_AH_ENABLED then
        TKOR_ProcessAuctionButtons()
    elseif event == "AUCTION_BIDDER_UPDATE" and TKOR_AH_ENABLED then
        TKOR_ProcessAuctionButtons()
    end
end)

local function TKOR_ProcessAuctionButtons()
    if not TKOR_AH_ENABLED then return end
    
    for i = 1, 50 do
        local button = _G["AuctionHouseFrameAuctionButton" .. i]
        if button then
            local buttonName = _G[button:GetName() .. "Name"]
            if buttonName then
                local originalText = buttonName:GetText()
                if originalText and originalText ~= "" then
                    local translatedName = TranslateItemName(originalText)
                    if translatedName and translatedName ~= originalText then
                        buttonName:SetText(translatedName)
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
TKOR_AH_Frame:RegisterEvent("PLAYER_LOGIN")

TKOR_AH_Frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == ADDON_NAME then
        TKOR_AH_ENABLED = true
    elseif event == "AUCTION_HOUSE_SHOW" then
        cache_hit_count = 0
        cache_miss_count = 0
    elseif event == "AUCTION_HOUSE_UPDATE" then
        cache_miss_count = cache_miss_count + 1
        TKOR_ProcessAuctionButtons()
    end
end)

--------------------------------------------------
-- # 명령어 (메세지 없음)
--------------------------------------------------
SLASH_TKOR_AH1 = "/tkor_ah"
SLASH_TKOR_AH2 = "/경매장"
SlashCmdList["TKOR_AH"] = function(msg)
    if msg == "on" then
        TKOR_AH_ENABLED = true
    elseif msg == "off" then
        TKOR_AH_ENABLED = false
    elseif msg == "clear" then
        for key in pairs(TKOR_AH_NameCache) do
            TKOR_AH_NameCache[key] = nil
        end
    end
end
