local m = {}
Aux.test = m

function m.prettify_search(search)
    local item_pattern = '([^/;]+)([^;]*)/exact'
    while true do
        local _, _, name, in_between = strfind(search, item_pattern)
        if name then
            search = gsub(search, item_pattern, m.display_name(Aux.static.auctionable_items[strupper(name)])..in_between, 1)
        else
            return Aux.gui.inline_color({216, 225, 211, 1})..search..'|r'
        end
    end
end

function m.display_name(item_id)
    local item_info = Aux.static.item_info(item_id)
    return '|c'..Aux.quality_color(item_info.quality)..'['..item_info.name..']'..'|r'
end

function m:complete()

    local filter_string = this:GetText()

    local completed_filter_string = ({strfind(filter_string, '([^;]*)/[^/;]*$')})[3]
    local current_filter = completed_filter_string and Aux.scan_util.filter_from_string(completed_filter_string)

    local options = {}

    if current_filter or not completed_filter_string then
        current_filter = current_filter or {}

        if current_filter.name
                and Aux.static.auctionable_items[strupper(current_filter.name)]
                and not current_filter.min_level
                and not current_filter.max_level
                and not current_filter.class
                and not current_filter.subclass
                and not current_filter.slot
                and not current_filter.quality
                and not current_filter.usable
                and not current_filter.exact
        then
            tinsert(options, 'exact')
        end

        -- classes
        if not current_filter.class and not current_filter.exact then
            for _, class in ipairs({ GetAuctionItemClasses() }) do
                tinsert(options, class)
            end
        end

        -- subclasses
        if current_filter.class and not current_filter.subclass then
            for _, class in ipairs({ GetAuctionItemSubClasses(current_filter.class) }) do
                tinsert(options, class)
            end
        end

        -- slots
        if current_filter.class and current_filter.subclass and not current_filter.slot then
            for _, invtype in ipairs({ GetAuctionInvTypes(current_filter.class, current_filter.subclass) }) do
                tinsert(options, getglobal(invtype))
            end
        end

        -- usable
        if not current_filter.usable and not current_filter.exact then
            tinsert(options, 'usable')
        end

        -- rarities
        if not current_filter.quality and not current_filter.exact then
            for i=0,4 do
                tinsert(options, getglobal('ITEM_QUALITY'..i..'_DESC'))
            end
        end

        -- discard
        if not current_filter.discard then
            tinsert(options, 'discard')
        end

        -- item names
        if not completed_filter_string then
            local item_filters = {}
            for key, value in Aux.static.auctionable_items do
                if type(key) == 'number' then
                    tinsert(item_filters, value.name..'/exact')
                end
            end
            sort(item_filters)
            for _, item_name in ipairs(item_filters) do
                tinsert(options, item_name)
            end
        end

        local start_index, _, current_modifier = strfind(filter_string, '([^/;]*)$')
        current_modifier = current_modifier or ''

        for _, option in ipairs(options) do
            if string.sub(strupper(option), 1, strlen(current_modifier)) == strupper(current_modifier) then
                this:SetText(string.sub(filter_string, 1, start_index - 1)..option)
                this:HighlightText(strlen(filter_string), -1)
                return
            end
        end
    end
end

function m:complete_item()

    local text = this:GetText()

    local item_names = {}
    for key, value in Aux.static.auctionable_items do
        if type(key) == 'number' then
            tinsert(item_names, value.name)
        end
    end
    sort(item_names)

    for _, item_name in ipairs(item_names) do
        if string.sub(strupper(item_name), 1, strlen(text)) == strupper(text) then
            this:SetText(item_name)
            this:HighlightText(strlen(text), -1)
            return
        end
    end
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