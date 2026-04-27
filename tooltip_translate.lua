-- 외부 번역 파일 로드
local TranslateTable = tooltip_translate_data or {}

-- 디버그: 번역 테이블 로드 확인
local function CheckTranslateTableLoaded()
    local count = 0
    for _ in pairs(TranslateTable) do count = count + 1 end
    if count > 0 then
        print("|cffffff00[TooltipTranslate]|r 번역 테이블 로드됨: " .. count .. "개 항목")
    else
        print("|cffff0000[TooltipTranslate]|r 경고: 번역 테이블이 비어있습니다!")
    end
end

-- WoW 로드 시 한 번만 실행
local loaded = false
local function OnFirstTooltip()
    if loaded then return end
    loaded = true
    CheckTranslateTableLoaded()
end

-- 2. WoW 색상 코드 제거
local function RemoveColorCodes(text)
    if not text then return text end
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "") -- |cXXXXXXXX 제거
    text = string.gsub(text, "|r", "")                 -- |r 제거
    text = string.gsub(text, "|H[^|]*|h", "")          -- |Hlink|h 제거
    text = string.gsub(text, "|h", "")                 -- |h 제거
    return text
end

-- 3. 텍스트 정규화 함수
local function NormalizeText(text)
    if not text or text == "" then return "" end
    -- 소문자로 변환
    text = string.lower(text)
    -- 끝 마침표만 제거
    text = string.gsub(text, "%.$", "")
    -- 중복 공백 제거
    text = string.gsub(text, "%s+", " ")
    -- 앞뒤 공백 제거
    text = string.match(text, "^%s*(.-)%s*$") or text
    return text
end

-- 3.1 숫자를 패턴으로 변환 (세트 번호는 무시)
local function CreateNumberPattern(normalizedText)
    -- "up to 16 and damage done by up to 5" → "up to (%d+) and damage done by up to (%d+)"
    -- 하지만 세트 번호 같은 괄호 안의 숫자는 제외
    -- "(2) set effect: +200 armor" → "set effect: +(%d+) armor" (세트 번호 제거)

    -- 먼저 세트 번호 패턴 제거 (앞의 괄호와 숫자)
    local cleaned = string.gsub(normalizedText, "^%(%d+%)%s*", "") -- (N) 제거

    -- 그 다음 나머지 숫자만 패턴화
    local pattern = string.gsub(cleaned, "%d+", "(%%d+)")
    return pattern
end

-- 3.2 패턴 매칭 (세트 효과 우선 처리)
local function MatchPatternInTable(normalizedText)
    -- 세트 효과인지 확인: "(N) 세트 효과: +X word" 형식
    local setMatch = string.match(normalizedText, "^set effect:%s*%+%d+%s+(.+)$")
    if setMatch then
        -- 세트 효과에서 "+X word" 부분만 추출해서 매칭 시도
        local _, num = string.match(normalizedText, ":%s*%+(%d+)$")
        if num then
            -- "+X word" 형식으로 매칭 시도
            local translation = GetTranslation("+" .. num .. " " .. setMatch)
            if translation then return translation end

            -- 단어만 매칭 시도
            local translation2 = GetTranslation(setMatch)
            if translation2 then return translation2 end
        end
    end

    local pattern = CreateNumberPattern(normalizedText)

    for key, value in pairs(TranslateTable) do
        local keyNorm = NormalizeText(key)
        local keyPattern = CreateNumberPattern(keyNorm)

        -- 정규식 패턴으로 비교
        if string.match(normalizedText, "^" .. keyPattern .. "$") then
            return value, keyNorm -- 값과 사전의 정규화된 키 반환
        end
    end

    return nil, nil
end

-- 3.3 번역 조회 함수 (정확 매칭 → 패턴 매칭)
local function GetTranslation(text)
    if not text or text == "" then return nil end

    local normalized = NormalizeText(text)

    -- 세트 번호 제거 (정규화 전)
    local cleanedForSet = string.gsub(text, "^%(%d+%)%s*", "")
    if cleanedForSet ~= text then
        -- 세트 번호가 있었다면 제거 후 정규화
        normalized = NormalizeText(cleanedForSet)
    end

    -- 1단계: 사전에서 정확히 일치하는 것 찾기 (모든 키 확인)
    for key, value in pairs(TranslateTable) do
        if NormalizeText(key) == normalized then
            return value
        end
    end

    -- 2단계: 숫자 패턴으로 매칭
    local patternResult = MatchPatternInTable(normalized)
    if patternResult then
        return patternResult
    end

    return nil
end

-- 4. 사전 초기화 (스킬 체크)
local function InitializeDB()
    -- 사전이 제대로 로드되었는지 확인만 함
    local count = 0
    for _ in pairs(TranslateTable) do count = count + 1 end
    if count == 0 then
        print("|cffff0000[TooltipTranslate]|r 경고: 번역 테이블이 비어있습니다!")
    end
end

-- 4.1 미매칭 텍스트 기록 시스템 (SavedVariables 방식)
-- 게임 종료 시 자동으로 WTF/Account/<계정>/SavedVariables/TooltipKOR-wotlk.lua 에 저장됨
TooltipKOR_Untranslated = TooltipKOR_Untranslated or {}
local UNTRANSLATED_DB = TooltipKOR_Untranslated

-- WTF 저장용 간단한 키 생성 (세트 번호, 불필요한 텍스트 제거)
local function CreateWTFKey(text)
    -- "(2) 세트 효과: +200 armor" → "+200 armor"
    local cleaned = string.gsub(text, "^%(%d+%)%s*", "") -- (N) 제거
    cleaned = string.gsub(cleaned, "^세트%s*효과:%s*", "") -- "세트 효과:" 제거
    cleaned = string.gsub(cleaned, "^set%s*effect:%s*", "") -- "set effect:" 제거 (영어)
    cleaned = string.gsub(cleaned, "^[Ss]et%s*효과:%s*", "") -- "Set 효과:" 제거

    -- 장착 효과: "장착 효과: ..." → "..."
    cleaned = string.gsub(cleaned, "^장착%s*효과?:%s*", "")
    cleaned = string.gsub(cleaned, "^[Ee]quip%s*효과?:%s*", "")
    cleaned = string.gsub(cleaned, "^equip:%s*", "")

    -- 사용 효과: "사용 효과: ..." → "..."
    cleaned = string.gsub(cleaned, "^사용%s*효과?:%s*", "")
    cleaned = string.gsub(cleaned, "^[Uu]se%s*효과?:%s*", "")
    cleaned = string.gsub(cleaned, "^use:%s*", "")

    return cleaned
end

local function RecordUntranslated(equipType, text)
    if not text or text == "" then return end

    if not UNTRANSLATED_DB[equipType] then
        UNTRANSLATED_DB[equipType] = {}
    end

    -- WTF 저장용 간단한 키 생성
    local wtfKey = CreateWTFKey(text)
    local normalized = NormalizeText(wtfKey)

    -- 정규화된 텍스트로 중복 방지
    -- 키만 저장, 값은 비움 (한글 입력 대기)
    UNTRANSLATED_DB[equipType][wtfKey] = ""
end

-- 4.2 미매칭 텍스트 저장 (SavedVariables - 자동 저장)
-- local function SaveUntranslatedToWTF()
--     -- SavedVariables 방식이므로 명시적 파일 쓰기 불필요
--     -- 게임 종료 시 자동으로 WTF/Account/<계정>/SavedVariables/TooltipKOR-wotlk.lua 에 저장됨

--     local count = 0
--     for _, texts in pairs(UNTRANSLATED_DB) do
--         if next(texts) then
--             for _ in pairs(texts) do count = count + 1 end
--         end
--     end

--     if count > 0 then
--         print("|cffffff00[TooltipTranslate]|r 게임 종료 시 미번역 텍스트(" .. count .. "개)가 저장됩니다.")
--         print("|cffffff00[TooltipTranslate]|r 저장 위치: WTF/Account/<계정>/SavedVariables/TooltipKOR-wotlk.lua")
--     end
-- end

-- 4.3 미매칭 텍스트 체크 헬퍼 (영어/한글 둘 다 감지)
local function IsEquipText(text)
    local t = string.lower(text)
    return t:find("equip:") ~= nil or t:find("장착 효과") ~= nil
end

local function IsUseText(text)
    local t = string.lower(text)
    return t:find("use:") ~= nil or t:find("사용 효과") ~= nil
end

local function IsChanceText(text)
    local t = string.lower(text)
    return t:find("chance on") ~= nil or t:find("chance") ~= nil or t:find("발동 효과") ~= nil
end

local function IsSetText(text)
    local t = string.lower(text)
    return t:find("set:") ~= nil or (t:find("set") and t:find("effect")) or t:find("세트") ~= nil
end

-- 5. 번역 엔진
local function TranslateTooltipLines(tooltip)
    OnFirstTooltip() -- 첫 번째 호출 시 로드 확인
    InitializeDB()   -- 첫 호출 시 초기화

    local name = tooltip:GetName()
    if not name then return end

    for i = 1, tooltip:NumLines() do
        -- 왼쪽 텍스트 처리
        local leftLine = _G[name .. "TextLeft" .. i]
        -- if leftLine then
        --     local text = leftLine:GetText()
        --     if text then
        --         -- 색상 코드 제거
        --         text = RemoveColorCodes(text)

        --         local translatedText = nil

        --         -- 정규화
        --         local cleanText = NormalizeText(text)

        --         -- 1) 정확한 매칭 먼저 (전체 문구)
        --         local translation = GetTranslation(text)
        --         if translation then
        --             leftLine:SetText(translation)
        --             translatedText = translation
        --         else
        --             -- 미매칭된 특정 타입 기록
        --             local recordType = nil
        --             if IsEquipText(text) then
        --                 recordType = "equip"
        --             elseif IsUseText(text) then
        --                 recordType = "use"
        --             elseif IsChanceText(text) then
        --                 recordType = "chance_on_hit"
        --             elseif IsSetText(text) then
        --                 recordType = "set"
        --             end

        --             if recordType then
        --                 RecordUntranslated(recordType, text)
        --             end

        --             -- 2) 세트 효과 패턴: "(2) Set: +200 Armor"만 처리 (너무 정확하게)
        --             if string.match(cleanText, "^(%([%d]+%))%s*[Ss]et:%s*%+%d+") then
        --                 local setNum, num, word = string.match(cleanText, "^(%([%d]+%))%s*[Ss]et:%s*%+(%d+)%s+(.+)$")
        --                 if setNum and num and word then
        --                     word = string.gsub(word, "%s*%.$", "")
        --                     local korWord = GetTranslation(word)
        --                     if not korWord then
        --                         -- 단어 분리해서 번역
        --                         local parts = {}
        --                         for part in string.gmatch(word, "[%w]+") do
        --                             table.insert(parts, GetTranslation(part) or part)
        --                         end
        --                         korWord = table.concat(parts, " ")
        --                     end
        --                     translatedText = setNum .. " 세트 효과: " .. korWord .. " +" .. num
        --                     leftLine:SetText(translatedText)
        --                 end
        --             end

        --             -- 3) "Word +X" 패턴 - "Armor +270"
        --             if not translatedText and string.match(cleanText, "^[%w%s]+ %+%d+$") then
        --                 local word, num = string.match(cleanText, "^(.+)%s+%+(%d+)$")
        --                 if word and num then
        --                     local korWord = GetTranslation(word)
        --                     if not korWord then
        --                         -- 마지막 단어만 시도
        --                         local lastWord = string.match(word, "(%w+)%s*$")
        --                         korWord = GetTranslation(lastWord) or lastWord
        --                     end
        --                     translatedText = korWord .. " +" .. num
        --                     leftLine:SetText(translatedText)
        --                     leftLine:SetTextColor(1, 1, 1)  -- 흰색
        --                 end
        --             end

        --             -- 4) "+X Word" 패턴 - "+7 Strength", "+261 Armor"
        --             if not translatedText and string.match(cleanText, "^%+%d+%s+") then
        --                 local num, word = string.match(cleanText, "^%+(%d+)%s+(.+)$")
        --                 if num and word then
        --                     local korWord = GetTranslation(word)
        --                     if not korWord then
        --                         -- 마지막 단어만 시도
        --                         local lastWord = string.match(word, "(%w+)%s*$")
        --                         korWord = GetTranslation(lastWord) or lastWord
        --                     end
        --                     translatedText = korWord .. " +" .. num
        --                     leftLine:SetText(translatedText)
        --                     leftLine:SetTextColor(1, 1, 1)  -- 흰색
        --                 end
        --             end

        --             -- 5) "숫자 단어" 패턴 - "261 Armor"
        --             if not translatedText and string.match(cleanText, "^%d+%s+%w+$") then
        --                 local num, word = string.match(cleanText, "^(%d+)%s+(.+)$")
        --                 if num and word then
        --                     local korWord = GetTranslation(word) or word
        --                     translatedText = korWord .. " " .. num
        --                     leftLine:SetText(translatedText)
        --                 end
        --             end

        --             -- 6) "Requires Level X" 패턴
        --             if not translatedText and string.find(string.lower(cleanText), "requires level") then
        --                 local level = string.match(text, "%d+")
        --                 if level then
        --                     leftLine:SetText("필요 레벨 " .. level)
        --                 end
        --             end

        --             -- 7) "Item Level X" 패턴
        --             if not translatedText and string.find(string.lower(cleanText), "item level") then
        --                 local level = string.match(text, "%d+")
        --                 if level then
        --                     leftLine:SetText("아이템 레벨 " .. level)
        --                 end
        --             end
        --         end
        --     end
        -- end

        -- 우측 텍스트 처리 (재질/무기 타입 번역)
        local rightLine = _G[name .. "TextRight" .. i]
        if rightLine then
            local rText = rightLine:GetText()
            if rText then
                rText = RemoveColorCodes(rText)

                local translation = GetTranslation(rText)
                if translation then
                    rightLine:SetText(translation)
                end
            end
        end
    end
end

-- 6. 이벤트 후킹 (모든 업데이트 시 항상 번역)
local frame = CreateFrame("Frame")

-- 게임 종료 시 미매칭 텍스트 저장
-- frame:RegisterEvent("PLAYER_LOGOUT")
-- frame:SetScript("OnEvent", function(self, event)
--     if event == "PLAYER_LOGOUT" then
--         SaveUntranslatedToWTF()
--     end
-- end)

GameTooltip:HookScript("OnTooltipSetItem", function(self)
    TranslateTooltipLines(self)
end)

ItemRefTooltip:HookScript("OnTooltipSetItem", function(self)
    TranslateTooltipLines(self)
end)

-- ShoppingTooltip (비교 창)
if ShoppingTooltip1 then
    ShoppingTooltip1:HookScript("OnTooltipSetItem", function(self)
        TranslateTooltipLines(self)
    end)
    ShoppingTooltip1:HookScript("OnUpdate", function(self)
        if self:IsShown() then
            TranslateTooltipLines(self)
        end
    end)
end

if ShoppingTooltip2 then
    ShoppingTooltip2:HookScript("OnTooltipSetItem", function(self)
        TranslateTooltipLines(self)
    end)
    ShoppingTooltip2:HookScript("OnUpdate", function(self)
        if self:IsShown() then
            TranslateTooltipLines(self)
        end
    end)
end

-- EQCompareTooltip (비교 창 대안)
if EQCompareTooltip1 then
    EQCompareTooltip1:HookScript("OnTooltipSetItem", function(self)
        TranslateTooltipLines(self)
    end)
    EQCompareTooltip1:HookScript("OnUpdate", function(self)
        if self:IsShown() then
            TranslateTooltipLines(self)
        end
    end)
end

if EQCompareTooltip2 then
    EQCompareTooltip2:HookScript("OnTooltipSetItem", function(self)
        TranslateTooltipLines(self)
    end)
    EQCompareTooltip2:HookScript("OnUpdate", function(self)
        if self:IsShown() then
            TranslateTooltipLines(self)
        end
    end)
end

-- OnUpdate에서도 계속 번역 (마우스 이동 등으로 인한 재표시 대응)
GameTooltip:HookScript("OnUpdate", function(self)
    if self:IsShown() then
        TranslateTooltipLines(self)
    end
end)

ItemRefTooltip:HookScript("OnUpdate", function(self)
    if self:IsShown() then
        TranslateTooltipLines(self)
    end
end)
