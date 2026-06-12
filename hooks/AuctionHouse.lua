-- hooks/AuctionHouse.lua
-- 경매장 검색 결과 한글화 모듈
-- GetAuctionItemInfo() 후킹으로 모든 페이지에서 자동 적용

local ADDON_NAME = "TooltipKOR-wotlk"

--------------------------------------------------
-- # 설정 변수
--------------------------------------------------
TKOR_AH_ENABLED = TKOR_AH_ENABLED or true  -- 활성화 여부

--------------------------------------------------
-- # 캐시 (성능 최적화)
--------------------------------------------------
-- format: { ["list_1"] = "린넨 옷감", ["list_40"] = "비단 옷감", ... }
local TKOR_AH_NameCache = {}

-- 캐시 크기 제한 (메모리 관리)
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
    -- 캐시가 너무 크면 가장 오래된 항목들 제거
    if GetCacheSize() > MAX_CACHE_SIZE then
        local items_to_keep = {}
        local items_to_remove = {}
        
        -- 최근 2500 개만 유지
        local current = 0
        for key, value in pairs(TKOR_AH_NameCache) do
            if current < 2500 then
                items_to_keep[key] = value
            else
                items_to_remove[key] = value
            end
            current = current + 1
        end
        
        -- 캐시 정리
        for key in pairs(TKOR_AH_NameCache) do
            TKOR_AH_NameCache[key] = nil
        end
        
        for key, value in pairs(items_to_keep) do
            TKOR_AH_NameCache[key] = value
        end
        
        print(string.format("[TooltipKOR] 경매장 캐시 정리됨 (남은 항목: %d)", GetCacheSize()))
    end
end

--------------------------------------------------
-- # 유틸 함수
--------------------------------------------------
local function CleanString(str)
    if not str or str == "" then return "" end
    -- 색상 코드 제거
    str = string.gsub(str, "|c%x%x%x%x%x%x%x%x", "")
    str = string.gsub(str, "|r", "")
    -- 공백 제거
    str = string.gsub(str, "^%s+", "")
    str = string.gsub(str, "%s+$", "")
    return str
end

local function TranslateItemName(name)
    if not name or name == "" then return name end
    
    local cleanName = CleanString(name)
    if not cleanName or cleanName == "" then return name end
    
    -- 1. 캐시에서 확인
    local cacheKey = "list_" .. cleanName
    if TKOR_AH_NameCache[cacheKey] then
        cache_hit_count = cache_hit_count + 1
        return TKOR_AH_NameCache[cacheKey]
    end
    
    -- 2. 데이터베이스에서 검색
    -- items.lua 의 translate() 함수 사용
    local _, _, _, _, _, _, _, _, translatedName
    if _G.items and _G.items.translate then
        _, _, _, _, _, _, _, _, translatedName = _G.items.translate(cleanName)
    elseif _G.TKOR_Items and _G.TKOR_Items.translate then
        _, _, _, _, _, _, _, _, translatedName = _G.TKOR_Items.translate(cleanName)
    elseif _G.itemsData and _G.itemsData.translate then
        -- itemsData.lua 방식
        if _G.itemsData[cleanName] then
            translatedName = _G.itemsData[cleanName]
        end
    end
    
    -- 3. 번역 결과가 있으면 캐시 저장
    if translatedName and translatedName ~= cleanName then
        -- 캐시 키로 저장
        TKOR_AH_NameCache[cacheKey] = translatedName
        
        -- 추가적인 캐시 키 (별칭 등)
        -- ex: "linen cloth" → "린넨 옷감", "Linen Cloth" → "린넨 옷감"
        local lowerKey = "list_" .. string.lower(cleanName)
        if lowerKey ~= cacheKey then
            TKOR_AH_NameCache[lowerKey] = translatedName
        end
        
        cache_miss_count = cache_miss_count + 1
        
        -- 캐시 정리 필요 시
        if GetCacheSize() > MAX_CACHE_SIZE then
            CleanupCache()
        end
        
        -- 100 번마다 로그 (디버깅용)
        if cache_miss_count % 100 == 0 then
            print(string.format("[TooltipKOR] 경매장: 번역 %d회, 캐시 히트 %d회 (캐시 크기: %d)", 
                cache_miss_count, cache_hit_count, GetCacheSize()))
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
    -- 리스트 연결에서만 적용
    if connection ~= "list" then
        return origGetAuctionItemInfo(slot, connection, index)
    end
    
    -- slot 범위 확인 (1~40)
    if not slot or slot < 1 or slot > NUM_AUCTION_LIST_ITEMS then
        return origGetAuctionItemInfo(slot, connection, index)
    end
    
    -- 원본 호출
    local name, _, texture, stackCount, cost, level, quality, numBids, 
           timeLeft, owner, itemLink, canUse = origGetAuctionItemInfo(slot, connection, index)
    
    -- 이름 변환 (첫 번째 반환값이 이름)
    if name and name ~= "" then
        local translatedName = TranslateItemName(name)
        if translatedName and translatedName ~= name then
            name = translatedName
        end
    end
    
    return name, texture, stackCount, cost, level, quality, numBids, 
           timeLeft, owner, itemLink, canUse
end

-- 함수 후킹 (원본 함수 이름을 바꿔서 원본에 접근)
_G.GetAuctionItemInfo_orig = _G.GetAuctionItemInfo_orig or GetAuctionItemInfo_orig
_G.GetAuctionItemInfo = GetAuctionItemInfo

--------------------------------------------------
-- # 추가: 경매장 프레임 업데이트 감지
--------------------------------------------------
-- 프레임이 업데이트될 때 텍스트 직접 수정 (보완용)
local TKOR_AH_UpdateFrame = CreateFrame("Frame")
TKOR_AH_UpdateFrame:SetScript("OnEvent", function(self, event, frame, ...)
    if event == "AUCTION_HOUSE_UPDATE" and TKOR_AH_ENABLED then
        TKOR_ProcessAuctionButtons()
    elseif event == "AUCTION_BIDDER_UPDATE" and TKOR_AH_ENABLED then
        TKOR_ProcessAuctionButtons()
    end
end)

-- 경매장 버튼을 처리하는 함수
local function TKOR_ProcessAuctionButtons()
    if not TKOR_AH_ENABLED then return end
    
    -- 검색 결과 리스트 처리
    for i = 1, NUM_AUCTION_LIST_ITEMS do
        local button = _G["AuctionHouseFrameAuctionButton" .. i]
        if button then
            local buttonName = _G[button:GetName() .. "Name"]
            if buttonName then
                local originalText = buttonName:GetText()
                if originalText and originalText ~= "" then
                    local cleanText = CleanString(originalText)
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
        -- 자신의 애드온이 로드되면 자동 활성화
        TKOR_AH_ENABLED = true
    elseif event == "PLAYER_LOGIN" then
        print(string.format("[TooltipKOR] 경매장 한글화 모듈 로드됨 (GetAuctionItemInfo 후킹 완료)"))
        print(string.format("경매장 페이지: 1~%d 개 아이템 표시", NUM_AUCTION_LIST_ITEMS or 40))
    elseif event == "AUCTION_HOUSE_SHOW" then
        -- 경매장 열 때 초기화
        cache_hit_count = 0
        cache_miss_count = 0
        print("[TooltipKOR] 경매장이 열렸습니다.")
    elseif event == "AUCTION_HOUSE_UPDATE" then
        -- 경매장 데이터 업데이트 시 (검색어 변경, 페이지 이동 등)
        -- 캐시는 유지하되, 새 데이터도 자동으로 변환됨
        cache_miss_count = cache_miss_count + 1
        -- 버튼 텍스트도 업데이트 (이중 보호)
        TKOR_ProcessAuctionButtons()
    end
end)

--------------------------------------------------
-- # 명령어 (테스트/제어용)
--------------------------------------------------
SLASH_TKOR_AH1 = "/tkor_ah"
SLASH_TKOR_AH2 = "/경매장"
SlashCmdList["TKOR_AH"] = function(msg)
    if msg == "on" then
        TKOR_AH_ENABLED = true
        print("✅ 경매장 한글화: 활성화")
    elseif msg == "off" then
        TKOR_AH_ENABLED = false
        print("❌ 경매장 한글화: 비활성화")
    elseif msg == "cache" then
        print(string.format("경매장 캐시 정보:"))
        print(string.format("  - 캐시 크기: %d 개", GetCacheSize()))
        print(string.format("  - 히트: %d 회", cache_hit_count))
        print(string.format("  - 미스: %d 회", cache_miss_count))
        print(string.format("  - 히트율: %.1f%%", 
            cache_hit_count > 0 and (cache_hit_count / (cache_hit_count + cache_miss_count)) * 100 or 0))
    elseif msg == "clear" then
        for key in pairs(TKOR_AH_NameCache) do
            TKOR_AH_NameCache[key] = nil
        end
        print("✅ 경매장 캐시 초기화됨")
    elseif msg == "status" then
        print(string.format("경매장 한글화 상태: %s", TKOR_AH_ENABLED and "활성화" or "비활성화"))
        print(string.format("NUM_AUCTION_LIST_ITEMS: %d", NUM_AUCTION_LIST_ITEMS or 40))
    else
        print("[경매장 한글화] 명령어:")
        print("  /tkor_ah on   - 활성화")
        print("  /tkor_ah off  - 비활성화")
        print("  /tkor_ah cache - 캐시 정보")
        print("  /tkor_ah clear - 캐시 초기화")
        print("  /tkor_ah status - 상태 확인")
    end
end

-- 초기 로드
print(string.format("[TooltipKOR] 경매장 한글화 모듈 로드됨 (NUM_AUCTION_LIST_ITEMS: %d)", NUM_AUCTION_LIST_ITEMS or 40))
