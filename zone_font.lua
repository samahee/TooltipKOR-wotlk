-- zone_font.lua
-- 지역명 및 월드맵에 한글판 특유의 근사한 폰트를 적용하는 스크립트

-- [설정] 폰트 경로 (Fonts 폴더 안에 해당 폰트 파일이 있어야 함)
local FONT_PATH = "Interface\\AddOns\\TooltipKOR-wotlk\\Fonts\\K_Pagetext.TTF"

-- 1. 화면 중앙 지역명 폰트 설정
local function ApplyZoneFonts()
    if ZoneTextString then
        ZoneTextString:SetFont(FONT_PATH, 32, "THICKOUTLINE")
    end
    if SubZoneTextString then
        SubZoneTextString:SetFont(FONT_PATH, 24, "THICKOUTLINE")
    end
    if PVPInfoTextString then
        PVPInfoTextString:SetFont(FONT_PATH, 20, "OUTLINE")
    end
    -- if MinimapZoneText then
    --     MinimapZoneText:SetFont(FONT_PATH, 12, "OUTLINE")
    -- end
end

-- 2. 월드맵 관련 폰트 설정
local function ApplyMapFonts()
    -- 월드맵 지역 레이블 (지도 위에 마우스 올릴 때 나오는 이름 등)
    if WorldMapFrameAreaLabel then
        WorldMapFrameAreaLabel:SetFont(FONT_PATH, 24, "THICKOUTLINE")
    end
    -- 월드맵 타이틀 (상단 제목)
    if WorldMapFrameTitleText then
        WorldMapFrameTitleText:SetFont(FONT_PATH, 16, "OUTLINE")
    end
    -- 월드맵 드롭다운 메뉴 텍스트
    if WorldMapContinentDropDownText then
        WorldMapContinentDropDownText:SetFont(FONT_PATH, 12, "OUTLINE")
    end
    if WorldMapZoneDropDownText then
        WorldMapZoneDropDownText:SetFont(FONT_PATH, 12, "OUTLINE")
    end
end

-- 이벤트 프레임 생성 (지역 변경 시마다 폰트 재적용)
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("ZONE_CHANGED")
f:SetScript("OnEvent", function()
    -- 시스템 폰트 초기화 이후에 덮어씌우기 위해 지연 실행
    C_Timer.After(0.1, function()
        ApplyZoneFonts()
        ApplyMapFonts()
    end)
end)

-- 월드맵이 열릴 때도 폰트 적용
if WorldMapFrame then
    WorldMapFrame:HookScript("OnShow", ApplyMapFonts)
end

-- 애드온 로드 직후 즉시 실행
ApplyZoneFonts()
ApplyMapFonts()
