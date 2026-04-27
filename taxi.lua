-- taxi.lua
-- Taxi 노드 툴팁 제목을 SUBZ_KR → MAP_KR 우선순위로 한글 치환 (콤마 분할 지원)
-- 전제: data/map_koKR.lua 의 MAP_KR, data/subzones_koKR.lua 의 SUBZ_KR 이 선로드

TooltipKOR = TooltipKOR or {}
TooltipKOR.Taxi = TooltipKOR.Taxi or {}

if TooltipKOR.Taxi.__installed then return end
TooltipKOR.Taxi.__installed = true

-- ========= 정규화 유틸 ('The ' 제거 포함, Lua 5.0) =========
local MAP_KR_NORM, SUBZ_KR_NORM = nil, nil

local function tkor_strip_color(s)
  s = string.gsub(s or "", "|c%x%x%x%x%x%x%x%x", "")
  s = string.gsub(s, "|r", "")
  return s
end

local function tkor_trim(s)
  s = string.gsub(s or "", "^%s+", "")
  s = string.gsub(s, "%s+$", "")
  return s
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

local function build_norm_tables_once()
  if not SUBZ_KR_NORM and type(SUBZ_KR)=="table" then
    SUBZ_KR_NORM = {}
    for en, ko in pairs(SUBZ_KR) do
      if type(en)=="string" and ko and ko~="" then
        local n = tkor_normalize_key(en)
        if n ~= "" and not SUBZ_KR_NORM[n] then SUBZ_KR_NORM[n] = ko end
      end
    end
  end
  if not MAP_KR_NORM and type(MAP_KR)=="table" then
    MAP_KR_NORM = {}
    for en, ko in pairs(MAP_KR) do
      if type(en)=="string" and ko and ko~="" then
        local n = tkor_normalize_key(en)
        if n ~= "" and not MAP_KR_NORM[n] then MAP_KR_NORM[n] = ko end
      end
    end
  end
end

-- 기본 치환: SUBZ_KR → MAP_KR (정확 → 정규화)
local function KR(s)
  if type(s) ~= "string" or s == "" then return s end
  -- 1) 정확 일치
  if SUBZ_KR and SUBZ_KR[s] and SUBZ_KR[s] ~= "" then return SUBZ_KR[s] end
  if MAP_KR  and MAP_KR[s]  and MAP_KR[s]  ~= "" then return MAP_KR[s]  end
  -- 2) 정규화 일치
  build_norm_tables_once()
  local ns = tkor_normalize_key(s)
  if SUBZ_KR_NORM and ns and SUBZ_KR_NORM[ns] then return SUBZ_KR_NORM[ns] end
  if MAP_KR_NORM  and ns and MAP_KR_NORM[ns]  then return MAP_KR_NORM[ns]  end
  return s
end

-- "노드, 지역" 같은 합성 타이틀 처리
local function KR_Composed(title)
  if type(title) ~= "string" or title == "" then return title end
  -- 1) 전체 매핑 우선
  local full = KR(title)
  if full ~= title then return full end

  -- 2) 콤마 분할 후 각 파트 매핑
  local changed, parts, i = false, {}, 1
  for seg in string.gfind(title, "([^,]+)") do
    local p  = tkor_trim(seg)
    local kp = KR(p)
    if kp ~= p then changed = true end
    parts[i] = kp; i = i + 1
  end
  if changed and i > 2 then
    return table.concat(parts, ", ")
  end

  return title
end

-- ========= 툴팁 첫 줄 교체 =========
local function ReplaceTaxiTooltipTitleFromTooltip()
  local tip = GameTooltip
  if not tip or not tip.GetName or not tip.NumLines then return end
  local name = tip:GetName() or "GameTooltip"
  local L1 = (getglobal and getglobal(name.."TextLeft1")) or (_G and _G[name.."TextLeft1"])
  if not (L1 and L1.GetText and L1.SetText) then return end

  local t = L1:GetText()
  if not t or t == "" then return end

  local ko = KR_Composed(t)
  if ko ~= t then
    L1:SetText(ko)
    if tip.Show then tip:Show() end
  end
end

-- ========= 글로벌 함수 후킹 (원본 실행 후 제목만 교체) =========
local function HookTaxiNodeOnButtonEnter()
  local orig = (getglobal and getglobal("TaxiNodeOnButtonEnter")) or (_G and _G["TaxiNodeOnButtonEnter"])
  if type(orig) ~= "function" then return end
  local function wrapper(btn)
    orig(btn)                       -- 원본 툴팁 생성
    ReplaceTaxiTooltipTitleFromTooltip()
  end
  if setglobal then setglobal("TaxiNodeOnButtonEnter", wrapper) end
  if _G then _G["TaxiNodeOnButtonEnter"] = wrapper end
end

HookTaxiNodeOnButtonEnter()
