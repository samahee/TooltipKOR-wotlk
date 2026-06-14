-- hooks/TradeSkill.lua
-- 전문/보조 기술(TradeSkillFrame) 좌측 목록 + 선택 스킬명 + 재료명 한글화 모듈
-- spell_name_data.lua 스킬명, TKOR_eng_to_kor 재료명 사용

local ADDON_NAME = "TooltipKOR-wotlk"

--------------------------------------------------
-- # 설정 변수
--------------------------------------------------
TKOR_TRADE_ENABLED = TKOR_TRADE_ENABLED or true

--------------------------------------------------
-- # 캐시
--------------------------------------------------
local TKOR_Trade_NameCache = {}

--------------------------------------------------
-- # 텍스트 유틸 (색상 코드 제거)
--------------------------------------------------
local function StripColorCodes(text)
    if not text then return "" end
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    return text
end

--------------------------------------------------
-- # GetMatchKey (spell.lua 와 동일)
--------------------------------------------------
local function GetMatchKey(text)
    if not text then return "" end
    text = StripColorCodes(text)
    text = string.lower(text)
    text = string.gsub(text, "(%d+),(%d+)", "%1%2")
    text = string.gsub(text, "%${.-}", "var")
    text = string.gsub(text, "%$[a-zA-Z]%d*", "var")
    text = string.gsub(text, "%d+%.?%d*", "var")
    text = string.gsub(text, "[^a-z가-힣]", "")
    return text
end

--------------------------------------------------
-- # 스펠명 DB 로드
--------------------------------------------------
local function InitializeSkillDB()
    local db = {}
    local sources = { _G["spell_name_data"], _G["spell_name_custom_data"] }
    for _, src in ipairs(sources) do
        if src then
            for engName, krName in pairs(src) do
                db[GetMatchKey(engName)] = krName
            end
        end
    end
    TKOR_Trade_NameCache = {}
    return db
end

local TKOR_Trade_SkillDB = nil

--------------------------------------------------
-- # Normalize (아이템명 매칭 - items.lua 와 동일)
--------------------------------------------------
local function Normalize(str)
    if not str then return "" end
    return string.lower(string.gsub(str, "['\"%,.%s]+", ""))
end

--------------------------------------------------
-- # TranslateSkillName (스킬명 번역 - spell_name_data 사용)
--------------------------------------------------
local function TranslateSkillName(name)
    if not name or name == "" then return name end
    if string.find(name, "[\234-\235]") then return name end
    if TKOR_Trade_NameCache[name] then return TKOR_Trade_NameCache[name] end

    if not TKOR_Trade_SkillDB then
        TKOR_Trade_SkillDB = InitializeSkillDB()
    end

    local cleanName = StripColorCodes(name)
    if not cleanName or cleanName == "" then return name end

    local matchKey = GetMatchKey(cleanName)
    local translated = TKOR_Trade_SkillDB[matchKey]
    if translated and translated ~= "" and translated ~= name then
        TKOR_Trade_NameCache[name] = translated
        return translated
    end

    TKOR_Trade_NameCache[name] = name
    return name
end

--------------------------------------------------
-- # TranslateItemName (재료명 번역 - TKOR_eng_to_kor 사용)
--------------------------------------------------
local function TranslateItemName(name)
    if not name or name == "" then return name end
    if string.find(name, "[\234-\235]") then return name end

    local cleanName = StripColorCodes(name)
    if not cleanName or cleanName == "" then return name end

    local normName = Normalize(cleanName)
    local eng_to_kor = _G.TKOR_eng_to_kor
    if eng_to_kor and eng_to_kor[normName] then
        return eng_to_kor[normName]
    end

    return name
end

--------------------------------------------------
-- # ParseReagentLine (재료 한줄 파싱 + 번역)
--    "Linen Cloth x 5" → "리넨 옷감 x 5"
--------------------------------------------------
local function ParseReagentLine(text)
    if not text or text == "" then return text end
    if string.find(text, "[\234-\235]") then return text end

    local clean = StripColorCodes(text)

    -- "이름 x 숫자" 패턴
    local itemPart = string.match(clean, "^(.-)%s*x%s*(%d+)$")
    if itemPart then
        local translatedPart = TranslateItemName(itemPart)
        if translatedPart and translatedPart ~= itemPart then
            local safePattern = string.gsub(itemPart, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
            return string.gsub(text, safePattern, translatedPart)
        end
    end

    -- 일반 이름만 있는 경우
    local translated = TranslateItemName(clean)
    if translated and translated ~= clean then
        local safePattern = string.gsub(clean, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
        return string.gsub(text, safePattern, translated)
    end

    return text
end

--------------------------------------------------
-- # ProcessTradeSkillFrame (목록 + 선택스킬명 + 재료명 통합 업데이트)
--------------------------------------------------
local function ProcessTradeSkillList()
    if not TKOR_TRADE_ENABLED then return end
    if not TradeSkillFrame or not TradeSkillFrame:IsVisible() then return end

    -- 1) 좌측 목록: TradeSkillSkill1 ~ TradeSkillSkill8
    local offset = FauxScrollFrame_GetOffset(TradeSkillListScrollFrame)
    local numTradeSkills = GetNumTradeSkills()

    for i = 1, TRADE_SKILLS_DISPLAYED do -- TRADE_SKILLS_DISPLAYED = 8
        local skillIndex = i + offset
        if skillIndex <= numTradeSkills then
            local button = _G["TradeSkillSkill" .. i]
            if button and button.GetText and button.SetText then
                local currentText = button:GetText()
                if currentText and currentText ~= "" then
                    -- [+] [++] [+++] 프리픽스 제거 후 이름만 번역
                    local prefix = string.match(currentText, "^%s*%[%+%-%+%-%+%-%]?%]?%]?%s*")
                    local skillNameOnly = prefix and string.sub(currentText, #prefix + 1) or currentText

                    local translated = TranslateSkillName(skillNameOnly)
                    if translated and translated ~= skillNameOnly then
                        button:SetText((prefix or "") .. translated)
                    end
                end
            end
        end
    end

    -- 2) 우측 상단 선택된 스킬명: TradeSkillSkillName
    local detailName = _G["TradeSkillSkillName"]
    if detailName and detailName.GetText then
        local currentText = detailName:GetText()
        if currentText and currentText ~= "" then
            local translated = TranslateSkillName(currentText)
            if translated and translated ~= currentText then
                detailName:SetText(translated)
            end
        end
    end

    -- 3) 재료명: TradeSkillReagent1Name ~ TradeSkillReagent8Name
    for i = 1, MAX_TRADE_SKILL_REAGENTS do -- MAX_TRADE_SKILL_REAGENTS = 8
        local reagentName = _G["TradeSkillReagent" .. i .. "Name"]
        if reagentName and reagentName.GetText then
            local currentText = reagentName:GetText()
            if currentText and currentText ~= "" then
                local translated = ParseReagentLine(currentText)
                if translated and translated ~= currentText then
                    reagentName:SetText(translated)
                end
            end
        end
    end
end

--------------------------------------------------
-- # 이벤트 리스너
--------------------------------------------------
local TKOR_Trade_Frame = CreateFrame("Frame")
TKOR_Trade_Frame:RegisterEvent("ADDON_LOADED")
TKOR_Trade_Frame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" then
        if addonName == ADDON_NAME then
            TKOR_TRADE_ENABLED = true
            TKOR_Trade_SkillDB = InitializeSkillDB()
        elseif addonName == "Blizzard_TradeSkillUI" then
            hooksecurefunc("TradeSkillFrame_Update", ProcessTradeSkillList)
        end
    end
end)

if _G.TradeSkillFrame_Update and not TKOR_Trade_Frame.hooked then
    hooksecurefunc("TradeSkillFrame_Update", ProcessTradeSkillList)
    TKOR_Trade_Frame.hooked = true
end
