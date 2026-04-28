-- spell.lua - 스펠/오라/아이템효과 개별 독립 처리 및 미번역 깔끔 저장 통합 버전

local ADDON_NAME = "TooltipKOR-wotlk"

TKOR_SAVE_SP_DESC = false
TKOR_SAVE_AURA_DESC = false
TKOR_SAVE_ITEM_DESC = false

spell_name_dataDB = {}
spell_desc_dataDB = {}
TooltipKOR_Untranslated = TooltipKOR_Untranslated or {}

--------------------------------------------------
-- # 텍스트 유틸 (색상 코드 제거 및 특수 공백 정규화)
--------------------------------------------------
local function StripColorCodes(text)
    if not text then return "" end
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")

    -- 와우 툴팁 특유의 보이지 않는 특수 공백(NBSP) 및 제로 위드 스페이스를 일반 공백으로 강제 변환
    text = string.gsub(text, "\194\160", " ")
    text = string.gsub(text, "\160", " ")
    text = string.gsub(text, "\226\128\139", "")

    return text
end

--------------------------------------------------
-- # 시간 단위 제거 유틸
--------------------------------------------------
local function StripTimeUnits(text)
    if not text then return "" end
    local res = text
    -- 숫자 뒤에 붙은 단위들을 숫자만 남기고 제거
    res = string.gsub(res, "(%d+%.?%d*)%s*sec%a*%.?", "%1")
    res = string.gsub(res, "(%d+%.?%d*)%s*min%a*%.?", "%1")
    res = string.gsub(res, "(%d+%.?%d*)%s*hour%a*%.?", "%1")
    res = string.gsub(res, "(%d+%.?%d*)%s*hr%a*%.?", "%1")
    res = string.gsub(res, "(%d+%.?%d*)%s*day%a*%.?", "%1")
    res = string.gsub(res, "(%d+%.?%d*)%s*yard%a*%.?", "%1")
    res = string.gsub(res, "(%d+%.?%d*)%s*yd%a*%.?", "%1")
    res = string.gsub(res, "(%d+%.?%d*)%s*meter%a*%.?", "%1")
    return res
end

--------------------------------------------------
-- # 변수 추출 유틸 (시간 단위 자동 변환 기능 포함)
--------------------------------------------------
local function ExtractVariables(text, injectUnits)
    local vars = {}
    -- 천 단위 콤마 제거 (예: 1,200 -> 1200)
    local cleanText = string.gsub(text, "(%d+),(%d+)", "%1%2")

    for num, unit in string.gmatch(cleanText, "(%d+%.?%d*)%s*([a-zA-Z]*)") do
        num = string.gsub(num, "%.$", "") -- 숫자 끝에 찍힌 마침표 제거

        -- 2차 시도(시간 단위 제거)로 매칭된 경우, 한글 문장에 직접 시간 단위를 붙여줌
        if injectUnits and unit and unit ~= "" then
            local lUnit = string.lower(unit)
            if string.match(lUnit, "^sec") then
                num = num .. "초"
            elseif string.match(lUnit, "^min") then
                num = num .. "분"
            elseif string.match(lUnit, "^hour") or string.match(lUnit, "^hr") then
                num = num .. "시간"
            elseif string.match(lUnit, "^day") then
                num = num .. "일"
            elseif string.match(lUnit, "^yard") or string.match(lUnit, "^yd") or string.match(lUnit, "^meter") then
                num = num .. "미터"
            end
        end
        table.insert(vars, num)
    end
    return vars
end

--------------------------------------------------
-- # 매칭 키 생성
--------------------------------------------------
local function GetMatchKey(text)
    if not text then return "" end
    text = StripColorCodes(text)
    text = string.lower(text)

    -- 숫자 천 단위 쉼표 제거
    text = string.gsub(text, "(%d+),(%d+)", "%1%2")

    -- 변수들을 일관된 문자(var)로 치환
    text = string.gsub(text, "%${.-}", "var")
    text = string.gsub(text, "%$[a-zA-Z]%d*", "var") -- $s1, $a, $d, $t 등 모든 알파벳 변수 지원
    text = string.gsub(text, "%d+%.?%d*", "var")

    -- 공백, 마침표, 특수문자를 포함한 알파벳/한글 이외의 모든 문자 완벽 제거
    text = string.gsub(text, "[^a-z가-힣]", "")
    return text
end

--------------------------------------------------
-- # 변수 처리 함수들
--------------------------------------------------
local function NormalizeVariables(text)
    local idx = 100
    return string.gsub(text, "%${(.-)}", function()
        local rep = "$s" .. idx
        idx = idx + 1
        return rep
    end)
end

local function ReplaceExpressions(text)
    return string.gsub(text, "%${(.-)}", function(expr)
        expr = string.gsub(expr, "%$m%d+", "0")
        expr = string.gsub(expr, "%$M%d+", "0")
        expr = string.gsub(expr, "%$SPH", "0")
        expr = string.gsub(expr, "%$AP", "0")

        local f = loadstring("return " .. expr)
        if f then
            local ok, result = pcall(f)
            if ok and result then return math.floor(result) end
        end
        return "0"
    end)
end

local function ReplaceAllVars(text, numbers)
    text = string.gsub(text, "%$s(%d+)", function(i)
        i = tonumber(i)
        if numbers[i] then return numbers[i] end
        return numbers[#numbers] or "0"
    end)

    -- [단위 중복 방지] 초초, 분분, 시간시간, 미터미터, 일일 등을 하나로 합침
    text = string.gsub(text, "(초)초", "%1")
    text = string.gsub(text, "(분)분", "%1")
    text = string.gsub(text, "(시간)시간", "%1")
    text = string.gsub(text, "(미터)미터", "%1")
    text = string.gsub(text, "(일)일", "%1")

    text = string.gsub(text, "%$[mMq](%d+)", "0")
    return text
end

local function NormalizeToGeneric(text)
    local idx = 1
    text = string.gsub(text, "%${.-}", function()
        local rep = "$s" .. idx; idx = idx + 1; return rep
    end)
    text = string.gsub(text, "%d+%.?%d*", function()
        local rep = "$s" .. idx; idx = idx + 1; return rep
    end)

    text = string.gsub(text, "%s+", " ")
    text = string.match(text, "^%s*(.-)%s*$")

    return text
end

-- [공통] 미번역 저장 및 잡다한 데이터 차단
local function SaveUntranslated(text, category)
    if category == "spell" and not TKOR_SAVE_SP_DESC then return end
    if category == "aura" and not TKOR_SAVE_AURA_DESC then return end
    if category == "item" and not TKOR_SAVE_ITEM_DESC then return end

    if not text or text == "" then return end
    text = StripColorCodes(text)

    text = string.match(text, "^%s*(.-)%s*$")
    if not text or text == "" then return end

    local hasKorean = string.match(text, "[\234-\235][\128-\191][\128-\191]")
    local hasAlphabet = string.match(text, "[a-zA-Z].*[a-zA-Z]")

    if not hasKorean and hasAlphabet then
        local keyToSave = NormalizeToGeneric(text)
        if string.match(keyToSave, "[a-zA-Z]") then
            if not TooltipKOR_Untranslated[keyToSave] then
                TooltipKOR_Untranslated[keyToSave] = ""
            end
        end
    end
end

--------------------------------------------------
-- # DB 초기화
--------------------------------------------------
local function InitializeDB()
    local nameSources = { _G["spell_name_data"], _G["spell_name_custom_data"] }
    for _, nameData in ipairs(nameSources) do
        if nameData then
            for engName, krName in pairs(nameData) do
                spell_name_dataDB[GetMatchKey(engName)] = krName
            end
        end
    end

    local descSources = { _G["spell_desc_data"], _G["spell_desc_custom_data"], _G["spell_aura_data"] }
    for _, descData in ipairs(descSources) do
        if descData then
            for engKey, krDesc in pairs(descData) do
                -- [변수 자동 정규화] 원문에 등장하는 $a, $d, $t 등 모든 변수를 순서대로 $s1, $s2로 매핑
                local mapping = {}
                local idx = 1
                -- 중복을 피하기 위해 원문에 등장하는 모든 변수 패턴을 순서대로 추출
                for var in string.gmatch(engKey, "%$[a-zA-Z]%d*") do
                    if not mapping[var] then
                        mapping[var] = "$s" .. idx
                        idx = idx + 1
                    end
                end

                -- 추출된 매핑 정보를 바탕으로 한글 번역문의 변수들을 표준 형태($s1, $s2...)로 변환
                local normalizedKr = krDesc
                for var, rep in pairs(mapping) do
                    -- 특수문자($) 이스케이프 처리하여 안전하게 치환
                    local escapedVar = string.gsub(var, "%%", "%%%%")
                    escapedVar = string.gsub(escapedVar, "%$", "%%$")
                    normalizedKr = string.gsub(normalizedKr, escapedVar, rep)
                end

                spell_desc_dataDB[GetMatchKey(engKey)] = {
                    original = engKey,
                    kr = NormalizeVariables(normalizedKr)
                }
            end
        end
    end
end

--------------------------------------------------
-- # 툴팁 전체 사전 검사 (유닛/타겟 여부 판단)
--------------------------------------------------
local function IsUnitTooltip(tt, nameString)
    if tt.GetUnit and tt:GetUnit() then
        return true
    end

    for i = 1, tt:NumLines() do
        local line = _G[nameString .. "TextLeft" .. i]
        if line and line:IsShown() then
            local text = string.lower(line:GetText() or "")
            -- 유닛 툴팁 판별 패턴 (단어 경계 체크를 추가하여 설명 속의 단어와 혼동 방지)
            if string.find(text, "%(player%)") or
                string.find(text, "%(boss%)") or
                string.find(text, "%(elite%)") or
                string.find(text, "%(npc%)") or
                string.find(text, "'s p[ea]t") or
                string.find(text, "'s minion") or
                -- 평판 단계 (앞뒤가 공백이거나 줄의 시작/끝인 경우만 인정)
                string.find(text, "^매우 적대적$") or string.find(text, "^hated$") or
                string.find(text, "^적대적$") or string.find(text, "^hostile$") or
                string.find(text, "^약간 적대적$") or string.find(text, "^unfriendly$") or
                string.find(text, "^중립적$") or string.find(text, "^neutral$") or
                string.find(text, "^약간 우호적$") or string.find(text, "^friendly$") or
                string.find(text, "^우호적$") or string.find(text, "^honored$") or
                string.find(text, "^매우 우호적$") or string.find(text, "^revered$") or
                string.find(text, "^확고한 동맹$") or string.find(text, "^exalted$") then
                return true
            end
        end
    end
    return false
end

--------------------------------------------------
-- 1 스펠 이름 처리
--------------------------------------------------
local profession_name_prefixes = {
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

local function ProcessSpellName(tt, nameString)
    local titleLine = _G[nameString .. "TextLeft1"]
    if not titleLine then return false end

    -- 엔진에서 직접 영어 마법 이름을 가져옴 (이미 한글로 바뀌었어도 추적 가능)
    local engName = tt:GetSpell() or titleLine:GetText()
    if not engName or engName == "" then return false end

    local matchKey = GetMatchKey(engName)
    local krName = spell_name_dataDB[matchKey]

    if krName and krName ~= engName then
        local titleText = titleLine:GetText() or ""
        local titlePrefix = string.match(StripColorCodes(titleText), "^%s*([^:]+:%s*).+$")
        if titlePrefix then
            for eng, kor in pairs(profession_name_prefixes) do
                if string.find(titlePrefix, eng) or string.find(titlePrefix, kor) then
                    local newTitle = string.gsub(titlePrefix, eng, kor) .. krName
                    if titleLine:GetText() ~= newTitle then
                        titleLine:SetText(newTitle)
                        return true
                    end
                    return false
                end
            end
        end

        -- 현재 툴팁 텍스트와 우리가 가진 번역이 다를 경우에만 교체
        if titleLine:GetText() ~= krName then
            titleLine:SetText(krName)
            return true
        end
    end
    return false
end

--------------------------------------------------
-- 2 스펠 설명 처리
--------------------------------------------------
local function ProcessSpellDesc(tt, nameString)
    local changed = false
    local i = 2
    local numLines = tt:NumLines()

    while i <= numLines do
        local line = _G[nameString .. "TextLeft" .. i]
        if line and line:IsShown() then
            local text = line:GetText() or ""
            local r, g, b = line:GetTextColor()
            local cleanText = StripColorCodes(text)
            local isBlank = (cleanText == "" or string.match(cleanText, "^%s*$"))

            if not isBlank and r > 0.9 and g > 0.7 and b < 0.2 then
                local cleanTextLower = string.lower(cleanText)
                local isEffect = false
                local effectPrefixesLower = {
                    "^사용 효과:", "^착용 효과:", "^세트 효과:", "^발동 효과:",
                    "^use:", "^equip:", "^set:", "^chance on hit:",
                    "^%s*%(%d+%)%s*set:", "^%s*%(%d+%)%s*세트 효과:"
                }
                for _, p in ipairs(effectPrefixesLower) do
                    if string.find(cleanTextLower, p) then
                        isEffect = true
                        break
                    end
                end

                if not string.match(cleanTextLower, "^cost:") and
                    not string.match(cleanTextLower, "^level:") and
                    not isEffect then
                    local engDescLines = {}
                    local engDescFull = ""

                    while i <= numLines do
                        local subLine = _G[nameString .. "TextLeft" .. i]
                        if not subLine or not subLine:IsShown() then break end

                        local subText = subLine:GetText() or ""
                        local sr, sg, sb = subLine:GetTextColor()
                        local subCleanText = StripColorCodes(subText)
                        local subIsBlank = (subCleanText == "" or string.match(subCleanText, "^%s*$"))

                        if subIsBlank then break end

                        if sr > 0.9 and sg > 0.7 and sb < 0.2 then
                            local subCleanLower = string.lower(subCleanText)
                            local subIsEffect = false
                            for _, p in ipairs(effectPrefixesLower) do
                                if string.find(subCleanLower, p) then
                                    subIsEffect = true
                                    break
                                end
                            end
                            if string.match(subCleanLower, "^cost:") or string.match(subCleanLower, "^level:") or subIsEffect then
                                break
                            end

                            engDescFull = engDescFull .. (engDescFull == "" and "" or " ") .. subCleanText
                            table.insert(engDescLines, subLine)
                            i = i + 1
                        else
                            break
                        end
                    end

                    if #engDescLines > 0 then
                        local match = spell_desc_dataDB[GetMatchKey(engDescFull)]
                        local useKoreanUnits = false

                        -- [보정 로직] 매칭 실패 시, 문장 앞부분에 이름이나 Rank가 붙어 있는지 확인하여 제거 후 재시도
                        if not match then
                            local cleanFullLower = string.lower(engDescFull)
                            local strippedFull = engDescFull
                            local foundHeader = false

                            -- 1. "Rank X" 혹은 "레벨 X" 제거 시도
                            local s, e = string.find(cleanFullLower, "^rank %d+%s*")
                            if not s then s, e = string.find(cleanFullLower, "^레벨 %d+%s*") end
                            if s then
                                strippedFull = string.sub(strippedFull, e + 1)
                                foundHeader = true
                            end

                            -- 2. 마법 이름이 앞에 붙어 있는지 확인 (GetSpell() 활용)
                            local spellName = tt:GetSpell()
                            if spellName then
                                local snLower = string.lower(spellName)
                                local cfLower = string.lower(strippedFull)
                                local ss, ee = string.find(cfLower, "^" .. snLower .. "%s*")
                                if ss then
                                    strippedFull = string.sub(strippedFull, ee + 1)
                                    foundHeader = true
                                end
                            end

                            if foundHeader then
                                match = spell_desc_dataDB[GetMatchKey(strippedFull)]
                            end
                        end

                        if not match then
                            local fallbackText = StripTimeUnits(engDescFull)
                            if fallbackText ~= engDescFull then
                                match = spell_desc_dataDB[GetMatchKey(fallbackText)]
                                if match then
                                    useKoreanUnits = true -- 시간 단위가 제거된 상태로 매칭됨! 한국어 단위를 붙여줘야 함.
                                end
                            end
                        end

                        if match then
                            local numbers = {}
                            for _, l in ipairs(engDescLines) do
                                local lineVars = ExtractVariables(l:GetText() or "", useKoreanUnits)
                                for _, v in ipairs(lineVars) do
                                    table.insert(numbers, v)
                                end
                            end

                            local finalDesc = ReplaceAllVars(ReplaceExpressions(match.kr), numbers)
                            engDescLines[1]:SetText(finalDesc)
                            for j = 2, #engDescLines do
                                engDescLines[j]:SetText("")
                                engDescLines[j]:Hide()
                            end
                            changed = true
                        else
                            SaveUntranslated(engDescFull, "spell")
                        end
                    end
                else
                    i = i + 1
                end
            else
                i = i + 1
            end
        else
            i = i + 1
        end
    end

    return changed
end

--------------------------------------------------
-- 3 오라 이름 처리
--------------------------------------------------
local function ProcessAuraName(tt, nameString)
    local titleLine = _G[nameString .. "TextLeft1"]
    if not titleLine then return false end

    local engName = titleLine:GetText()
    if engName and engName ~= "" then
        local krName = spell_name_dataDB[GetMatchKey(engName)]
        if krName and krName ~= engName then
            local r, g, b = titleLine:GetTextColor()
            titleLine:SetText(krName)
            titleLine:SetTextColor(r, g, b)
            return true
        end
    end
    return false
end

--------------------------------------------------
-- 4 오라 설명 처리
--------------------------------------------------
local function ProcessAuraDesc(tt, nameString)
    local engDescLines = {}
    local engDescFull = ""
    local changed = false

    for i = 2, tt:NumLines() do
        local line = _G[nameString .. "TextLeft" .. i]
        if line and line:IsShown() then
            local text = line:GetText() or ""
            local r, g, b = line:GetTextColor()
            local cleanText = StripColorCodes(text)
            local isBlank = (cleanText == "" or string.match(cleanText, "^%s*$"))

            if not isBlank then
                local cleanTextLower = string.lower(cleanText)
                local isTimeLine = string.match(cleanTextLower, "^%d+%s?min") or
                    string.match(cleanTextLower, "^%d+%s?sec") or
                    string.match(cleanTextLower, "^%d+%s?hour") or
                    string.match(cleanTextLower, "^%d+%s?day") or
                    string.match(cleanText, "^%d+%s?분") or
                    string.match(cleanText, "^%d+%s?초") or
                    string.match(cleanText, "^%d+%s?시간") or
                    string.match(cleanText, "^%d+%s?일")

                -- "every 5 seconds" 같은 마법 효과 설명이 시간 줄로 오인되는 것 방지
                if isTimeLine and (string.find(cleanTextLower, "mana") or
                        string.find(cleanTextLower, "health") or
                        string.find(cleanTextLower, "damage") or
                        string.find(cleanTextLower, "restores") or
                        string.find(cleanTextLower, "heals")) then
                    isTimeLine = false
                end

                local isAuraInfoLine = string.match(cleanTextLower, "^level:") or
                    string.match(cleanTextLower, "^지속시간")

                if not isTimeLine and not isAuraInfoLine then
                    if (r > 0.7 and g > 0.7 and b > 0.7) or (r > 0.9 and g > 0.7 and b < 0.2) then
                        engDescFull = engDescFull .. (engDescFull == "" and "" or " ") .. cleanText
                        table.insert(engDescLines, line)
                    end
                end
            end
        end
    end

    if #engDescLines == 0 then return false end

    local match = spell_desc_dataDB[GetMatchKey(engDescFull)]
    local useKoreanUnits = false

    if not match then
        local fallbackText = StripTimeUnits(engDescFull)
        if fallbackText ~= engDescFull then
            match = spell_desc_dataDB[GetMatchKey(fallbackText)]
            if match then
                useKoreanUnits = true
            end
        end
    end

    if match then
        local numbers = {}
        for _, line in ipairs(engDescLines) do
            local lineVars = ExtractVariables(line:GetText() or "", useKoreanUnits)
            for _, v in ipairs(lineVars) do
                table.insert(numbers, v)
            end
        end
        local finalDesc = ReplaceAllVars(ReplaceExpressions(match.kr), numbers)
        engDescLines[1]:SetText(finalDesc)
        for i = 2, #engDescLines do
            engDescLines[i]:SetText("")
            engDescLines[i]:Hide()
        end
        changed = true
    else
        SaveUntranslated(engDescFull, "aura") -- 오라도 누락 없이 저장되도록 적용
    end
    return changed
end

--------------------------------------------------
-- 5 아이템 효과 처리 (사용, 착용, 세트, 발동)
--------------------------------------------------
local function ProcessItemEffects(tt, nameString)
    local changed = false
    for i = 2, tt:NumLines() do
        local line = _G[nameString .. "TextLeft" .. i]
        if line and line:IsShown() then
            local text = line:GetText() or ""
            local cleanText = StripColorCodes(text)
            local isBlank = (cleanText == "" or string.match(cleanText, "^%s*$"))

            if not isBlank then
                local prefixes = {
                    "^%s*%(%d+%)%s*세트 효과:", "^%s*%(%d+%)%s*Set:",
                    "^사용 효과:", "^착용 효과:", "^세트 효과:", "^발동 효과:",
                    "^Use:", "^Equip:", "^Set:", "^Chance on hit:"
                }

                local prefix, body
                for _, p in ipairs(prefixes) do
                    local s, e = string.find(cleanText, p)
                    if s then
                        prefix = string.sub(cleanText, s, e)
                        body = string.sub(cleanText, e + 1)
                        break
                    end
                end

                if prefix and body then
                    body = string.gsub(body, "^%s+", "")
                    local mainDesc = body
                    local parenSuffix = ""
                    local m, p = string.match(body, "^(.-)%s*(%b())$")
                    if m then
                        mainDesc = m
                        parenSuffix = " " .. p
                    end

                    local match = spell_desc_dataDB[GetMatchKey(mainDesc)]
                    local useKoreanUnits = false

                    if not match then
                        local fallbackText = StripTimeUnits(mainDesc)
                        if fallbackText ~= mainDesc then
                            match = spell_desc_dataDB[GetMatchKey(fallbackText)]
                            if match then
                                useKoreanUnits = true
                            end
                        end
                    end

                    if match then
                        local numbers = ExtractVariables(mainDesc, useKoreanUnits)
                        local finalDesc = ReplaceAllVars(ReplaceExpressions(match.kr), numbers)
                        line:SetText(prefix .. " " .. finalDesc .. parenSuffix)
                        changed = true
                    else
                        SaveUntranslated(mainDesc, "item") -- 아이템 효과도 누락 없이 저장되도록 적용
                    end
                end
            end
        end
    end
    return changed
end

--------------------------------------------------
-- # 핸들러 및 후킹
--------------------------------------------------
local function HandleSpellTooltip(tt)
    local nameString = tt:GetName()
    if not nameString then return end

    if IsUnitTooltip(tt, nameString) then return end

    local changed = false
    if ProcessSpellName(tt, nameString) then changed = true end
    if ProcessItemEffects(tt, nameString) then changed = true end
    if ProcessSpellDesc(tt, nameString) then changed = true end
    if changed and not tt.KOR_Resized then
        tt:Show()
        tt.KOR_Resized = true
    end
end

local function HandleAuraTooltip(tt)
    local nameString = tt:GetName()
    if not nameString then return end

    if IsUnitTooltip(tt, nameString) then return end

    local changed = false
    if ProcessAuraName(tt, nameString) then changed = true end
    if ProcessAuraDesc(tt, nameString) then changed = true end
    if changed and not tt.KOR_Resized then
        tt:Show()
        tt.KOR_Resized = true
    end
end

function TKOR_SpellHook(tt)
    if not tt or tt.__TKOR_SpellHooked then return end
    tt:HookScript("OnTooltipSetSpell", function(self)
        self.KOR_Resized = nil; HandleSpellTooltip(self)
    end)
    tt:HookScript("OnTooltipSetItem", function(self)
        self.KOR_Resized = nil; HandleSpellTooltip(self)
    end)
    -- 직접 텍스트를 박는 경우 대응
    tt:HookScript("OnShow", function(self)
        HandleSpellTooltip(self)
    end)
    tt.__TKOR_SpellHooked = true
end

local function HookTooltip(tt)
    TKOR_SpellHook(tt)
    if not tt then return end
    local auraFuncs = { "SetUnitAura", "SetUnitBuff", "SetUnitDebuff", "SetPlayerBuff" }
    for _, func in ipairs(auraFuncs) do
        if tt[func] then
            hooksecurefunc(tt, func, function(self)
                self.KOR_Resized = nil; HandleAuraTooltip(self)
            end)
        end
    end

    tt:HookScript("OnUpdate", function(self)
        local title = _G[self:GetName() .. "TextLeft1"]
        if title then
            local text = title:GetText()
            if text and text ~= "" and self.KOR_LastText ~= text then
                self.KOR_LastText = text

                if not string.find(text, "[\234-\235]") then
                    HandleSpellTooltip(self)
                    HandleAuraTooltip(self)
                end
            end
        end
    end)

    tt:HookScript("OnHide", function(self)
        self.KOR_Resized = nil
        self.KOR_LastText = nil
    end)

    if tt:HasScript("OnTooltipCleared") then
        tt:HookScript("OnTooltipCleared", function(self)
            self.KOR_Resized = nil
            self.KOR_LastText = nil
        end)
    end
end

-- SLASH_SAVE1 = "/저장"
-- SlashCmdList["SAVE"] = function()
--     DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[TooltipKOR]|r 미번역 내역 저장 완료.")
-- end

SLASH_SPDESC1 = "/sp_desc"
SlashCmdList["SPDESC"] = function(msg)
    if msg == "on" then
        TKOR_SAVE_SP_DESC = true
        print("|cff00ff00[TooltipKOR]|r 스펠 설명 미번역 수집 ON, 데이터 수집 중")
        print("|cff00ff00[TooltipKOR]|r |cffff0000파일에 쓰기 위해서는 반드시 /reload 해야합니다.|r")
    elseif msg == "off" then
        TKOR_SAVE_SP_DESC = false
        print("|cff00ff00[TooltipKOR]|r 스펠 설명 미번역 수집 OFF, 데이터 수집이 중지됨")
        print("|cff00ff00[TooltipKOR]|r ON 이후 OFF 하더라도 /reload 하면 ON 상태에서 수집한 데이터는 저장됩니다")
    else
        print("사용법: /sp_desc on 또는 /sp_desc off")
    end
end

SLASH_AURADESC1 = "/aura_desc"
SlashCmdList["AURADESC"] = function(msg)
    if msg == "on" then
        TKOR_SAVE_AURA_DESC = true
        print("|cff00ff00[TooltipKOR]|r 오라 설명 미번역 수집 ON, 데이터 수집 중")
        print("|cff00ff00[TooltipKOR]|r |cffff0000파일에 쓰기 위해서는 반드시 /reload 해야합니다.|r")
    elseif msg == "off" then
        TKOR_SAVE_AURA_DESC = false
        print("|cff00ff00[TooltipKOR]|r 오라 설명 미번역 수집 OFF, 데이터 수집이 중지됨")
        print("|cff00ff00[TooltipKOR]|r ON 이후 OFF 하더라도 /reload 하면 ON 상태에서 수집한 데이터는 저장됩니다")
    else
        print("사용법: /aura_desc on 또는 /aura_desc off")
    end
end

SLASH_ITEMDESC1 = "/item_desc"
SlashCmdList["ITEMDESC"] = function(msg)
    if msg == "on" then
        TKOR_SAVE_ITEM_DESC = true
        print("|cff00ff00[TooltipKOR]|r 아이템 효과 설명 미번역 수집 ON, 데이터 수집 중")
        print("|cff00ff00[TooltipKOR]|r |cffff0000파일에 쓰기 위해서는 반드시 /reload 해야합니다.|r")
    elseif msg == "off" then
        TKOR_SAVE_ITEM_DESC = false
        print("|cff00ff00[TooltipKOR]|r 아이템 효과 설명 미번역 수집 OFF, 데이터 수집이 중지됨")
        print("|cff00ff00[TooltipKOR]|r ON 이후 OFF 하더라도 /reload 하면 ON 상태에서 수집한 데이터는 저장됩니다")
    else
        print("사용법: /item_desc on 또는 /item_desc off")
    end
end

-- [추가] 외부 애드온(AtlasLoot 등) 전용 툴팁 대응 로직
local function HookAddonTooltips()
    local addonTooltips = {
        "AtlasLootTooltip",
        "AtlasLootTooltip2",
        "AtlasLootTooltip3",
        "AtlasTooltip",
        "aux_tooltip",
        "AuxTooltip",
    }

    for _, name in ipairs(addonTooltips) do
        local tt = _G[name]
        if tt then
            HookTooltip(tt)
        end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        InitializeDB()
        HookTooltip(GameTooltip)
        HookTooltip(ItemRefTooltip)
        if ShoppingTooltip1 then HookTooltip(ShoppingTooltip1) end
        if ShoppingTooltip2 then HookTooltip(ShoppingTooltip2) end
    end

    -- 아틀라스루트 등 외부 애드온 툴팁 후킹 시도
    HookAddonTooltips()
end)

-- 즉시 한 번 실행
HookAddonTooltips()
