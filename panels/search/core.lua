local private, public = {}, {}
Aux.search_frame = public

aux_favorite_searches = {}
aux_recent_searches = {}

local search_scan_id

private.popup_info = {
    rename = {}
}

do
    local function action()
        private.popup_info.rename.name = getglobal(this:GetParent():GetName()..'EditBox'):GetText()
        private.update_search_listings()
    end

    StaticPopupDialogs['AUX_SEARCH_SAVED_RENAME'] = {
        text = 'Enter a new name for this search.',
        button1 = 'Accept',
        button2 = 'Cancel',
        hasEditBox = 1,
        OnShow = function()
            local rename_info = private.popup_info.rename
            local edit_box = getglobal(this:GetName()..'EditBox')
            edit_box:SetText(rename_info.name or '')
            edit_box:SetFocus()
            edit_box:HighlightText()
        end,
        OnAccept = action,
        EditBoxOnEnterPressed = function()
            action()
            this:GetParent():Hide()
        end,
        EditBoxOnEscapePressed = function()
            this:GetParent():Hide()
        end,
        timeout = 0,
        hideOnEscape = 1,
    }
end
StaticPopupDialogs['AUX_SEARCH_TABLE_FULL'] = {
    text = 'Table full!\nFurther results from this search will be discarded.',
    button1 = 'Ok',
    showAlert = 1,
    timeout = 0,
    hideOnEscape = 1,
}

private.RESULTS, private.SAVED, private.FILTER = 1, 2, 3

private.elements = {
    [private.RESULTS] = {},
    [private.SAVED] = {},
    [private.FILTER] = {},
}

function private.update_search_listings()
    local favorite_search_rows = {}
    for i, favorite_search in ipairs(aux_favorite_searches) do
        local name = favorite_search.name and LIGHTYELLOW_FONT_COLOR_CODE..favorite_search.name..FONT_COLOR_CODE_CLOSE or strsub(favorite_search.prettified, 1, 250)
        tinsert(favorite_search_rows, {
            cols = {{value=name}},
            search = favorite_search,
            index = i,
            name = name,
        })
    end
    private.favorite_searches_listing:SetData(favorite_search_rows)

    local recent_search_rows = {}
    for i, recent_search in ipairs(aux_recent_searches) do
        local name = recent_search.name and LIGHTYELLOW_FONT_COLOR_CODE..recent_search.name..FONT_COLOR_CODE_CLOSE or strsub(recent_search.prettified, 1, 250)
        tinsert(recent_search_rows, {
            cols = {{value=name}},
            search = recent_search,
            index = i,
            name = name,
        })
    end
    private.recent_searches_listing:SetData(recent_search_rows)
end

function private.update_tab(tab)

    private.search_results_button:UnlockHighlight()
    private.saved_searches_button:UnlockHighlight()
    private.new_filter_button:UnlockHighlight()
    AuxSearchFrameResults:Hide()
    AuxSearchFrameSaved:Hide()
    AuxSearchFrameFilter:Hide()

    if tab == private.RESULTS then
        AuxSearchFrameResults:Show()
        private.search_results_button:LockHighlight()
    elseif tab == private.SAVED then
        AuxSearchFrameSaved:Show()
        private.saved_searches_button:LockHighlight()
    elseif tab == private.FILTER then
        AuxSearchFrameFilter:Show()
        private.new_filter_button:LockHighlight()
    end
end

function public.set_filter(filter_string)
    private.search_box:SetText(filter_string)
end

function private.add_filter(filter_string, replace)
    filter_string = filter_string or private.get_form_filter()


    local old_filter_string
    if not replace then
        old_filter_string = private.search_box:GetText()
        old_filter_string = Aux.util.trim(old_filter_string)

        if strlen(old_filter_string) > 0 then
            old_filter_string = old_filter_string..';'
        end
    end

    private.search_box:SetText((old_filter_string or '')..filter_string)
end

function private.clear_form()
    AuxSearchFrameFilterNameInputBox:SetText('')
    AuxSearchFrameFilterExactCheckButton:SetChecked(nil)
    AuxSearchFrameFilterMinLevel:SetText('')
    AuxSearchFrameFilterMaxLevel:SetText('')
    AuxSearchFrameFilterUsableCheckButton:SetChecked(nil)
    UIDropDownMenu_ClearAll(private.class_dropdown)
    UIDropDownMenu_ClearAll(private.subclass_dropdown)
    UIDropDownMenu_ClearAll(private.slot_dropdown)
    UIDropDownMenu_ClearAll(private.quality_dropdown)
    private.first_page_editbox:SetText('')
    private.last_page_editbox:SetText('')
end

function private.get_form_filter()
    local filter_term = ''

    local function add(part)
        filter_term = filter_term == '' and part or filter_term..'/'..part
    end

    add(AuxSearchFrameFilterNameInputBox:GetText())

    if AuxSearchFrameFilterExactCheckButton:GetChecked() then
        add('exact')
    end

    if tonumber(AuxSearchFrameFilterMinLevel:GetText()) then
        add(max(1, min(60, tonumber(AuxSearchFrameFilterMinLevel:GetText()))))
    end

    if tonumber(AuxSearchFrameFilterMaxLevel:GetText()) then
        add(max(1, min(60, tonumber(AuxSearchFrameFilterMaxLevel:GetText()))))
    end

    if AuxSearchFrameFilterUsableCheckButton:GetChecked() then
        add('usable')
    end

    local class = UIDropDownMenu_GetSelectedValue(private.class_dropdown) ~= 0 and UIDropDownMenu_GetSelectedValue(private.class_dropdown)
    if class then
        local classes = { GetAuctionItemClasses() }
        add(strlower(classes[class]))
        local subclass = UIDropDownMenu_GetSelectedValue(private.subclass_dropdown) ~= 0 and UIDropDownMenu_GetSelectedValue(private.subclass_dropdown)
        if subclass then
            local subclasses = {GetAuctionItemSubClasses(class)}
            add(strlower(subclasses[subclass]))
            local slot = UIDropDownMenu_GetSelectedValue(private.slot_dropdown) ~= 0 and UIDropDownMenu_GetSelectedValue(private.slot_dropdown)
            if slot then
                add(strlower(getglobal(slot)))
            end
        end
    end

    local quality = UIDropDownMenu_GetSelectedValue(private.quality_dropdown) ~= 0 and UIDropDownMenu_GetSelectedValue(private.quality_dropdown)
    if quality then
        add(strlower(getglobal('ITEM_QUALITY'..quality..'_DESC')))
    end

    local first_page, last_page = tonumber(private.first_page_editbox:GetText()), tonumber(private.last_page_editbox:GetText())
    first_page = first_page and max(1, first_page)
    last_page = last_page and max(1, last_page)
    if first_page or last_page then
        add((first_page or '') .. ':' .. (last_page or ''))
    end

    return filter_term
end

function public.on_open()
    private.update_search_listings()
end

function public.on_close()
    private.results_listing:SetSelectedRecord()
end

function public.on_load()
    public.create_frames(private, public)
    private.update_search()
    private.update_tab(private.SAVED)
end

function public.execute(mode, filter_string)
    if filter_string then
        private.search_box:SetText(filter_string)
    end

    local queries
    if mode == 'search' or mode == 'refresh' then
        if mode == 'refresh' then
            private.search_box:SetText(private.current_search().filter_string)
            private.results_listing:Reset()
        end

        local filters = Aux.scan_util.parse_filter_string(private.search_box:GetText())
        if not filters then
            return
        end

        queries = Aux.util.map(filters, function(filter)
            return {
                blizzard_query = filter.blizzard_query,
                validator = filter.validator,
            }
        end)

        if mode == 'search' then
            tinsert(aux_recent_searches, 1, {
                filter_string = private.search_box:GetText(),
                prettified = Aux.util.join(Aux.util.map(filters, function(filter) return filter.prettified end), ';'),
            })
            while getn(aux_recent_searches) > 50 do
                tremove(aux_recent_searches)
            end
            private.update_search_listings()
            private.new_search()
        end
    elseif mode == 'resume' then
        queries = private.current_search().continuation
        Aux.scan.abort(search_scan_id)
        private.current_search().continuation = nil
        private.resume_button:Disable()
        private.results_listing:SetSelectedRecord()
    end

    private.update_tab(private.RESULTS)

    local search = private.current_search()
    local current_query, current_page
    search_scan_id = Aux.scan.start{
        type = 'list',
        queries = queries,
        on_scan_start = function()
            private.status_bar:update_status(0,0)
            if mode == 'search' then
                private.status_bar:set_text('Scanning auctions...')
            elseif mode == 'refresh' then
                private.status_bar:set_text('Rescanning auctions...')
            elseif mode == 'resume' then
                private.status_bar:set_text('Resuming scan...')
            end
        end,
        on_page_loaded = function(page, total_pages)
            current_page = page
            private.status_bar:update_status(100 * (current_query - 1) / getn(queries), 100 * (page - 1) / total_pages)
            private.status_bar:set_text(format('Scanning %d / %d (Page %d / %d)', current_query, getn(queries), page, total_pages))
        end,
        on_page_scanned = function()
            private.results_listing:SetDatabase()
        end,
        on_start_query = function(query_index)
            current_query = query_index
        end,
        on_auction = function(auction_record)
            if getn(search.records) < 1000 then
                tinsert(search.records, auction_record)
                if getn(search.records) == 1000 then
                    StaticPopup_Show('AUX_SEARCH_TABLE_FULL')
                end
            end
        end,
        on_complete = function()
            private.status_bar:update_status(100, 100)
            private.status_bar:set_text('Done Scanning')

            if private.current_search() == search and AuxSearchFrameResults:IsVisible() and getn(search.records) == 0 then
                private.update_tab(private.SAVED)
            end
        end,
        on_abort = function()
            private.status_bar:update_status(100, 100)
            private.status_bar:set_text('Done Scanning')

            for i=1,(current_query or 1)-1 do
                tremove(queries, 1)
            end
            if queries[1].blizzard_query then
                queries[1].blizzard_query.first_page = (current_page and (queries[1].blizzard_query.first_page or 0) + current_page or queries[1].blizzard_query.first_page)
            end
            search.continuation = queries
            if private.current_search() == search then
                private.resume_button:Enable()
            end
        end,
    }
end

function private.test(record)
    return function(index)
        local auction_info = Aux.info.auction(index)
        return auction_info and auction_info.search_signature == record.search_signature
    end
end

function private.record_remover(record)
    return function()
        private.results_listing:RemoveAuctionRecord(record)
    end
end

function private.record_bid_updater(record)
    return
end

do
    local scan_id
    local IDLE, SEARCHING, FOUND = {}, {}, {}
    local state = IDLE
    local found_index

    function private.find_auction(record)
        if not private.results_listing:ContainsRecord(record) or Aux.is_player(record.owner) then
            return
        end

        Aux.scan.abort(scan_id)
        state = SEARCHING
        scan_id = Aux.scan_util.find(
            record,
            private.status_bar,
            function()
                state = IDLE
            end,
            function()
                state = IDLE
                private.record_remover(record)()
            end,
            function(index)
                state = FOUND
                found_index = index

                if not record.high_bidder then
                    private.bid_button:SetScript('OnClick', function()
                        if private.test(record)(index) and private.results_listing:ContainsRecord(record) then
                            Aux.place_bid('list', index, record.bid_price, record.bid_price < record.buyout_price and function()
                                Aux.info.bid_update(record)
                                private.results_listing:SetDatabase()
                            end or private.record_remover(record))
                        end
                    end)
                    private.bid_button:Enable()
                end

                if record.buyout_price > 0 then
                    private.buyout_button:SetScript('OnClick', function()
                        if private.test(record)(index) and private.results_listing:ContainsRecord(record) then
                            Aux.place_bid('list', index, record.buyout_price, private.record_remover(record))
                        end
                    end)
                    private.buyout_button:Enable()
                end
            end
        )
    end

    function public.on_update()
        if state == IDLE or state == SEARCHING then
            private.buyout_button:Disable()
            private.bid_button:Disable()
        end

        if state == SEARCHING then
            return
        end

        local selection = private.results_listing:GetSelection()
        if not selection then
            state = IDLE
        elseif selection and state == IDLE then
            private.find_auction(selection.record)
        elseif state == FOUND and not private.test(selection.record)(found_index) then
            private.buyout_button:Disable()
            private.bid_button:Disable()
            if not Aux.bid_in_progress() then
                state = IDLE
            end
        end
    end
end

do
    local searches = { [0] = {
        filter_string = '',
        records = {},
    }}
    local search_index = 0

    function private.current_search()
        return searches[search_index]
    end

    function private.update_search()
        Aux.scan.abort(search_scan_id)
        private.search_box:SetText(searches[search_index].filter_string)
        private.results_listing:Reset()
        private.results_listing:SetDatabase(searches[search_index].records)
        if search_index == 1 or search_index == 0 then
            private.previous_button:Disable()
        else
            private.previous_button:Enable()
        end
        if search_index == getn(searches) or search_index == 0 then
            private.next_button:Hide()
            private.search_box:SetPoint('LEFT', private.previous_button, 'RIGHT', 4, 0)
        else
            private.next_button:Show()
            private.search_box:SetPoint('LEFT', private.next_button, 'RIGHT', 4, 0)
        end
        if search_index > 0 then
            private.refresh_button:Enable()
        end
        if searches[search_index].continuation then
            private.resume_button:Enable()
        else
            private.resume_button:Disable()
        end
    end

    function private.new_search()
        tinsert(searches, search_index + 1, {
            filter_string = private.search_box:GetText(),
            records = {},
        })
        while getn(searches) > search_index + 1 do
            tremove(searches)
        end
        if getn(searches) > 5 then
            tremove(searches, 1)
        end
        search_index = getn(searches)
        private.update_search()
    end

    function private.previous_search()
        search_index = search_index - 1
        private.update_search()
        private.update_tab(private.RESULTS)
    end

    function private.next_search()
        search_index = search_index + 1
        private.update_search()
        private.update_tab(private.RESULTS)
    end
end

function private.initialize_class_dropdown()
    local function on_click()
        if this.value ~= UIDropDownMenu_GetSelectedValue(private.class_dropdown) then
            UIDropDownMenu_ClearAll(private.subclass_dropdown)
            UIDropDownMenu_ClearAll(private.slot_dropdown)
        end
        UIDropDownMenu_SetSelectedValue(private.class_dropdown, this.value)
    end

    UIDropDownMenu_AddButton{
        text = ALL,
        value = 0,
        func = on_click,
    }

    for i, class in pairs({ GetAuctionItemClasses() }) do
        UIDropDownMenu_AddButton{
            text = class,
            value = i,
            func = on_click,
        }
    end
end

function private.initialize_subclass_dropdown()

    local function on_click()
        if this.value ~= UIDropDownMenu_GetSelectedValue(private.subclass_dropdown) then
            UIDropDownMenu_ClearAll(private.slot_dropdown)
        end
        UIDropDownMenu_SetSelectedValue(private.subclass_dropdown, this.value)
    end

    local class_index = UIDropDownMenu_GetSelectedValue(private.class_dropdown)

    if class_index and GetAuctionItemSubClasses(class_index) then
        UIDropDownMenu_AddButton{
            text = ALL,
            value = 0,
            func = on_click,
        }

        for i, subclass in pairs({ GetAuctionItemSubClasses(class_index) }) do
            UIDropDownMenu_AddButton{
                text = subclass,
                value = i,
                func = on_click,
            }
        end
    end
end

function private.initialize_slot_dropdown()

    local function on_click()
        UIDropDownMenu_SetSelectedValue(private.slot_dropdown, this.value)
    end

    local class_index = UIDropDownMenu_GetSelectedValue(private.class_dropdown)
    local subclass_index = UIDropDownMenu_GetSelectedValue(private.subclass_dropdown)

    if class_index and subclass_index and GetAuctionInvTypes(class_index, subclass_index) then
        UIDropDownMenu_AddButton{
            text = ALL,
            value = 0,
            func = on_click,
        }

        for i, slot in pairs({ GetAuctionInvTypes(class_index, subclass_index) }) do
            local slot_name = getglobal(slot)
            UIDropDownMenu_AddButton{
                text = slot_name,
                value = slot,
                func = on_click,
            }
        end
    end
end

function private.initialize_quality_dropdown()

    local function on_click()
        UIDropDownMenu_SetSelectedValue(private.quality_dropdown, this.value)
    end

	UIDropDownMenu_AddButton{
		text = ALL,
        value = 0,
		func = on_click,
	}
	for i=0,4 do
		UIDropDownMenu_AddButton{
			text = getglobal('ITEM_QUALITY'..i..'_DESC'),
			value = i,
			func = on_click,
		}
	end
end

