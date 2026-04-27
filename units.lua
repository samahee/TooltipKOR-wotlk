-- unit.lua

-- 1. 빠른 조회를 위한 해시 테이블 생성 (이름 기반 매칭용)
-- 전역 변수 unit_data를 사용하여 초기화합니다.
local normalized_db = {}

local function Normalize(str)
    if not str then return "" end
    return string.lower(string.gsub(str, "['\",%.%s]+", ""))
end

-- 데이터를 로딩할 때 단 한 번만 실행 (렉 방지)
if unit_data then
    for _, names in pairs(unit_data) do
        local engName = names[1]
        local korName = names[2]
        normalized_db[Normalize(engName)] = korName
    end
end

-- 2. 유닛 툴팁 처리 함수 (루프 없음, 0.001초 미만 소요)
local function UpdateUnitTooltip(tooltip)
    local _, unit = tooltip:GetUnit()
    if not unit then return end

    local left1 = _G[tooltip:GetName() .. "TextLeft1"]
    if not left1 then return end
    local tooltipUnitName = left1:GetText()

    if tooltipUnitName then
        local normalizedName = Normalize(tooltipUnitName)
        local korName = normalized_db[normalizedName]

        -- 한글 이름이 존재하고, 현재 이름과 다를 경우에만 교체
        if korName and left1:GetText() ~= korName then
            left1:SetText(korName)
            tooltip:Show()
        end
    end
end

-- 3. 후크 등록
GameTooltip:HookScript("OnTooltipSetUnit", UpdateUnitTooltip)
-- 간혹 OnTooltipSetUnit 이벤트가 발생하지 않는 상황을 대비
GameTooltip:HookScript("OnShow", UpdateUnitTooltip)
