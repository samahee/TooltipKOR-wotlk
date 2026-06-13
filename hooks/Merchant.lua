-- hooks/Merchant.lua
-- 상점 아이템 이름 한글화 모듈
-- items.lua 의 Normalize 함수 및 TKOR_eng_to_kor 데이터를 사용

local ADDON_NAME = "TooltipKOR-wotlk"

--------------------------------------------------
-- # 설정 변수
--------------------------------------------------
TKOR_MERCHANT_ENABLED = TKOR_MERCHANT_ENABLED or true

--------------------------------------------------
-- # 캐시
--------------------------------------------------
local TKOR_Merchant_NameCache = {}

--------------------------------------------------
-- # 문자열 처리 유틸 함수
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

    -- [최적화 1] 원본 이름 자체를 캐시 키로 사용하여 연산 최소화
    if TKOR_Merchant_NameCache[name] then
        return TKOR_Merchant_NameCache[name]
    end

    local cleanName = CleanString(name)
    if not cleanName or cleanName == "" then return name end

    local normName = Normalize(cleanName)

    -- items.lua 의 TKOR_eng_to_kor 전역 변수 사용
    local eng_to_kor = _G.TKOR_eng_to_kor
    if eng_to_kor and eng_to_kor[normName] then
        local translatedName = eng_to_kor[normName]
        TKOR_Merchant_NameCache[name] = translatedName
        return translatedName
    end

    -- [최적화 2] 매칭되지 않은 단어나 이미 한글인 단어도 캐시에 넣어 재검색 방지
    TKOR_Merchant_NameCache[name] = name
    return name
end

--------------------------------------------------
-- # GetMerchantItemInfo 후킹 (API 호출 레벨에서 번역)
--------------------------------------------------
local origGetMerchantItemInfo = _G.GetMerchantItemInfo

_G.GetMerchantItemInfo = function(index)
    if not index or index < 1 then
        return origGetMerchantItemInfo(index)
    end

    local name, texture, price, quantity, numAvailable, isUsable, extendedCost = origGetMerchantItemInfo(index)

    if name and name ~= "" then
        local translatedName = TranslateItemName(name)
        if translatedName and translatedName ~= name then
            name = translatedName
        end
    end

    return name, texture, price, quantity, numAvailable, isUsable, extendedCost
end

--------------------------------------------------
-- # 상점 버튼 텍스트 직접 수정 (프레임 업데이트 이후 적용)
--------------------------------------------------
local function TKOR_ProcessMerchantButtons()
    if not TKOR_MERCHANT_ENABLED then return end

    local numMerchantItems = GetMerchantNumItems()
    if not numMerchantItems then return end

    for i = 1, MERCHANT_ITEMS_PER_PAGE do
        local index = (((MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE) + i)
        if index <= numMerchantItems then
            local name = _G.GetMerchantItemInfo(index)
            if name and name ~= "" then
                local buttonName = _G["MerchantItem" .. i .. "Name"]
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

--------------------------------------------------
-- # 이벤트 리스너 (프레임 로드 감지 및 후킹)
--------------------------------------------------
local TKOR_Merchant_Frame = CreateFrame("Frame")
TKOR_Merchant_Frame:RegisterEvent("ADDON_LOADED")
TKOR_Merchant_Frame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" then
        if addonName == ADDON_NAME then
            TKOR_MERCHANT_ENABLED = true
        end
        -- 상점 UI가 로드된 직후 후킹
        if _G.MerchantFrame_Update and not self.hooked then
            hooksecurefunc("MerchantFrame_Update", TKOR_ProcessMerchantButtons)
            self.hooked = true
        end
    end
end)

-- 상점 UI가 이미 로드되어 있다면 바로 후킹
if _G.MerchantFrame_Update and not TKOR_Merchant_Frame.hooked then
    hooksecurefunc("MerchantFrame_Update", TKOR_ProcessMerchantButtons)
    TKOR_Merchant_Frame.hooked = true
end
