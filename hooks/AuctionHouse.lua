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
    str = string.gsub(str, "|T.-|t", "") -- 텍스처 아이콘 제거
    str = string.gsub(str, "^%s+", "")
    str = string.gsub(str, "%s+$", "")
    return str
end

--------------------------------------------------
-- # TranslateItemName 함수 (색상 코드 및 공백, 링크 유지)
--------------------------------------------------
local function TranslateItemName(name)
    if not name or name == "" then return name end

    if TKOR_AH_NameCache[name] then
        return TKOR_AH_NameCache[name]
    end

    -- 만약 아이템 링크 형태라면 내부 이름만 추출해서 번역
    -- 1) |h[이름]|h 형식 (블리자드 기본, 대괄호 포함 링크)
    local linkName = string.match(name, "|h%[(.-)%]|h")
    if linkName then
        local translatedLinkName = TranslateItemName(linkName)
        if translatedLinkName and translatedLinkName ~= linkName then
            local safePattern = string.gsub(linkName, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
            local finalName = string.gsub(name, "%[" .. safePattern .. "%]", "[" .. translatedLinkName .. "]")
            TKOR_AH_NameCache[name] = finalName
            return finalName
        end
    end

    -- 2) |h이름|h 형식 (aux auction_listing: 대괄호 제거된 아이템 링크)
    --    |cff...|Hitem:id:...|hName|h|r  형태에서 Name 추출
    local plainLinkName = string.match(name, "|Hitem:%d+.*|h([^|]+)|h")
    if plainLinkName then
        local translatedPlainName = TranslateItemName(plainLinkName)
        if translatedPlainName and translatedPlainName ~= plainLinkName then
            local escaped = string.gsub(plainLinkName, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
            local finalName = string.gsub(name, "|h" .. escaped .. "|h", "|h" .. translatedPlainName .. "|h")
            TKOR_AH_NameCache[name] = finalName
            return finalName
        end
    end

    -- 3) [이름] 형식 (aux item_listing: 순수 대괄호만)
    local bracketName = string.match(name, "^%[(.-)%]$")
    if bracketName then
        local translatedBracketName = TranslateItemName(bracketName)
        if translatedBracketName and translatedBracketName ~= bracketName then
            local finalName = "[" .. translatedBracketName .. "]"
            TKOR_AH_NameCache[name] = finalName
            return finalName
        end
    end

    local cleanName = CleanString(name)
    if not cleanName or cleanName == "" then return name end

    local normName = Normalize(cleanName)

    -- ✅ items.lua 의 TKOR_eng_to_kor 사용
    local eng_to_kor = _G.TKOR_eng_to_kor
    if eng_to_kor and eng_to_kor[normName] then
        local translatedName = eng_to_kor[normName]

        -- 원본 문자열에서 영문 이름 부분만 한글로 치환하여 색상 코드와 공백을 그대로 유지
        local safePattern = string.gsub(cleanName, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
        local finalName = string.gsub(name, safePattern, translatedName)

        TKOR_AH_NameCache[name] = finalName
        return finalName
    end

    TKOR_AH_NameCache[name] = name
    return name
end

--------------------------------------------------
-- # 외부 애드온 (aux 등) 완벽 호환: 전역 SetText 후킹
-- AUCTION_HOUSE_SHOW/CLOSED 이벤트로 엄격하게 게이트 제어
--------------------------------------------------
local isAHWindowOpen = false

-- AUCTION_HOUSE_CLOSED 이벤트를 감지할 별도 프레임
-- (기존 TKOR_AH_Frame 은 ADDON_LOADED 도 받고 있어서 목적 분리)
local TKOR_AH_GateCheck = CreateFrame("Frame")
TKOR_AH_GateCheck:RegisterEvent("AUCTION_HOUSE_SHOW")
TKOR_AH_GateCheck:RegisterEvent("AUCTION_HOUSE_CLOSED")
TKOR_AH_GateCheck:SetScript("OnEvent", function(self, event, ...)
    if not TKOR_AH_ENABLED then return end
    if event == "AUCTION_HOUSE_SHOW" then
        isAHWindowOpen = true
    elseif event == "AUCTION_HOUSE_CLOSED" then
        isAHWindowOpen = false
    end
end)

-- 보안: AuxFrame 이 직접 show/hide 되는 경우를 대비한 OnUpdate fallback
-- (아주 드문 케이스지만, AuxFrame 이 이벤트 없이 show 되는 경우 대응)
local TKOR_AH_SafetyCheck = CreateFrame("Frame")
TKOR_AH_SafetyCheck:SetScript("OnUpdate", function()
    if not TKOR_AH_ENABLED then return end
    if not isAHWindowOpen then return end -- 이미 false 면 체크 불필요

    local auctionVisible = (_G.AuctionFrame and _G.AuctionFrame:IsVisible())
    local auxVisible = (_G.AuxFrame and _G.AuxFrame:IsVisible())

    if not auctionVisible and not auxVisible then
        isAHWindowOpen = false
    end
end)

local fstring_meta = getmetatable(CreateFrame("Frame"):CreateFontString()).__index
hooksecurefunc(fstring_meta, "SetText", function(self, text)
    if not isAHWindowOpen or not text or type(text) ~= "string" then return end
    if self._tkor_translating then return end

    local translated = TranslateItemName(text)
    if translated and translated ~= text then
        self._tkor_translating = true
        self:SetText(translated)
        self._tkor_translating = false
    end
end)

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
