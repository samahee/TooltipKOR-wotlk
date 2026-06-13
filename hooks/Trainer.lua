-- hooks/Trainer.lua
-- 교육관(트레이너) 마법 이름 한글화 모듈
-- data/spell_name_data.lua 의 데이터를 사용하여 트레이너 버튼의 영어 이름을 한글로 교체
-- WotLK 기준: ClassTrainerFrame 사용

local ADDON_NAME = "TooltipKOR-wotlk"

--------------------------------------------------
-- # 설정 변수
--------------------------------------------------
TKOR_TRAINER_ENABLED = TKOR_TRAINER_ENABLED or true

--------------------------------------------------
-- # 캐시
--------------------------------------------------
local TKOR_Trainer_NameCache = {}

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
-- # Normalize 함수 (spell.lua 와 동일한 로직)
--------------------------------------------------
local function Normalize(str)
    if not str then return "" end
    return string.lower(string.gsub(str, "['\",\"%,.%s]+", ""))
end

--------------------------------------------------
-- # GetMatchKey 함수 (spell.lua 와 동일한 로직)
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
-- # DB 로드
--------------------------------------------------
local Trainer_NameDB = {}

local function InitializeTrainerDB()
    Trainer_NameDB = {}
    local nameSources = { _G["spell_name_data"], _G["spell_name_custom_data"] }
    for _, nameData in ipairs(nameSources) do
        if nameData then
            for engName, krName in pairs(nameData) do
                Trainer_NameDB[GetMatchKey(engName)] = krName
            end
        end
    end
    -- 캐시 초기화
    TKOR_Trainer_NameCache = {}
end

--------------------------------------------------
-- # TranslateSpellName 함수
--------------------------------------------------
local function TranslateSpellName(name)
    if not name or name == "" then return name end

    if TKOR_Trainer_NameCache[name] then
        return TKOR_Trainer_NameCache[name]
    end

    local cleanName = StripColorCodes(name)
    if not cleanName or cleanName == "" then return name end

    -- 원본 텍스트에 있던 앞부분 공백(들여쓰기) 캡처
    local leadingSpaces = string.match(cleanName, "^%s+") or ""

    local normName = Normalize(cleanName)

    -- DB 에서 매칭
    local matchKey = GetMatchKey(cleanName)
    local translatedName = Trainer_NameDB[matchKey]

    if translatedName and translatedName ~= cleanName then
        -- 번역된 텍스트 앞에 원래의 들여쓰기 공백을 유지시켜 줌
        local finalName = leadingSpaces .. translatedName
        TKOR_Trainer_NameCache[name] = finalName
        return finalName
    end

    TKOR_Trainer_NameCache[name] = name
    return name
end

--------------------------------------------------
-- # 트레이너 버튼 업데이트
--------------------------------------------------
local function UpdateTrainerButtons()
    if not TKOR_TRAINER_ENABLED then return end

    -- ClassTrainerSkill1 ~ ClassTrainerSkill11 까지 순회 (WotLK 3.3.5)
    for i = 1, 11 do
        local button = _G["ClassTrainerSkill" .. i]
        if not button then break end

        local spellName = _G["ClassTrainerSkill" .. i .. "Text"]
        if spellName then
            local currentText = spellName:GetText()
            if currentText and currentText ~= "" then
                local translatedName = TranslateSpellName(currentText)
                if translatedName and translatedName ~= currentText then
                    spellName:SetText(translatedName)
                end
            end
        end
    end

    -- 하단 상세 정보 창의 마법 이름 번역 (ClassTrainerSkillName)
    local detailSpellName = _G["ClassTrainerSkillName"]
    if detailSpellName then
        local currentText = detailSpellName:GetText()
        if currentText and currentText ~= "" then
            local translatedName = TranslateSpellName(currentText)
            if translatedName and translatedName ~= currentText then
                detailSpellName:SetText(translatedName)
            end
        end
    end
end

--------------------------------------------------
-- # 이벤트 리스너 (ADDON_LOADED 감지 및 후킹)
--------------------------------------------------
local TKOR_Trainer_Frame = CreateFrame("Frame")
TKOR_Trainer_Frame:RegisterEvent("ADDON_LOADED")
TKOR_Trainer_Frame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" then
        if addonName == ADDON_NAME then
            InitializeTrainerDB()
            TKOR_TRAINER_ENABLED = true
        elseif addonName == "Blizzard_TrainerUI" then
            -- 블리자드 트레이너 UI가 로드된 직후 안전하게 후킹
            hooksecurefunc("ClassTrainerFrame_Update", UpdateTrainerButtons)
        end
    end
end)
