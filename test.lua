local m = {}
Aux.test = m

function m.key_count(table)
    local count = 0
    for _, _ in pairs(table) do
        count = count + 1
    end
    return count
end

--StaticPopupDialogs["CANCEL_AUCTION"] = {
--    text = TEXT(CANCEL_AUCTION_CONFIRMATION),
--    button1 = TEXT(ACCEPT),
--    button2 = TEXT(CANCEL),
--    OnAccept = function()
--        CancelAuction(GetSelectedAuctionItem("owner"));
--    end,
--    OnShow = function()
--        MoneyFrame_Update(this:GetName().."MoneyFrame", AuctionFrameAuctions.cancelPrice);
--        if ( AuctionFrameAuctions.cancelPrice > 0 ) then
--            getglobal(this:GetName().."Text"):SetText(CANCEL_AUCTION_CONFIRMATION_MONEY);
--        else
--            getglobal(this:GetName().."Text"):SetText(CANCEL_AUCTION_CONFIRMATION);
--        end
--
--    end,
--    hasMoneyFrame = 1,
--    showAlert = 1,
--    timeout = 0,
--};

--StaticPopupDialogs["TSM_SHOPPING_SAVED_EXPORT_POPUP"] = {
--    text = L["Press Ctrl-C to copy this saved search."],
--    button1 = OKAY,
--    OnShow = function(self)
--        self.editBox:SetText(private.popupInfo.export)
--        self.editBox:HighlightText()
--        self.editBox:SetFocus()
--        self.editBox:SetScript("OnEscapePressed", function() StaticPopup_Hide("TSM_SHOPPING_SAVED_EXPORT_POPUP") end)
--        self.editBox:SetScript("OnEnterPressed", function() self.button1:Click() end)
--    end,
--    hasEditBox = true,
--    timeout = 0,
--    hideOnEscape = true,
--    preferredIndex = 3,
--}
--StaticPopupDialogs["TSM_SHOPPING_SAVED_IMPORT_POPUP"] = {
--    text = L["Paste the search you'd like to import into the box below."],
--    button1 = L["Import"],
--    button2 = CANCEL,
--    OnShow = function(self)
--        self.editBox:SetText("")
--        self.editBox:HighlightText()
--        self.editBox:SetFocus()
--        self.editBox:SetScript("OnEscapePressed", function() StaticPopup_Hide("TSM_SHOPPING_SAVED_IMPORT_POPUP") end)
--        self.editBox:SetScript("OnEnterPressed", function() self.button1:Click() end)
--    end,
--    OnAccept = function(self)
--        local text = self.editBox:GetText():trim()
--        if text ~= "" then
--            local found = false
--            -- check if this search already exists
--            for i, data in ipairs(TSM.db.global.savedSearches) do
--                if data.searchMode == "normal" and strlower(data.filter) == strlower(text) then
--                    -- update the lastSearch time and return
--                    data.isFavorite = true
--                    found = true
--                    break
--                end
--            end
--            if not found then
--                tinsert(TSM.db.global.savedSearches, {searchMode="normal", filter=text, name=text, lastSearch=time(), isFavorite=true})
--            end
--            TSM:Printf(L["Added '%s' to your favorite searches."], text)
--            private.UpdateSTData()
--        end
--    end,
--    hasEditBox = true,
--    timeout = 0,
--    hideOnEscape = true,
--    preferredIndex = 3,
--}