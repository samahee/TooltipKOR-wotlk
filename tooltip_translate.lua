-- tooltip_translate.lua
-- Translates Blizzard option tooltip text without overwriting GlobalStrings.

local TranslateTable = tooltip_translate_data or {}
local installed = false
local translating = false

local function StripColors(text)
    if not text then return text end
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    return text
end

local function Trim(text)
    text = string.gsub(text or "", "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function TranslateText(text)
    if type(text) ~= "string" or text == "" then return text end

    local translated = TranslateTable[text]
    if translated then return translated end

    local plain = StripColors(text)
    translated = TranslateTable[plain]
    if translated then return translated end

    plain = Trim(plain)
    translated = TranslateTable[plain]
    if translated then return translated end

    return text
end

local function TranslateTooltipLines(tooltip)
    if translating or not tooltip or not tooltip.GetName or not tooltip.NumLines then return end

    local name = tooltip:GetName()
    if not name then return end

    translating = true
    for i = 1, tooltip:NumLines() do
        local leftLine = _G[name .. "TextLeft" .. i]
        if leftLine and leftLine.GetText and leftLine.SetText then
            local text = leftLine:GetText()
            local translated = TranslateText(text)
            if translated ~= text then leftLine:SetText(translated) end
        end

        local rightLine = _G[name .. "TextRight" .. i]
        if rightLine and rightLine.GetText and rightLine.SetText then
            local text = rightLine:GetText()
            local translated = TranslateText(text)
            if translated ~= text then rightLine:SetText(translated) end
        end
    end
    translating = false
end

local function WrapTooltip(tooltip)
    if not tooltip or tooltip.__TKOR_OptionTooltipHooked then return end

    if tooltip.SetText then
        local origSetText = tooltip.SetText
        tooltip.SetText = function(self, text, ...)
            return origSetText(self, TranslateText(text), ...)
        end
    end

    if tooltip.AddLine then
        local origAddLine = tooltip.AddLine
        tooltip.AddLine = function(self, text, ...)
            return origAddLine(self, TranslateText(text), ...)
        end
    end

    if tooltip.AddDoubleLine then
        local origAddDoubleLine = tooltip.AddDoubleLine
        tooltip.AddDoubleLine = function(self, leftText, rightText, ...)
            return origAddDoubleLine(self, TranslateText(leftText), TranslateText(rightText), ...)
        end
    end

    tooltip:HookScript("OnShow", TranslateTooltipLines)
    tooltip.__TKOR_OptionTooltipHooked = true
end

local function Install()
    if installed then return end
    installed = true

    WrapTooltip(GameTooltip)
    if ItemRefTooltip then WrapTooltip(ItemRefTooltip) end
end

Install()
