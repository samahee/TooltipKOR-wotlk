-- map.lua (Vanilla 1.12 / Lua 5.0 safe)
-- 요구: data/map_koKR.lua 의 MAP_KR, data/subzones_koKR.lua 의 SUBZ_KR 선로드
-- SUBZ_KR(서브존) → MAP_KR(대륙/지역) 우선순위로 정규화 매칭하여
-- 월드맵 드롭다운/라벨/타이틀 + 화면 중앙 라벨 + 미니맵 위 라벨을 한글화

TooltipKOR = TooltipKOR or {}
TooltipKOR.Map = TooltipKOR.Map or {}

-- ================= 정규화 유틸 =================
local function tkor_strip_color(s)
  s = string.gsub(s or "", "|c%x%x%x%x%x%x%x%x", "")
  s = string.gsub(s, "|r", "")
  return s
end
local function tkor_trim(s)
  s = string.gsub(s or "", "^%s+", ""); s = string.gsub(s, "%s+$", ""); return s
end
local function tkor_normalize_key(s)
  if type(s) ~= "string" then return s end
  s = tkor_strip_color(s)
  s = string.gsub(s, "[\r\n]", " ")
  s = string.gsub(s, "%s+", " ")
  s = tkor_trim(s)
  s = string.gsub(s, "^The%s+", "")  -- 'The ' 접두어 제거
  s = string.gsub(s, "%s*%-%s*", "-")
  s = string.lower(s)                 -- 대/소문자 무시
  return s
end

-- ================= 소스 테이블 구성 =================
local SOURCES -- { {raw=SUBZ_KR, norm=...}, {raw=MAP_KR, norm=...} }
local function build_norm(src)
  local norm = {}
  if type(src) == "table" then
    for en, ko in pairs(src) do
      if type(en)=="string" and ko and ko~="" then
        local k = tkor_normalize_key(en)
        if k ~= "" and not norm[k] then norm[k] = ko end
      end
    end
  end
  return norm
end
local function ensure_sources()
  if SOURCES then return end
  SOURCES = {}
  if type(_G.SUBZ_KR) == "table" then
    table.insert(SOURCES, { raw=_G.SUBZ_KR, norm=build_norm(_G.SUBZ_KR) })
  end
  if type(_G.MAP_KR) == "table" then
    table.insert(SOURCES, { raw=_G.MAP_KR,  norm=build_norm(_G.MAP_KR)  })
  end
end

local function KR(s)
  if type(s) ~= "string" or s == "" then return s end
  ensure_sources()
  -- 1) 원키 매칭 (SUBZ → MAP)
  for i=1, (SOURCES and #SOURCES or 0) do
    local raw = SOURCES[i].raw
    if raw and raw[s] and raw[s] ~= "" then return raw[s] end
  end
  -- 2) 정규화 매칭 (SUBZ → MAP)
  local ns = tkor_normalize_key(s)
  for i=1, (SOURCES and #SOURCES or 0) do
    local v = SOURCES[i].norm and SOURCES[i].norm[ns]
    if v and v ~= "" then return v end
  end
  return s
end

-- ================= FontString:SetText 래핑 =================
local function WrapSetText(fsname)
  local fs = (getglobal and getglobal(fsname)) or (_G and _G[fsname])
  if fs and fs.SetText and not fs.__TKOR_wrapped then
    local orig = fs.SetText
    fs.SetText = function(self, txt)
      if type(txt)=="string" then txt = KR(txt) end
      return orig(self, txt)
    end
    fs.__TKOR_wrapped = true
  end
end

-- 월드맵 선택값/라벨/타이틀 + 화면 중앙 + 미니맵 위 라벨 래핑
WrapSetText("WorldMapContinentDropDownText")
WrapSetText("WorldMapZoneDropDownText")
WrapSetText("WorldMapFrameAreaLabel")
WrapSetText("WorldMapFrameTitleText")
WrapSetText("WorldMapFrameTitle")
WrapSetText("ZoneTextString")
WrapSetText("SubZoneTextString")
WrapSetText("MinimapZoneText")  -- ← 미니맵 라벨을 여기서 처리

-- ================= 월드맵 라벨 사후 보정 =================
local function FixWorldMapLabelsOnce()
  local L = (getglobal and getglobal("WorldMapFrameAreaLabel")) or (_G and _G["WorldMapFrameAreaLabel"])
  if L and L.GetText and L.SetText then
    local t = L:GetText(); if t and t~="" then local k=KR(t); if k~=t then L:SetText(k) end end
  end
  local T = (getglobal and getglobal("WorldMapFrameTitleText")) or (_G and _G["WorldMapFrameTitleText"])
  if not T then T = (getglobal and getglobal("WorldMapFrameTitle")) or (_G and _G["WorldMapFrameTitle"]) end
  if T and T.GetText and T.SetText then
    local t2 = T:GetText(); if t2 and t2~="" then local k2=KR(t2); if k2~=t2 then T:SetText(k2) end end
  end
end

-- ================= 함수 후킹(사후) =================
local function HookAfter(fn_name, post)
  local orig = (getglobal and getglobal(fn_name)) or (_G and _G[fn_name])
  if type(orig) ~= "function" then return end
  local function w(a1,a2,a3,a4) local r1,r2,r3,r4=orig(a1,a2,a3,a4); post(); return r1,r2,r3,r4 end
  if setglobal then setglobal(fn_name, w) end
  if _G then _G[fn_name] = w end
end

-- ================= 드롭다운(대륙/지역) 한글화 =================
local function GetInitMenuName()
  local ref = (getglobal and getglobal("UIDROPDOWNMENU_INIT_MENU")) or (_G and _G["UIDROPDOWNMENU_INIT_MENU"])
  if type(ref)=="table" then
    if ref.GetName then local ok,name=pcall(function() return ref:GetName() end); if ok and name then return name end end
    return ""
  elseif type(ref)=="string" then return ref end
  return ""
end
local function IsWorldMapDropDown()
  local n = GetInitMenuName()
  return (n=="WorldMapContinentDropDown" or n=="WorldMapZoneDropDown"
       or n=="WorldMapFrameContinentDropDown" or n=="WorldMapFrameZoneDropDown")
end
local function Wrap_AddButton_Once()
  if TooltipKOR.Map.__dd_wrapped then return end
  local add = (getglobal and getglobal("UIDropDownMenu_AddButton")) or (_G and _G["UIDropDownMenu_AddButton"])
  if type(add) ~= "function" then return end
  local orig = add
  local function add_wrap(info, level)
    if info and info.text and IsWorldMapDropDown() then info.text = KR(info.text) end
    return orig(info, level)
  end
  if setglobal then setglobal("UIDropDownMenu_AddButton", add_wrap) end
  if _G then _G["UIDropDownMenu_AddButton"] = add_wrap end
  TooltipKOR.Map.__dd_wrapped = true
end
local function FixOpenDropDownOnce()
  if not IsWorldMapDropDown() then return end
  local list = (getglobal and getglobal("DropDownList1")) or (_G and _G["DropDownList1"])
  if not (list and list.IsShown and list:IsShown()) then return end
  local i=1; while true do
    local btn = (getglobal and getglobal("DropDownList1Button"..i)) or (_G and _G["DropDownList1Button"..i])
    if not btn then break end
    local fs = btn.NormalText or (btn.GetName and getglobal(btn:GetName().."NormalText")) or (btn.GetFontString and btn:GetFontString())
    if fs and fs.GetText and fs.SetText then
      local t = fs:GetText(); if t and t~="" then local k=KR(t); if k~=t then fs:SetText(k) end end
    end
    i=i+1
  end
end
local function EnsureDropDownHooks() Wrap_AddButton_Once() end
local function OnMenuToggle() Wrap_AddButton_Once(); FixOpenDropDownOnce() end

-- 후킹/보정
EnsureDropDownHooks()
HookAfter("WorldMapFrame_Update", EnsureDropDownHooks)
HookAfter("ToggleWorldMap",       EnsureDropDownHooks)
-- HookAfter("ToggleDropDownMenu",   OnMenuToggle)  -- 서브메뉴 에러 발생으로 비활성화

HookAfter("WorldMapFrame_Update", FixWorldMapLabelsOnce)
HookAfter("SetMapZoom",           FixWorldMapLabelsOnce)
HookAfter("ToggleWorldMap",       FixWorldMapLabelsOnce)

-- ================= 지역 변경 이벤트(중앙+미니맵 갱신) =================
local ev = CreateFrame and CreateFrame("Frame")
if ev then
  ev:RegisterEvent("ZONE_CHANGED")
  ev:RegisterEvent("ZONE_CHANGED_INDOORS")
  ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:SetScript("OnEvent", function()
    local sub = GetSubZoneText and GetSubZoneText() or ""
    local zon = GetZoneText and GetZoneText() or ""
    local target, fsname
    if sub and sub~="" then target=KR(sub); fsname="SubZoneTextString"
    elseif zon and zon~="" then target=KR(zon); fsname="ZoneTextString" end
    if target and fsname then
      local FS = (getglobal and getglobal(fsname)) or (_G and _G[fsname])
      if FS and FS.SetText then FS:SetText(target) end
    end
    -- 미니맵 라벨도 즉시 보정
    local MZ = (getglobal and getglobal("MinimapZoneText")) or (_G and _G["MinimapZoneText"])
    if MZ and MZ.GetText and MZ.SetText then
      local mt = MZ:GetText()
      if mt and mt~="" then
        local mk = KR(mt)
        if mk ~= mt then MZ:SetText(mk) end
      end
    end
  end)
end

-- 시작 시 1회 보정
FixWorldMapLabelsOnce()
