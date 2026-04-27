-- buff_dbuff.lua  (WoW 3.3.5 / Lua 5.1 호환)
-- 중앙 전투 텍스트/에러 텍스트에 표시되는 버프/디버프 "이름만" 한글로 치환.
-- 요구: spell_name_data.lua 선로드

TooltipKOR = TooltipKOR or {}
TooltipKOR.Aura = TooltipKOR.Aura or {}
if TooltipKOR.Aura.__installed then return end
TooltipKOR.Aura.__installed = true

------------------------------------------------------------
-- 데이터 연동
------------------------------------------------------------
-- 사용자가 제공한 spell_name_data.lua의 테이블을 참조합니다.
local KR_DB = _G["spell_name_data"] or spell_name_data or {}
local NORM_DB = nil

------------------------------------------------------------
-- 유틸
------------------------------------------------------------
local function strip_color(s)
  s = string.gsub(s or "", "|c%x%x%x%x%x%x%x%x", "")
  s = string.gsub(s, "|r", "")
  return s
end

local function trim(s)
  s = string.gsub(s or "", "^%s+", "")
  s = string.gsub(s, "%s+$", "")
  return s
end

local function normalize_key(s)
  if type(s) ~= "string" then return s end
  s = strip_color(s)
  s = string.gsub(s, "[\r\n]", " ")
  s = string.gsub(s, "%s+", " ")
  s = trim(s)
  s = string.gsub(s, "^The%s+", "")
  s = string.gsub(s, "%s*%-%s*", "-")
  return string.lower(s)
end

-- 대소문자나 공백이 달라도 매칭될 수 있도록 정규화된 DB 캐싱
local function build_norm_db()
  if NORM_DB then return end
  NORM_DB = {}
  for en, ko in pairs(KR_DB) do
    if type(en) == "string" and type(ko) == "string" then
      local n = normalize_key(en)
      if n ~= "" and not NORM_DB[n] then
        NORM_DB[n] = ko
      end
    end
  end
end

------------------------------------------------------------
-- 주문 한글 치환기
------------------------------------------------------------
local function KR_SPELL(name)
  if type(name) ~= "string" or name == "" then return name end

  -- 1. 대소문자 포함 원본 매칭 시도
  local ko = KR_DB[name]
  if ko and ko ~= "" then return ko end

  -- 2. 정규화 후 매칭 시도
  if not NORM_DB then build_norm_db() end
  ko = NORM_DB[normalize_key(name)]

  return (ko and ko ~= "") and ko or name
end

------------------------------------------------------------
-- 메시지 재작성
------------------------------------------------------------
local function rewrite_aura_message(text)
  if type(text) ~= "string" or text == "" then return text end

  -- <영문주문> 또는 <영문주문> + 꼬리말
  do
    local s, e, inner, tail = string.find(text, "^%s*%<([^>]+)%>(.*)$")
    if s then
      local new_tail = tail or ""
      if new_tail == " fades" then new_tail = " 사라짐"
      elseif new_tail == " fades from you" then new_tail = " 사라짐 (본인)"
      elseif new_tail == " is removed" then new_tail = " 사라짐"
      end
      return "<" .. KR_SPELL(inner) .. ">" .. new_tail
    end
  end

  -- +버프 (시전자)
  do
    local s, e, cap, who = string.find(text, "^%+(.-)%s*%((.+)%)$")
    if s then return "+" .. KR_SPELL(cap) .. " (" .. who .. ")" end
  end
  -- -버프 (시전자)
  do
    local s, e, cap, who = string.find(text, "^%-(.-)%s*%((.+)%)$")
    if s then return "-" .. KR_SPELL(cap) .. " (" .. who .. ")" end
  end

  -- +버프 / -버프
  do
    local s, e, cap = string.find(text, "^%+(.*)$")
    if s then return "+" .. KR_SPELL(cap) end
  end
  do
    local s, e, cap = string.find(text, "^%-(.*)$")
    if s then return "-" .. KR_SPELL(cap) end
  end

  -- 안전망: 영문 기본 포맷 (fades, removed 등)
  do
    local s, e, cap = string.find(text, "^(.*) fades$")
    if s then return "<" .. KR_SPELL(cap) .. "> 사라짐" end
  end
  do
    local s, e, cap = string.find(text, "^(.*) fades from you$")
    if s then return "<" .. KR_SPELL(cap) .. "> 사라짐 (본인)" end
  end
  do
    local s, e, cap = string.find(text, "^(.*) is removed$")
    if s then return "<" .. KR_SPELL(cap) .. "> 사라짐" end
  end
  do
    local s, e, cap = string.find(text, "^(.*) is removed by .+$")
    if s then return "<" .. KR_SPELL(cap) .. "> 사라짐" end
  end

  return text
end

------------------------------------------------------------
-- 후킹 (함수 생성 시점에 맞춰 설치)
------------------------------------------------------------
local function install_ct_hook_if_ready()
  if TooltipKOR.Aura.__ct_wrapped then return end
  local fn = _G["CombatText_AddMessage"]
  if type(fn) ~= "function" then return end

  local orig = fn
  -- Lua 5.1 가변 인자를 사용하여 호환성과 안정성 강화
  _G["CombatText_AddMessage"] = function(msg, ...)
    if type(msg) == "string" then
      msg = rewrite_aura_message(msg)
    end
    return orig(msg, ...)
  end
  TooltipKOR.Aura.__ct_wrapped = true
end

local function install_ui_err_hook_if_ready()
  if TooltipKOR.Aura.__err_wrapped then return end
  local f = _G["UIErrorsFrame"]
  if not f or not f.AddMessage then return end

  local orig = f.AddMessage
  f.AddMessage = function(self, msg, ...)
    if type(msg) == "string" then
      msg = rewrite_aura_message(msg)
    end
    return orig(self, msg, ...)
  end
  TooltipKOR.Aura.__err_wrapped = true
end

-- 즉시 시도 + 이벤트/폴링 재시도
install_ct_hook_if_ready()
install_ui_err_hook_if_ready()

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("VARIABLES_LOADED")
ev:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" and arg1 == "Blizzard_CombatText" then
    install_ct_hook_if_ready()
  else
    install_ct_hook_if_ready()
    install_ui_err_hook_if_ready()
  end
end)

-- 안전장치: 처음 5초간 폴링
local elapsed, limit = 0, 5
ev:SetScript("OnUpdate", function(self, dt)
  elapsed = elapsed + (dt or 0)
  if elapsed < limit then
    install_ct_hook_if_ready()
    install_ui_err_hook_if_ready()
  else
    self:SetScript("OnUpdate", nil)
  end
end)
