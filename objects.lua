-- objects.lua

local normalized_db = {}
-- (Normalize 및 InitializeObjectDB 함수는 동일)
local function Normalize(str)
    if not str then return "" end
    return string.lower(string.gsub(str, "['\",%.%s]+", ""))
end

local function InitializeObjectDB()
    if object_data then
        for id, names in pairs(object_data) do
            normalized_db[id] = names[2]
            normalized_db[Normalize(names[1])] = names[2]
        end
    end
end
InitializeObjectDB()

local function UpdateObjectTooltip(tooltip)
    if not tooltip or not tooltip:IsShown() then return end

    local left1 = _G[tooltip:GetName() .. "TextLeft1"]
    if not left1 then return end

    local title = left1:GetText()
    if not title or title == "" then return end

    -- 1. 유닛 체크: UnitExists는 1 대신 true/false로 판별하는 것이 안전합니다.
    -- 마우스오버 유닛이 존재하고 이름이 툴팁 타이틀과 같다면 오브젝트 번역을 건너뜁니다.
    if UnitExists("mouseover") then
        local uname = UnitName("mouseover")
        if uname and Normalize(uname) == Normalize(title) then
            return
        end
    end

    -- 2. 오브젝트 번역 수행
    local normTitle = Normalize(title)
    local korName = normalized_db[normTitle] or normalized_db[title] -- 원본 키값 검색 추가

    if korName and title ~= korName then
        left1:SetText(korName)
        -- 툴팁 크기를 강제로 재계산하여 레이아웃 깨짐 방지
        tooltip:Show()
    end
end

-- 이벤트 후크 강화
-- 툴팁 내용이 바뀔 때 발생하는 이벤트를 최대한 활용합니다.
GameTooltip:HookScript("OnTooltipSetUnit", function(self) UpdateObjectTooltip(self) end)
GameTooltip:HookScript("OnTooltipSetItem", function(self) UpdateObjectTooltip(self) end)
GameTooltip:HookScript("OnUpdate", function(self) UpdateObjectTooltip(self) end) -- OnShow보다 빈도가 높고 정확함

-- 기존 OnUpdate 프레임은 삭제하거나 아래와 같이 수정하여
-- 툴팁 내용이 갱신될 때만 동작하게 최적화합니다.
local f = CreateFrame("Frame")
f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
f:SetScript("OnEvent", function()
    UpdateObjectTooltip(GameTooltip)
end)
