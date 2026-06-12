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
local MAX_CACHE_SIZE = 5000

local function GetCacheSize()
    local size = 0
    for _ in pairs(TKOR_AH_NameCache) do
        size = size + 1
    end
    return size
end

--------------------------------------------------
-- # items.lua 의 Normalize 함수를 그대로 사용
-- (정규식 패턴이 중요함!)
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
        local testConn = {"list", "bid", "buyout"}
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
TKOR_AH_Frame:RegisterEvent("PLAYER_LOGIN")

TKOR_AH_Frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == ADDON_NAME then
        TKOR_AH_ENABLED = true
    elseif event == "AUCTION_HOUSE_SHOW" then
        print("[TKOR] 경매장 열림")
        TKOR_ProcessAuctionButtons()
    elseif event == "AUCTION_HOUSE_UPDATE" then
        print("[TKOR] 경매장 업데이트")
        TKOR_ProcessAuctionButtons()
    elseif event == "PLAYER_LOGIN" then
        print("[TKOR] 경매장 한글화 모듈 로드됨")
        if _G.TKOR_eng_to_kor then
            local count = 0
            for _ in pairs(_G.TKOR_eng_to_kor) do count = count + 1 end
            print(string.format("[TKOR] eng_to_kor 데이터: %d 개", count))
        end
    end
end)

--------------------------------------------------
-- # 명령어
--------------------------------------------------
SLASH_TKOR_AH1 = "/tkor_ah"
SLASH_TKOR_AH2 = "/경매장"
SlashCmdList["TKOR_AH"] = function(msg)
    if msg == "on" then
        TKOR_AH_ENABLED = true
        print("[TKOR] 활성화")
    elseif msg == "off" then
        TKOR_AH_ENABLED = false
        print("[TKOR] 비활성화")
    elseif msg == "test" then
        print("[TKOR] 테스트:")
        local testNames = {"Linen Cloth", "Silk Cloth", "Wool Cloth"}
        for _, name in ipairs(testNames) do
            local result = TranslateItemName(name)
            print(string.format("  %s → %s", name, result))
        end
    elseif msg == "status" then
        print("[TKOR] 상태:")
        print(string.format("  활성화: %s", TKOR_AH_ENABLED and "ON" or "OFF"))
        if _G.TKOR_eng_to_kor then
            local count = 0
            for _ in pairs(_G.TKOR_eng_to_kor) do count = count + 1 end
            print(string.format("  eng_to_kor: %d 개", count))
        end
        print(string.format("  캐시: %d 개", GetCacheSize()))
    elseif msg == "debug" then
        print("[TKOR] 디버깅:")
        print(string.format("  GetAuctionItemInfo: %s", GetAuctionItemInfo and "있음" or "없음"))
        print(string.format("  origGetAuctionItemInfo: %s", origGetAuctionItemInfo and "있음" or "없음"))
        print(string.format("  TKOR_eng_to_kor: %s", _G.TKOR_eng_to_kor and "있음" or "없음"))
        
        -- Normalize 테스트 (items.lua 와 동일한 패턴 사용)
        print("[TKOR] Normalize 테스트:")
        local testNorm = {"linen cloth", "Silk Cloth", "WOOL CLOTH"}
        for _, name in ipairs(testNorm) do
            print(string.format("  %s → %s", name, Normalize(name)))
        end
        
        -- 경매장 버튼 확인
        for i = 1, 5 do
            local button = _G["AuctionHouseFrameAuctionButton" .. i]
            if button then
                local buttonName = _G[button:GetName() .. "Name"]
                if buttonName then
                    print(string.format("  Button %d Name: %s", i, buttonName:GetText() or "없음"))
                end
            end
        end
        
        -- TKOR_eng_to_kor 확인 (linen cloth 예시)
        print("[TKOR] TKOR_eng_to_kor 확인 (예시):")
        if _G.TKOR_eng_to_kor then
            local linen_norm = Normalize("Linen Cloth")
            print(string.format("  Normalize('Linen Cloth'): %s", linen_norm))
            print(string.format("  TKOR_eng_to_kor['%s']: %s", linen_norm, _G.TKOR_eng_to_kor[linen_norm] or "없음"))
            
            -- 일부 데이터 확인
            local count = 0
            for key, value in pairs(_G.TKOR_eng_to_kor) do
                if count < 3 then
                    print(string.format("    %s → %s", key, value))
                    count = count + 1
                end
                if count >= 3 then break end
            end
        end
    else
        print("[경매장] 명령어: /tkor_ah on/off/test/status/debug")
    end
end
