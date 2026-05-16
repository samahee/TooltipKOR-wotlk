-- mail.lua
-- Translates mail subjects after Blizzard builds the mail UI (경매장 메일 제목, 아이템 한글화).

local function TranslateTextObject(textObject)
    if not textObject or not textObject.GetText or not textObject.SetText then return end
    if type(TooltipKOR_TranslateMessage) ~= "function" then return end

    local text = textObject:GetText()
    local translated = TooltipKOR_TranslateMessage(text)
    if translated and translated ~= text then
        textObject:SetText(translated)
    end
end

local function TranslateSubjectText(subject)
    if type(subject) ~= "string" or subject == "" then return subject end
    if type(TooltipKOR_TranslateMessage) ~= "function" then return subject end

    return TooltipKOR_TranslateMessage(subject) or subject
end

local function TranslateInboxSubjects()
    for i = 1, (INBOXITEMS_TO_DISPLAY or 7) do
        local subjectObject = _G["MailItem" .. i .. "Subject"]
        local inboxIndex = i + ((InboxFrame and InboxFrame.pageNum or 1) - 1) * (INBOXITEMS_TO_DISPLAY or 7)
        local subject = select(4, GetInboxHeaderInfo(inboxIndex))

        if subjectObject and subjectObject.SetText and subject then
            subjectObject:SetText(TranslateSubjectText(subject))
        else
            TranslateTextObject(subjectObject)
        end
    end
end

local function TranslateOpenMail()
    TranslateTextObject(OpenMailSubject)
end

local function HookMail()
    if _G.__TKOR_MailHooked then return end

    if type(hooksecurefunc) == "function" then
        if type(InboxFrame_Update) == "function" then
            hooksecurefunc("InboxFrame_Update", TranslateInboxSubjects)
        end
        if type(OpenMail_Update) == "function" then
            hooksecurefunc("OpenMail_Update", TranslateOpenMail)
        end
    end

    local frame = CreateFrame and CreateFrame("Frame")
    if frame then
        frame:Hide()
        frame:RegisterEvent("MAIL_SHOW")
        frame:RegisterEvent("MAIL_INBOX_UPDATE")
        frame:SetScript("OnEvent", function()
            TranslateInboxSubjects()
            TranslateOpenMail()
            frame:Show()
        end)
        frame:SetScript("OnUpdate", function(self)
            self:Hide()
            TranslateInboxSubjects()
            TranslateOpenMail()
        end)
    end

    _G.__TKOR_MailHooked = true
end

HookMail()
