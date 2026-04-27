-- search.lua - 아이템 및 마법 검색 기능 (koKR -> enUS)
local ADDON_NAME = "TooltipKOR-wotlk"

-- [전역 테이블] 다른 파일에서 접근 가능 (아이템 및 마법 통합 검색용)
item_name_dataDB = {}

-- 정규화 함수: 한글 바이트를 손상시키지 않으면서 공백/특수문자 제거
local function norm_ko_nospace(s)
    if not s then return "" end
    
    -- 1. 색상 코드 제거
    s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
    s = string.gsub(s, "|r", "")
    
    -- 2. 안전한 공백 제거 (ASCII 공백 및 UTF-8 NBSP 시퀀스)
    s = string.gsub(s, "%s+", "")      -- 일반 공백, 탭 등
    s = string.gsub(s, "\194\160", "") -- UTF-8용 Non-breaking space (안전)
    -- 주의: 단일 바이트 \160 제거는 한글 '정' 등 특정 글자를 파괴하므로 절대 금지!
    
    -- 3. 대소문자 무시 (영문자만 안전하게 소문자화)
    s = string.gsub(s, "[A-Z]", string.lower)
    
    -- 4. 한글/영문/숫자를 제외한 특수문자 제거
    local specials = "[%.,:%(%)'\"%-%[%]!&%?%*#@/\\{}%+=_~`<>|]"
    s = string.gsub(s, specials, "")
    
    return s
end

-- [Helper] 인덱스에 데이터 추가
local function AddToIndex(key, engName)
    if not key or key == "" or not engName then return end
    
    local current = item_name_dataDB[key]
    if not current then
        item_name_dataDB[key] = engName
    elseif type(current) == "string" then
        if current ~= engName then
            item_name_dataDB[key] = { current, engName }
        end
    elseif type(current) == "table" then
        local exists = false
        for _, v in ipairs(current) do
            if v == engName then exists = true; break end
        end
        if not exists then
            table.insert(current, engName)
        end
    end
end

-- [초기화] 아이템 데이터 인덱스 생성
local function InitializeItemSearchDB()
    local itemData = _G["item_data"]
    if not itemData then return end
    for id, names in pairs(itemData) do
        if names[1] and names[2] then
            AddToIndex(norm_ko_nospace(names[2]), names[1])
        end
    end
end

-- [초기화] 마법(Spell) 데이터 인덱스 생성
local function InitializeSpellSearchDB()
    local nameSources = { "spell_name_data", "spell_name_custom_data" }
    for _, sourceName in ipairs(nameSources) do
        local nameData = _G[sourceName]
        if nameData then
            for engName, korName in pairs(nameData) do
                if type(engName) == "string" and type(korName) == "string" then
                    AddToIndex(norm_ko_nospace(korName), engName)
                end
            end
        end
    end
end

-- 슬래시 커맨드 등록
SLASH_ITEMTO1 = "/itemto"
SLASH_ITEMTO2 = "/검색"

SlashCmdList["ITEMTO"] = function(msg)
    if not msg or msg == "" then 
        DEFAULT_CHAT_FRAME:AddMessage("|cffffff00[검색]|r 사용법: /검색 [한글 이름]")
        return 
    end

    local key = norm_ko_nospace(msg)
    local en = item_name_dataDB[key]

    if en then
        -- 정확히 일치하는 결과가 있는 경우
        if type(en) == "table" then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffff00[검색]|r '" .. msg .. "' 결과:")
            for _, name in ipairs(en) do
                DEFAULT_CHAT_FRAME:AddMessage(" - " .. name)
            end
        else
            -- 단일 결과 출력
            DEFAULT_CHAT_FRAME:AddMessage(en)
        end
    else
        -- 정확한 일치가 없을 경우 부분 검색 시도
        local foundCount = 0
        local limit = 10
        
        for k, v in pairs(item_name_dataDB) do
            if string.find(k, key) then
                if foundCount == 0 then
                    DEFAULT_CHAT_FRAME:AddMessage("|cffffff00[검색]|r 정확한 결과는 없지만 비슷한 이름을 찾았습니다:")
                end
                
                if type(v) == "table" then
                    for _, name in ipairs(v) do
                        DEFAULT_CHAT_FRAME:AddMessage(" - " .. name .. " (|cffaaaaaa" .. k .. "|r)")
                    end
                else
                    DEFAULT_CHAT_FRAME:AddMessage(" - " .. v .. " (|cffaaaaaa" .. k .. "|r)")
                end
                
                foundCount = foundCount + 1
                if foundCount >= limit then 
                    DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa...외 다수 결과 생략...|r")
                    break 
                end
            end
        end
        
        if foundCount == 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[검색]|r 결과를 찾을 수 없습니다: " .. msg)
        end
    end
end

-- 애드온 로드 시 데이터 초기화
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, arg1)
    if arg1 and arg1:lower() == ADDON_NAME:lower() then
        InitializeItemSearchDB()
        InitializeSpellSearchDB()
    end
end)
