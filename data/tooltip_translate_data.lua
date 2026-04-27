-- tooltip_translate 번역 사전
-- 단어만 등록 - 숫자 제거, 마침표 무시
tooltip_translate_data = {
    -- 정확한 문구 매칭
    ["Improves your chance to hit with melee and ranged attacks by 1%"] = "근접 및 원거리 적중률 1% 증가",
    ["Increases your damage and healing by up to 20"] = "주문 공격력 및 치유량 최대 20 증가",
    ["Chance on melee attack to increase your damage and healing done by magical spells and effects by up to 95 for 10 sec"] = "근접 공격 시 일정 확률로 10초 동안 마법 주문 및 효과의 공격력과 치유량이 최대 95 증가",
    
    -- 능력치 (숫자 없이 단어만)
    -- ["Strength"] = "힘",
    -- ["Agility"] = "민첩성",
    -- ["Stamina"] = "체력",
    -- ["Intellect"] = "지능",
    -- ["Spirit"] = "정신력",
    -- ["Armor"] = "방어도",
    -- ["Attack Power"] = "전투력",
    -- ["All Resistances"] = "모든 저항",
    
    -- 품질 및 기본 정보
    -- ["Poor"] = "하급",
    -- ["Common"] = "일반",
    -- ["Uncommon"] = "고급",
    -- ["Rare"] = "희귀",
    -- ["Epic"] = "영웅",
    -- ["Legendary"] = "전설",
    
    -- 귀속 정보
    ["Binds when equipped"] = "착용 시 귀속",
    ["Binds when picked up"] = "획득 시 귀속",
    ["Soulbound"] = "귀속 아이템",
    ["Currently Equipped"] = "착용 중인 아이템",
    
    -- 부위 및 슬롯
    -- ["Wrist"] = "손목",
    -- ["Head"] = "머리",
    -- ["Neck"] = "목",
    -- ["Shoulder"] = "어깨",
    -- ["Chest"] = "가슴",
    -- ["Waist"] = "허리",
    -- ["Legs"] = "다리",
    -- ["Feet"] = "발",
    -- ["Finger"] = "손가락",
    -- ["Back"] = "등",
    -- ["Main Hand"] = "주손",
    -- ["Off Hand"] = "보조 무기",
    -- ["One-Hand"] = "한손 무기",
    -- ["Two-Hand"] = "양손 무기",
    -- ["Trinket"] = "장신구",
    -- ["Ranged"] = "원거리 무기",
    -- ["Relic"] = "성물",
    
    -- 방어구 타입 (우측 텍스트 사용)
    ["Plate"] = "판금",
    ["Mail"] = "사슬",
    ["Leather"] = "가죽",
    ["Cloth"] = "천",
    
    -- 무기 타입
    ["Mace"] = "둔기",
    ["Axe"] = "도끼",
    ["Sword"] = "검",
    ["Dagger"] = "단검",
    ["Hammer"] = "망치",
    ["Staff"] = "지팡이",
    ["Bow"] = "활",
    ["Gun"] = "총",
    ["Crossbow"] = "석궁",
    ["Polearm"] = "봉",
    ["Wand"] = "지팡이",
    ["Shield"] = "방패",
    ["Fist Weapon"] = "장착 무기",
    ["Arrow"] = "화살",
    ["Bullet"] = "탄환",
    
    -- 무기 속성
    -- ["Damage"] = "피해",
    -- ["Damage per second"] = "초당 피해",
    -- ["Speed"] = "속도",
    
    -- 아이템 정보
    -- ["Durability"] = "내구도",
    -- ["Requires Level"] = "필요 레벨",
    -- ["Item Level"] = "아이템 레벨",
    -- ["Value"] = "가격",
}


-- 간단한 테이블 길이 구하기 함수
function TranslationTableLen(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end
