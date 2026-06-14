-- hooks/SpellBook.lua
-- 마법책(SpellBookFrame) 마법 이름 한글화 모듈
-- data/spell_name_data.lua 의 데이터를 사용하여 마법 버튼의 영어 이름을 한글로 교체
-- WotLK 3.3.5 기준: SpellButton1SpellName ~ SpellButton12SpellName 사용

local ADDON_NAME = "TooltipKOR-wotlk"

--------------------------------------------------
-- # 설정 변수
--------------------------------------------------
TKOR_SPELLBOOK_ENABLED = TKOR_SPELLBOOK_ENABLED or true

--------------------------------------------------
-- # 캐시
--------------------------------------------------
local TKOR_SpellBook_NameCache = {}

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
-- # GetMatchKey (spell.lua 와 동일한 로직)
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
local function InitializeSpellBookDB()
    local db = {}
    local nameSources = { _G["spell_name_data"], _G["spell_name_custom_data"] }
    for _, nameData in ipairs(nameSources) do
        if nameData then
            for engName, krName in pairs(nameData) do
                db[GetMatchKey(engName)] = krName
            end
        end
    end
    TKOR_SpellBook_NameCache = {}
    return db
end

local TKOR_SpellBook_DB = nil

--------------------------------------------------
-- # TranslateSpellName 함수
--------------------------------------------------
local function TranslateSpellName(name)
    if not name or name == "" then return name end
    if string.find(name, "[\234-\235]") then return name end
    if TKOR_SpellBook_NameCache[name] then
        return TKOR_SpellBook_NameCache[name]
    end

    if not TKOR_SpellBook_DB then
        TKOR_SpellBook_DB = InitializeSpellBookDB()
    end

    local cleanName = StripColorCodes(name)
    if not cleanName or cleanName == "" then return name end

    local matchKey = GetMatchKey(cleanName)
    local translatedName = TKOR_SpellBook_DB[matchKey]
    if translatedName and translatedName ~= cleanName then
        TKOR_SpellBook_NameCache[name] = translatedName
        return translatedName
    end

    TKOR_SpellBook_NameCache[name] = name
    return name
end

--------------------------------------------------
-- # 마법 버튼 업데이트 (SpellButton1SpellName ~ SpellButton12SpellName)
--------------------------------------------------
local function UpdateSpellButtons()
    if not TKOR_SPELLBOOK_ENABLED then return end
    if not SpellBookFrame or not SpellBookFrame:IsVisible() then return end

    for i = 1, SPELLS_PER_PAGE do -- SPELLS_PER_PAGE = 12
        local spellNameObj = _G["SpellButton" .. i .. "SpellName"]
        if spellNameObj and spellNameObj.GetText then
            local currentText = spellNameObj:GetText()
            if currentText and currentText ~= "" then
                local translatedName = TranslateSpellName(currentText)
                if translatedName and translatedName ~= currentText then
                    spellNameObj:SetText(translatedName)
                end
            end
        end
    end
end

--------------------------------------------------
-- # 이벤트 리스너 (ADDON_LOADED 감지 및 후킹)
--------------------------------------------------
local TKOR_SpellBook_Frame = CreateFrame("Frame")
TKOR_SpellBook_Frame:RegisterEvent("ADDON_LOADED")
TKOR_SpellBook_Frame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" then
        if addonName == ADDON_NAME then
            TKOR_SPELLBOOK_ENABLED = true
            TKOR_SpellBook_DB = InitializeSpellBookDB()
        elseif addonName == "Blizzard_SpellBook" then
            -- 블리자드 마법책 UI가 로드된 직후 안전하게 후킹
            hooksecurefunc("UpdateSpells", UpdateSpellButtons)
        end
    end
end)

-- 마법책 UI가 이미 로드되어 있다면 바로 후킹
if _G.UpdateSpells and not TKOR_SpellBook_Frame.hooked then
    hooksecurefunc("UpdateSpells", UpdateSpellButtons)
    TKOR_SpellBook_Frame.hooked = true
end
