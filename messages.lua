-- messages.lua
-- Translates ERR_* style messages after they are emitted, without overwriting GlobalStrings.

local MessageData = messages_data or {}
local exactMessages = {}
local patternMessages = {}
local itemNameMap
local placeNameMap
local installed = false
local debugQuestMessages = false
local lastAcceptedQuestIndex
local questLinkUpdater

local captureTypeRules = {
    ["Discovered %s: %d experience gained"] = { "map" },
    ["Discovered: %s"] = { "map" },
    ["You are now in the queue to join a party for %s."] = { "map" },
    ["You have left the queue to join a party for %s."] = { "map" },
    ["Your group has joined the queue for %s"] = { "map" },

    ["Your skill in %s has increased to %d."] = { "skill" },
    ["You have gained %s proficiency."] = { "skill" },
    ["You have gained the %s skill."] = { "skill" },
    ["Requires %s %d"] = { "skill" },

    ["You have learned a new ability: %s."] = { "spell" },
    ["You have learned a new spell: %s."] = { "spell" },
    ["You have learned how to create a new item: %s."] = { "item" },
    ["You already know %s."] = { "spell" },
    ["You have unlearned %s."] = { "spell" },
    ["Your pet already knows %s."] = { "spell" },
    ["Your pet has learned a new ability: %s."] = { "spell" },
    ["Your pet has learned a new spell: %s."] = { "spell" },
    ["Your pet has unlearned %s."] = { "spell" },

    ["You loot %s"] = { "item" },
    ["Received item: %s."] = { "item" },
    ["Received %d of item: %s."] = { nil, "item" },
    ["You receive item: %s."] = { "item" },
    ["You receive item: %sx%d."] = { "item" },
    ["You receive loot: %s."] = { "item" },
    ["You receive loot: %sx%d."] = { "item" },
    ["You create: %s."] = { "item" },
    ["You create: %sx%d."] = { "item" },
    ["You won an auction for %s"] = { "item" },
    ["Your auction of %s has expired."] = { "item" },
    ["Your auction of %s has been cancelled by the seller."] = { "item" },
    ["A buyer has been found for your auction of %s."] = { "item" },
    ["You have been outbid on %s."] = { "item" },
    ["%s receives loot: %s."] = { "player", "item" },
    ["%s receives loot: %sx%d."] = { "player", "item" },
    ["Everyone passed on: %s"] = { "item" },
    ["%s has selected Disenchant for: %s"] = { "player", "item" },
    ["You have selected Disenchant for: %s"] = { "item" },
    ["%s has selected Greed for: %s"] = { "player", "item" },
    ["You have selected Greed for: %s"] = { "item" },
    ["%s has selected Need for: %s"] = { "player", "item" },
    ["You have selected Need for: %s"] = { "item" },
    ["%s passed on: %s"] = { "player", "item" },
    ["%s automatically passed on: %s because he cannot loot that item."] = { "player", "item" },
    ["%s automatically passed on: %s because she cannot loot that item."] = { "player", "item" },
    ["You passed on: %s"] = { "item" },
    ["You automatically passed on: %s because you cannot loot that item."] = { "item" },
    ["Disenchant Roll - %d for %s by %s"] = { nil, "item", "player" },
    ["Greed Roll - %d for %s by %s"] = { nil, "item", "player" },
    ["Need Roll - %d for %s by %s"] = { nil, "item", "player" },
    ["%s won: %s"] = { "player", "item" },
    ["%1$s won: %3$s |cff818181(Disenchant - %2$d)|r"] = { "player", nil, "item" },
    ["%1$s won: %3$s |cff818181(Greed - %2$d)|r"] = { "player", nil, "item" },
    ["%1$s won: %3$s |cff818181(Need - %2$d)|r"] = { "player", nil, "item" },
    ["You won: %s"] = { "item" },
    ["You won: %2$s |cff818181(Disenchant - %1$d)|r"] = { nil, "item" },
    ["You won: %2$s |cff818181(Greed - %1$d)|r"] = { nil, "item" },
    ["You won: %2$s |cff818181(Need - %1$d)|r"] = { nil, "item" },
}

local function TranslateMoneyUnits(text)
    if type(text) ~= "string" then return text end
    text = string.gsub(text, "Gold", "골드")
    text = string.gsub(text, "Silver", "실버")
    text = string.gsub(text, "Copper", "코퍼")
    return text
end

local function TranslateItemLinks(text)
    if type(text) ~= "string" or type(item_data) ~= "table" then return text end

    return string.gsub(text, "(|Hitem:(%d+):.-|h)%[(.-)%](|h)", function(linkStart, itemIdText, itemName, linkEnd)
        local itemId = tonumber(itemIdText)
        local data = itemId and item_data[itemId]
        local korName = type(data) == "table" and data[2]

        if type(korName) == "string" and korName ~= "" then
            return linkStart .. "[" .. korName .. "]" .. linkEnd
        end

        return linkStart .. "[" .. itemName .. "]" .. linkEnd
    end)
end

local function GetItemNameMap()
    if itemNameMap then return itemNameMap end

    itemNameMap = {}
    if type(item_data) == "table" then
        for _, data in pairs(item_data) do
            if type(data) == "table" and type(data[1]) == "string" and type(data[2]) == "string" then
                itemNameMap[data[1]] = data[2]
            end
        end
    end

    return itemNameMap
end

local function TranslatePlainItemNames(text)
    if type(text) ~= "string" or not string.find(text, "%[") or string.find(text, "|Hitem:") then return text end

    local names = GetItemNameMap()
    return string.gsub(text, "%[(.-)%]", function(itemName)
        return "[" .. (names[itemName] or itemName) .. "]"
    end)
end

local function TranslatePlainItemName(text)
    if type(text) ~= "string" then return text end

    local names = GetItemNameMap()
    return names[text] or text
end

local function GetPlaceNameMap()
    if placeNameMap then return placeNameMap end

    placeNameMap = {}
    if type(MAP_KR) == "table" then
        for from, to in pairs(MAP_KR) do
            if type(from) == "string" and type(to) == "string" then
                placeNameMap[from] = to
            end
        end
    end
    if type(SUBZ_KR) == "table" then
        for from, to in pairs(SUBZ_KR) do
            if type(from) == "string" and type(to) == "string" then
                placeNameMap[from] = to
            end
        end
    end

    return placeNameMap
end

local function TranslatePlaceName(text)
    if type(text) ~= "string" then return text end

    local names = GetPlaceNameMap()
    return names[text] or text
end

local function TranslateSpellName(text)
    if type(text) ~= "string" or type(spell_name_data) ~= "table" then return text end

    return spell_name_data[text] or text
end

local function TranslateDynamicParts(text)
    return TranslatePlainItemNames(TranslateItemLinks(TranslateMoneyUnits(text)))
end

local function StripMessageColors(text)
    if type(text) ~= "string" then return text end

    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    return text
end

local function TranslateColoredExactMessage(message)
    local colorStart, innerText, colorEnd = string.match(message, "^(|c%x%x%x%x%x%x%x%x)(.-)(|r)$")
    if colorStart and innerText and colorEnd then
        local exact = exactMessages[innerText]
        if exact then
            return colorStart .. TranslateDynamicParts(exact) .. colorEnd
        end
    end

    local stripped = StripMessageColors(message)
    if stripped ~= message then
        local exact = exactMessages[stripped]
        if exact then
            return TranslateDynamicParts(exact)
        end
    end

    return nil
end

local function EscapePatternChar(ch)
    if string.find("^$()%.[]*+-?", ch, 1, true) then
        return "%" .. ch
    end
    return ch
end

local function IsFormatSpecAt(text, index)
    local rest = string.sub(text, index)
    return string.match(rest, "^%%(%d+%$[-+ #0]*%d*%.?%d*[cdeEfgGiopsuXxqs])")
        or string.match(rest, "^%%([-+ #0]*%d*%.?%d*[cdeEfgGiopsuXxqs])")
end

local function SpecCapturePattern(spec, isLast)
    local final = string.sub(spec, -1)
    if final == "d" or final == "i" or final == "u" then
        return "([%-]?%d+)"
    elseif final == "f" or final == "g" or final == "G" or final == "e" or final == "E" then
        return "([%-]?%d+%.?%d*)"
    elseif final == "s" or final == "q" then
        return isLast and "(.+)" or "(.-)"
    end
    return isLast and "(.+)" or "(.-)"
end

local function TemplateToPattern(template)
    local parts = {}
    local specs = {}
    local i = 1
    local len = string.len(template)

    while i <= len do
        local ch = string.sub(template, i, i)
        if ch == "%" then
            local nextCh = string.sub(template, i + 1, i + 1)
            if nextCh == "%" then
                table.insert(parts, "%%")
                i = i + 2
            else
                local spec = IsFormatSpecAt(template, i)
                if spec then
                    table.insert(specs, spec)
                    table.insert(parts, SpecCapturePattern(spec, i + string.len(spec) >= len))
                    i = i + string.len(spec) + 1
                else
                    table.insert(parts, "%%")
                    i = i + 1
                end
            end
        else
            table.insert(parts, EscapePatternChar(ch))
            i = i + 1
        end
    end

    return "^" .. table.concat(parts) .. "$", specs
end

local function HasFormat(template)
    local index = string.find(template, "%%")
    return index and IsFormatSpecAt(template, index) ~= nil
end

local function TranslateCapturedValue(value, captureType)
    if type(value) ~= "string" or value == "" then return value end

    if captureType == "item" then
        return TranslatePlainItemName(TranslateDynamicParts(value))
    elseif captureType == "map" then
        return TranslatePlaceName(value)
    elseif captureType == "spell" then
        return TranslateSpellName(value)
    elseif captureType == "skill" then
        local exact = exactMessages[value]
        if exact then
            return TranslateDynamicParts(exact)
        end
        return value
    elseif captureType == "player" then
        return value
    end

    return TranslateDynamicParts(value)
end

local function FillTemplate(template, captures, sourceSpecs, captureTypes)
    local index = 0
    local captureValues = {}
    local result = {}
    local i = 1
    local len = string.len(template)

    for captureIndex, spec in ipairs(sourceSpecs or {}) do
        local positional = string.match(spec, "^(%d+)%$")
        if positional then
            captureValues[tonumber(positional)] = captures[captureIndex]
        else
            captureValues[captureIndex] = captures[captureIndex]
        end
    end

    while i <= len do
        local ch = string.sub(template, i, i)
        if ch == "%" then
            local nextCh = string.sub(template, i + 1, i + 1)
            if nextCh == "%" then
                table.insert(result, "%")
                i = i + 2
            else
                local spec = IsFormatSpecAt(template, i)
                if spec then
                    local positional = string.match(spec, "^(%d+)%$")
                    local captureIndex
                    if positional then
                        captureIndex = tonumber(positional)
                    else
                        index = index + 1
                        captureIndex = index
                    end

                    table.insert(result, TranslateCapturedValue(captureValues[captureIndex] or "", captureTypes and captureTypes[captureIndex]))
                    i = i + string.len(spec) + 1
                else
                    table.insert(result, ch)
                    i = i + 1
                end
            end
        else
            table.insert(result, ch)
            i = i + 1
        end
    end

    return TranslateDynamicParts(table.concat(result))
end

local function CompileMessages()
    for from, to in pairs(MessageData) do
        if type(from) == "string" and type(to) == "string" then
            if HasFormat(from) then
                local pattern, specs = TemplateToPattern(from)
                table.insert(patternMessages, { pattern = pattern, specs = specs, to = to, captureTypes = captureTypeRules[from], priority = string.len(from) })
            else
                exactMessages[from] = to
            end
        end
    end

    table.sort(patternMessages, function(a, b)
        return (a.priority or 0) > (b.priority or 0)
    end)
end

local function TranslateKnownMessage(message)
    if type(message) ~= "string" or message == "" then return message end

    local exact = exactMessages[message]
    if exact then return TranslateDynamicParts(exact) end

    local coloredExact = TranslateColoredExactMessage(message)
    if coloredExact then return coloredExact end

    for _, entry in ipairs(patternMessages) do
        local captures = { string.match(message, entry.pattern) }
        if captures[1] then
            return FillTemplate(entry.to, captures, entry.specs, entry.captureTypes)
        end
    end

    return nil
end

local function TranslateMessage(message)
    local translated = TranslateKnownMessage(message)
    if translated then return translated end

    return TranslateDynamicParts(message)
end

local function MessageEventFilter(self, event, message, ...)
    local translated = TranslateMessage(message)
    if translated ~= message then
        local info = ChatTypeInfo and ChatTypeInfo[string.match(event or "", "^CHAT_MSG_(.+)$")]
        if self and self.AddMessage then
            if info then
                self:AddMessage(translated, info.r, info.g, info.b, info.id)
            else
                self:AddMessage(translated)
            end
        end

        return true
    end

    return false
end

local function HookChatEvents()
    if type(ChatFrame_AddMessageEventFilter) ~= "function" then return end

    local events = {
        "CHAT_MSG_SYSTEM",
        "CHAT_MSG_LOOT",
        "CHAT_MSG_MONEY",
        "CHAT_MSG_SKILL",
        "CHAT_MSG_COMBAT_MISC_INFO",
    }

    for _, event in ipairs(events) do
        ChatFrame_AddMessageEventFilter(event, MessageEventFilter)
    end
end

local function HookUIErrorsFrame()
    if not UIErrorsFrame or UIErrorsFrame.__TKOR_MessageHooked or not UIErrorsFrame.AddMessage then return end

    -- UI_ERROR_MESSAGE and UI_INFO_MESSAGE are already routed here by Blizzard UI.
    -- Hook the final display call to translate once without duplicating messages.
    local origAddMessage = UIErrorsFrame.AddMessage
    UIErrorsFrame.AddMessage = function(self, message, ...)
        return origAddMessage(self, TranslateMessage(message), ...)
    end

    UIErrorsFrame.__TKOR_MessageHooked = true
end

local function HookCombatText()
    if type(CombatText_AddMessage) ~= "function" or _G.__TKOR_CombatTextHooked then return end

    local origCombatTextAddMessage = CombatText_AddMessage
    CombatText_AddMessage = function(message, ...)
        return origCombatTextAddMessage(TranslateKnownMessage(message) or message, ...)
    end

    _G.__TKOR_CombatTextHooked = true
end

local function IsEpochRealm()
    if type(GetRealmName) ~= "function" then return false end

    local realm = GetRealmName()
    return realm == "Kezan" or realm == "Gurubashi"
end

local function GetQuestTranslation(questId)
    local data
    if IsEpochRealm() and type(Quest_Data_epoch) == "table" then
        data = Quest_Data_epoch[questId]
    end
    if not data and type(Quest_Data_wotlk) == "table" then
        data = Quest_Data_wotlk[questId]
    end
    if not data and type(Quest_Data) == "table" then
        data = Quest_Data[questId]
    end

    if type(data) ~= "table" then return nil end

    local title = data.T or data[1]
    local objectives = data.O or data[3]
    if type(title) ~= "string" or title == "" then
        title = nil
    end
    if type(objectives) == "string" and objectives ~= "" then
        objectives = { objectives }
    elseif type(objectives) ~= "table" or not objectives[1] then
        objectives = nil
    end

    if not title and not objectives then return nil end
    return title, objectives
end

local function IsQuestTooltipSectionBreak(text)
    if type(text) ~= "string" then return false end

    return text == ""
        or text == "Requirements:"
        or text == "요구 조건:"
        or text == "Rewards:"
        or text == "보상:"
        or text == "Description"
        or text == "Objectives"
        or text == "Required Level:"
        or text == "Quest Level:"
        or string.find(text, "^Requirements:")
        or string.find(text, "^요구 조건:")
        or string.find(text, "^Rewards:")
        or string.find(text, "^Required Level:")
        or string.find(text, "^Quest Level:")
end

local function PrepareQuestTooltipLine(line, width)
    if not line then return end

    if line.SetWidth then
        line:SetWidth(width)
    end
    if line.SetWordWrap then
        line:SetWordWrap(true)
    end
    if line.SetNonSpaceWrap then
        line:SetNonSpaceWrap(true)
    end
end

local function UpdateQuestLinkTooltip(tooltip, questId)
    if not tooltip or not questId then return end

    local title, objectives = GetQuestTranslation(questId)
    if not title and not objectives then return end

    local name = tooltip:GetName()
    if not name then return end

    local originalWidth = tooltip:GetWidth() or 0
    local wrapWidth = originalWidth > 80 and (originalWidth - 36) or 420

    local titleLine = _G[name .. "TextLeft1"]
    if title and titleLine then
        PrepareQuestTooltipLine(titleLine, wrapWidth)
        titleLine:SetText(title)
    end

    if objectives then
        local objectiveText = table.concat(objectives, "\n")
        local objectiveLine
        local objectiveLineIndex
        local sectionStartIndex
        local lines = tooltip:NumLines() or 0

        for i = 3, lines do
            local line = _G[name .. "TextLeft" .. i]
            local text = line and line:GetText()

            if text and IsQuestTooltipSectionBreak(text) then
                sectionStartIndex = i
                break
            elseif text and text ~= "" and not objectiveLine then
                objectiveLine = line
                objectiveLineIndex = i
            elseif objectiveLine and text and IsQuestTooltipSectionBreak(text) then
                sectionStartIndex = i
                break
            end
        end

        if objectiveLine then
            PrepareQuestTooltipLine(objectiveLine, wrapWidth)
            objectiveLine:SetText(objectiveText)

            if sectionStartIndex then
                for i = (objectiveLineIndex or 0) + 1, sectionStartIndex - 1 do
                    local line = _G[name .. "TextLeft" .. i]
                    if line then
                        line:SetText("")
                    end
                end
            end
        elseif lines >= 2 and tooltip.AddLine then
            tooltip:AddLine(objectiveText, 1, 1, 1, true)
        end
    end

    if tooltip.SetWidth and originalWidth > 0 then
        tooltip:SetWidth(originalWidth)
    end
    tooltip:Show()
end

local function HookQuestLinks()
    if not ItemRefTooltip or ItemRefTooltip.__TKOR_QuestLinkHooked or not ItemRefTooltip.SetHyperlink then return end

    if not questLinkUpdater and CreateFrame then
        questLinkUpdater = CreateFrame("Frame")
        questLinkUpdater:Hide()
        questLinkUpdater:SetScript("OnUpdate", function(self)
            self:Hide()
            if self.tooltip and self.questId then
                UpdateQuestLinkTooltip(self.tooltip, self.questId)
            end
            self.tooltip = nil
            self.questId = nil
        end)
    end

    local function afterSetHyperlink(self, link)
        local questId = tonumber(string.match(link or "", "quest:(%d+)"))
        if questId then
            UpdateQuestLinkTooltip(self, questId)
            if questLinkUpdater then
                questLinkUpdater.tooltip = self
                questLinkUpdater.questId = questId
                questLinkUpdater:Show()
            end
        end
    end

    if type(hooksecurefunc) == "function" then
        hooksecurefunc(ItemRefTooltip, "SetHyperlink", afterSetHyperlink)
    else
        local origSetHyperlink = ItemRefTooltip.SetHyperlink
        ItemRefTooltip.SetHyperlink = function(self, link, ...)
            local result = origSetHyperlink(self, link, ...)
            afterSetHyperlink(self, link)
            return result
        end
    end

    ItemRefTooltip.__TKOR_QuestLinkHooked = true
end

local function DebugPrint(message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[TooltipKOR Debug]|r " .. tostring(message))
    end
end

local function HookQuestDebugEvents()
    if not debugQuestMessages or not CreateFrame then return end

    local frame = CreateFrame("Frame")
    local events = {
        "CHAT_MSG_SYSTEM",
        "CHAT_MSG_LOOT",
        "CHAT_MSG_MONEY",
        "UI_INFO_MESSAGE",
        "UI_ERROR_MESSAGE",
        "QUEST_ACCEPTED",
        "QUEST_DETAIL",
        "QUEST_GREETING",
        "QUEST_LOG_UPDATE",
        "QUEST_PROGRESS",
        "QUEST_COMPLETE",
        "QUEST_FINISHED",
        "QUEST_TURNED_IN",
    }

    for _, event in ipairs(events) do
        frame:RegisterEvent(event)
    end

    frame:SetScript("OnEvent", function(self, event, ...)
        local first = ...
        if event == "QUEST_LOG_UPDATE" and type(first) == "nil" then return end

        if event == "QUEST_ACCEPTED" then
            lastAcceptedQuestIndex = tonumber(first)
        end

        local parts = {}
        for i = 1, select("#", ...) do
            local value = select(i, ...)
            table.insert(parts, tostring(value))
        end

        DebugPrint(event .. ": " .. table.concat(parts, " | "))

        if event == "QUEST_ACCEPTED" and lastAcceptedQuestIndex and GetQuestLogTitle then
            local title = GetQuestLogTitle(lastAcceptedQuestIndex)
            DebugPrint("QUEST_ACCEPTED_TITLE: " .. tostring(title))
        end
    end)
end

local function Install()
    if installed then return end
    installed = true

    CompileMessages()
    HookChatEvents()
    HookUIErrorsFrame()
    HookCombatText()
    HookQuestLinks()
    HookQuestDebugEvents()
end

Install()
