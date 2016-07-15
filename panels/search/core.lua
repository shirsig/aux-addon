local private, public = {}, {}
Aux.search_frame = public

aux_favorite_searches = {}
aux_recent_searches = {}

local search_scan_id = 0

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

    filter_string = filter_string or private.search_box:GetText()
    private.search_box:SetText(filter_string)

    local queries = Aux.scan_util.parse_filter_string(filter_string)
    if not queries then
        return
    elseif getn(queries) > 1 then
        Aux.log('Invalid filter: The sniping mode does not support multiple queries')
    end
    if queries[1].blizzard_query.first_page or queries[1].blizzard_query.last_page then
        Aux.log('Invalid filter: The sniping mode does not support page range filters')
    end

    if filter_string ~= private.current_search().filter_string then
        private.new_search(filter_string, Aux.util.join(Aux.util.map(queries, function(filter) return filter.prettified end), ';'))
    else
        private.results_listing:SetSelectedRecord()
    end

    private.sniping_helper(private.current_search(), queries[1])
end

function private.sniping_helper(search, query)

    local ignore_page = not query.blizzard_query.first_page
    query.blizzard_query.first_page = query.blizzard_query.first_page or 0
    query.blizzard_query.last_page = query.blizzard_query.last_page or 0

    local sniping_map = {}
    for _, record in search.records do
        sniping_map[record.sniping_signature] = record
    end

    private.update_tab(private.RESULTS)

    local next_page
    search_scan_id = Aux.scan.start{
        type = 'list',
        queries = {query},
        on_scan_start = function()
            private.status_bar:update_status(99.99, 99.99)
            private.status_bar:set_text('Sniping ...')
        end,
        on_page_loaded = function(_, _, last_page)
            next_page = last_page
            if last_page == 0 then
                ignore_page = false
            end
        end,
        on_auction = function(auction_record)
            if not ignore_page then
                sniping_map[auction_record.sniping_signature] = auction_record
            end
        end,
        on_complete = function()
            if Aux.util.set_size(sniping_map) > 1000 then
                StaticPopup_Show('AUX_SEARCH_TABLE_FULL')
            else
                search.records = {}
                for _, record in sniping_map do
                    tinsert(search.records, record)
                end
                private.results_listing:SetDatabase(search.records)
            end

            query.blizzard_query.first_page = next_page
            query.blizzard_query.last_page = next_page
            private.sniping_helper(search, query)
        end,
        on_abort = function()
            private.status_bar:update_status(100, 100)
            private.status_bar:set_text('Done Sniping')
        end,
    }
end

function public.snipe(mode, filter_string)

    filter_string = filter_string or private.search_box:GetText()
    private.search_box:SetText(filter_string)

    if mode == 'search' and private.search_box:GetText() == private.current_search().filter_string then
        mode = 'refresh'
    end

    local queries, current_query, current_page, total_queries, start_page, start_query

    if mode == 'refresh' or mode == 'resume' then
        private.search_box:ClearFocus()
        private.search_box:SetText(private.current_search().filter_string)
    end
    if mode == 'refresh' then
        private.current_search().records = {}
        private.results_listing:SetDatabase(private.current_search().records)
    end

    queries = Aux.scan_util.parse_filter_string(filter_string)
    if not queries then
        return
    end
    total_queries = getn(queries)

    if mode == 'resume' then
        start_query, start_page = unpack(private.current_search().next)
        for i=1,start_query-1 do
            tremove(queries, 1)
        end
        queries[1].blizzard_query.first_page = (queries[1].blizzard_query.first_page or 0) + start_page - 1
        private.results_listing:SetSelectedRecord()
    else
        start_query, start_page = 1, 1
    end

    if mode == 'search' then
        private.new_search(filter_string, Aux.util.join(Aux.util.map(queries, function(filter) return filter.prettified end), ';'))
    end

    if mode == 'resume' or mode == 'refresh' then
        Aux.scan.abort(search_scan_id)
        private.current_search().next = nil
        private.disable_resume()
    end

    private.update_tab(private.RESULTS)

    local search = private.current_search()
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
        on_page_loaded = function(_, total_scan_pages)
            current_page = current_page + 1
            total_scan_pages = total_scan_pages + (start_page - 1)
            total_scan_pages = max(total_scan_pages, 1)
            current_page = min(current_page, total_scan_pages)
            private.status_bar:update_status(100 * (current_query - 1) / getn(queries), 100 * (current_page - 1) / total_scan_pages)
            private.status_bar:set_text(format('Scanning %d / %d (Page %d / %d)', current_query, total_queries, current_page, total_scan_pages))
        end,
        on_page_scanned = function()
            private.results_listing:SetDatabase()
        end,
        on_start_query = function(query)
            current_query = current_query and current_query + 1 or start_query
            current_page = current_page and 0 or start_page - 1
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

            if current_query then
                search.next = {current_query, current_page + 1}
            else
                search.next = {start_query, start_page}
            end

            if private.current_search() == search then
                private.enable_resume()
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
    local scan_id = 0
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

function private.enable_resume()
    private.resume_button:Show()
    private.search_box:SetPoint('RIGHT', private.resume_button, 'LEFT', -4, 0)
end

function private.disable_resume()
    private.resume_button:Hide()
    private.search_box:SetPoint('RIGHT', private.refresh_button, 'LEFT', -4, 0)
end

do
    local searches = { [1] = {
        filter_string = '',
        records = {},
    }}
    local search_index = 1

    function private.current_search()
        return searches[search_index]
    end

    function private.update_search()
        Aux.scan.abort(search_scan_id)
        private.search_box:ClearFocus()
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
        if searches[search_index].next then
            private.enable_resume()
        else
            private.disable_resume()
        end
    end

    function private.new_search(filter_string, prettified)
        tinsert(aux_recent_searches, 1, {
            filter_string = filter_string,
            prettified = prettified,
        })
        while getn(aux_recent_searches) > 50 do
            tremove(aux_recent_searches)
        end
        private.update_search_listings()

        tinsert(searches, search_index + 1, {
            filter_string = filter_string,
            records = {},
--            sniping = private.snipe_button:GetChecked() TODO
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

