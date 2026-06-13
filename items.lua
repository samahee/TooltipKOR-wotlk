-- items.lua

local tooltip_template_data = item_tooltip_data or {}
local tooltip_template_patterns = {}

local function EscapeTemplatePattern(text)
    if not text then return "" end
    return string.gsub(text, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

local function TemplateToPattern(template)
    if tooltip_template_patterns[template] then
        return tooltip_template_patterns[template]
    end

    local pattern = EscapeTemplatePattern(template)
    pattern = string.gsub(pattern, "%%%$s", "([%%d%%.]+)")
    pattern = "^" .. pattern .. "$"
    tooltip_template_patterns[template] = pattern
    return pattern
end

local function ApplyTemplateResult(template, captures)
    local index = 0
    return string.gsub(template, "%$s", function()
        index = index + 1
        return captures[index] or ""
    end)
end

local function TranslateItemLine(text)
    for key, value in pairs(tooltip_template_data) do
        local from, to
        if type(key) == "string" and type(value) == "string" then
            from, to = key, value
        elseif type(value) == "table" then
            from, to = value[1], value[2]
        end

        if type(from) == "string" and type(to) == "string" then
            local captures = { string.match(text, TemplateToPattern(from)) }

            if captures[1] or text == from then
                return ApplyTemplateResult(to, captures)
            end
        end
    end

    return text
end

-- 1. 매칭을 위한 전처리 함수 (공백, 특수문자, 마침표, 대소문자 무시)
local function Normalize(str)
    if not str then return "" end
    return string.lower(string.gsub(str, "['\",%.%s]+", ""))
end

-- [추가] 빠른 본문 검색을 위한 영어->한글 역방향 매핑 테이블 생성
local eng_to_kor = {}
if item_data then
    for id, data in pairs(item_data) do
        if type(data) == "table" and data[1] and data[2] then
            -- 전처리된 영어 이름을 키(Key)로 사용
            eng_to_kor[Normalize(data[1])] = data[2]
        end
    end
end
_G.TKOR_eng_to_kor = eng_to_kor -- AuctionHouse.lua, Merchant.lua 등에서 사용 가능하도록 전역 노출

-- 전문 기술 접두어 한글 매핑 테이블
local profession_map = {
    ["Cooking"] = "요리",
    ["Alchemy"] = "연금술",
    ["Enchanting"] = "마법부여",
    ["Fishing"] = "낚시",
    ["Mining"] = "채광",
    ["Skinning"] = "무두질",
    ["Tailoring"] = "재봉술",
    ["Blacksmithing"] = "대장기술",
    ["Leatherworking"] = "가죽세공",
    ["Engineering"] = "기계공학",
    ["First Aid"] = "응급치료",
    ["Jewelcrafting"] = "보석세공",
}

-- [추가] 텍스트에서 색상 코드 제거 함수
local function StripColors(text)
    if not text then return "" end
    local plain = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    plain = string.gsub(plain, "|r", "")
    return plain
end

-- [추가] Lua 정규식 특수문자 이스케이프 함수 (gsub 치환 시 오류 방지)
local function EscapePattern(text)
    if not text then return "" end
    return string.gsub(text, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

-- [추가] 툴팁 텍스트에서 순수 아이템/기술 이름만 추출하는 함수
local function GetCleanItemName(text)
    if not text then return "" end
    local clean = StripColors(text)
    clean = string.gsub(clean, "|n", "")            -- 줄바꿈 태그 제거
    clean = string.gsub(clean, "%(%s*%d+%s*%)", "") -- (10) 형태의 갯수 표시 제거
    clean = string.match(clean, "^%s*(.-)%s*$")     -- 문자열 앞뒤 공백 제거
    return clean
end

local function TranslateQualityLine(text)
    local plain = StripColors(text)
    plain = string.match(plain or "", "^%s*(.-)%s*$") or ""
    return tooltip_template_data[string.lower(plain)]
end

local function TranslateKnownName(text)
    local cleanName = GetCleanItemName(text)
    local normName = Normalize(cleanName)

    if normName ~= "" and eng_to_kor[normName] then
        return eng_to_kor[normName], cleanName
    end

    local translatedLine = TranslateItemLine(cleanName)
    if translatedLine ~= cleanName then
        return translatedLine, cleanName
    end

    return nil, cleanName
end

-- 2. 메인 로직 처리 함수
local function UpdateTooltipText(tooltip)
    local nameString = tooltip:GetName()
    local left1 = _G[nameString .. "TextLeft1"]
    if not left1 then return end

    local tooltipItemName = left1:GetText()
    if not tooltipItemName then return end

    local titleHasKorean = string.find(tooltipItemName, "[\234-\235]") ~= nil

    local isUpdated = false

    local titlePrefix, titleRest = string.match(StripColors(tooltipItemName), "^%s*([^:]+:%s*)(.+)$")
    if titlePrefix and titleRest then
        for eng, kor in pairs(profession_map) do
            if string.find(titlePrefix, eng) or string.find(titlePrefix, kor) then
                local translatedName = TranslateKnownName(titleRest)
                if translatedName then
                    local newTitle = string.gsub(titlePrefix, eng, kor) .. translatedName
                    if left1:GetText() ~= newTitle then
                        left1:SetText(newTitle)
                        isUpdated = true
                    end
                end
                break
            end
        end
    end

    -- [1단계] 첫 번째 줄 (이름) 교체
    -- 아이템 ID로 직접 매칭 시도
    local _, link = tooltip:GetItem()
    if not isUpdated and not titleHasKorean and link then
        local itemId = tonumber(string.match(link, "item:(%d+)"))
        if itemId and item_data and item_data[itemId] then
            local korName = item_data[itemId][2]
            if left1:GetText() ~= korName then
                left1:SetText(korName)
                isUpdated = true
            end
        end
    end

    -- ID 매칭 실패 시 또는 스펠/기술인 경우 역방향 매핑 테이블로 이름 교체
    -- (단, 스펠 툴팁인 경우 이름 번역은 spell.lua에서 전담하도록 제외)
    if not isUpdated and not titleHasKorean and not tooltip:GetSpell() then
        local translatedName = TranslateKnownName(tooltipItemName)
        if translatedName then
            left1:SetText(translatedName)
            isUpdated = true
        end
    end

    -- [2단계] 툴팁 본문 (재료, 요구 사항, 도구, 전문 기술) 교체 로직
    local exclude_patterns = {
        "^%s*사용 효과:",
        "^%s*착용 효과:",
        "^%s*세트 효과:",
        "^%s*발동 효과:"
    }

    for i = 1, tooltip:NumLines() do
        local lineObj = _G[nameString .. "TextLeft" .. i]
        if lineObj then
            local originalText = lineObj:GetText()
            -- 1번 라인이 이미 ID 매칭으로 업데이트 되었다면 본문 로직은 스킵
            if i == 1 and isUpdated then
                originalText = nil
            end

            if originalText and originalText ~= "" then
                local plainText = StripColors(originalText)
                local skip = false

                for _, pattern in ipairs(exclude_patterns) do
                    if string.match(plainText, pattern) then
                        skip = true
                        break
                    end
                end

                if not skip then
                    local newText = originalText
                    local qualityText = TranslateQualityLine(plainText)
                    local translatedLine = qualityText or TranslateItemLine(plainText)
                    local colonPos = string.find(originalText, ":")

                    if translatedLine ~= plainText then
                        newText = translatedLine
                    elseif colonPos then
                        local prefix = string.sub(originalText, 1, colonPos)
                        local rest = string.sub(originalText, colonPos + 1)
                        local plainPrefix = StripColors(prefix)

                        -- "요구 사항", "재료", "도구" 및 전문 기술 키워드 처리
                        local keyword_patterns = {
                            "요구 사항", "재료", "도구",
                            "^%s*Cooking:", "^%s*Alchemy:", "^%s*Enchanting:",
                            "^%s*Fishing:", "^%s*Mining:", "^%s*Skinning:",
                            "^%s*Tailoring:", "^%s*Blacksmithing:", "^%s*Leatherworking:",
                            "^%s*Engineering:", "^%s*First Aid:", "^%s*Jewelcrafting:"
                        }

                        local is_keyword_line = false
                        for _, pattern in ipairs(keyword_patterns) do
                            if string.match(plainPrefix, pattern) then
                                is_keyword_line = true
                                break
                            end
                        end

                        if is_keyword_line then
                            -- 접두어 자체를 한글로 교체 (예: Cooking: -> 요리:)
                            for eng, kor in pairs(profession_map) do
                                if string.find(plainPrefix, eng) then
                                    prefix = string.gsub(prefix, eng, kor)
                                    break
                                end
                            end

                            local translated_rest = ""
                            -- 쉼표(,)를 기준으로 구분된 항목 처리
                            for part in string.gmatch(rest, "[^,]+") do
                                local translatedName, cleanName = TranslateKnownName(part)

                                if translatedName then
                                    local safePattern = EscapePattern(cleanName)
                                    -- 원본의 |n 이나 색상 코드를 유지하며 이름만 교체
                                    part = string.gsub(part, safePattern, translatedName)
                                end

                                if translated_rest == "" then
                                    translated_rest = part
                                else
                                    translated_rest = translated_rest .. "," .. part
                                end
                            end
                            newText = prefix .. translated_rest
                        end
                    else
                        -- 콜론 없는 단일 라인 (도안 결과물 등)
                        local translatedName, cleanLine = TranslateKnownName(originalText)

                        if translatedName then
                            local safePattern = EscapePattern(cleanLine)
                            newText = string.gsub(originalText, safePattern, translatedName)
                        end
                    end

                    if newText ~= originalText then
                        lineObj:SetText(newText)
                        isUpdated = true
                    end
                end
            end
        end

        local rightLineObj = _G[nameString .. "TextRight" .. i]
        if rightLineObj then
            local originalRightText = rightLineObj:GetText()
            if originalRightText and originalRightText ~= "" then
                local plainRightText = StripColors(originalRightText)
                local translatedRightLine = TranslateItemLine(plainRightText)

                if translatedRightLine ~= plainRightText then
                    rightLineObj:SetText(translatedRightLine)
                    isUpdated = true
                end
            end
        end
    end

    if isUpdated then
        tooltip:Show()
    end
end

-- 3. 툴팁 후크 등록
function TKOR_ItemHook(tt)
    if not tt or tt.__TKOR_ItemHooked then return end

    -- 아이템 정보가 설정될 때
    if tt:HasScript("OnTooltipSetItem") then
        tt:HookScript("OnTooltipSetItem", UpdateTooltipText)
    end
    -- 스펠/기술 정보가 설정될 때
    if tt:HasScript("OnTooltipSetSpell") then
        tt:HookScript("OnTooltipSetSpell", UpdateTooltipText)
    end
    -- 애드온이 직접 Text를 박는 경우를 대비해 OnShow 시점에도 체크
    tt:HookScript("OnShow", UpdateTooltipText)

    tt.__TKOR_ItemHooked = true
end

local function HookTooltip(tt)
    TKOR_ItemHook(tt)
end

-- 기본 툴팁들 등록
HookTooltip(GameTooltip)
if ItemRefTooltip then HookTooltip(ItemRefTooltip) end
if ShoppingTooltip1 then HookTooltip(ShoppingTooltip1) end
if ShoppingTooltip2 then HookTooltip(ShoppingTooltip2) end

-- [추가] 외부 애드온(AtlasLoot 등) 전용 툴팁 대응 로직
local function HookAddonTooltips()
    local addonTooltips = {
        "AtlasLootTooltip",
        "AtlasLootTooltip2",
        "AtlasLootTooltip3",
        "AtlasTooltip",
        "aux_tooltip",
        "AuxTooltip",
        "QuestHelperTooltip",
        "QuestGuruTooltip",
    }

    for _, name in ipairs(addonTooltips) do
        local tt = _G[name]
        if tt then
            HookTooltip(tt)
        end
    end
end

-- 애드온 로드 시 및 이벤트 발생 시 외부 툴팁 후킹 시도
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, arg1)
    HookAddonTooltips()
end)

-- 즉시 실행
HookAddonTooltips()




-- 툴팁 이름이 없을 경우, reload 전까지 후킹 가능하게 하는 방법
-- /run TKOR_ItemHook(GetMouseFocus())
