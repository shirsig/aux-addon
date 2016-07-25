local m, public, private = Aux.tab(1, 'search_tab')

aux_favorite_searches = {}
aux_recent_searches = {}
aux_auto_buy_filter = ''

private.search_scan_id = 0
private.auto_buy_validator = nil

private.popup_info = {
    rename = {}
}

do
    local function action()
        m.popup_info.rename.name = getglobal(this:GetParent():GetName()..'EditBox'):GetText()
        m.update_search_listings()
    end

    StaticPopupDialogs['AUX_SEARCH_SAVED_RENAME'] = {
        text = 'Enter a new name for this search.',
        button1 = 'Accept',
        button2 = 'Cancel',
        hasEditBox = 1,
        OnShow = function()
            local rename_info = m.popup_info.rename
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
StaticPopupDialogs['AUX_SEARCH_AUTO_BUY'] = {
    text = 'Are you sure you want to activate automatic buyout?',
    button1 = 'Yes',
    button2 = 'No',
    OnAccept = function()
        m.auto_buy_checkbox:SetChecked(1)
    end,
    timeout = 0,
    hideOnEscape = 1,
}
StaticPopupDialogs['AUX_SEARCH_AUTO_BUY_FILTER'] = {
    text = 'Are you sure you want to set this filter for automatic buyout?',
    button1 = 'Yes',
    button2 = 'No',
    OnAccept = function()
        local queries = Aux.scan_util.parse_filter_string(m.auto_buy_filter_editbox:GetText())
        if queries then

            if getn(queries) > 1 then
                Aux.log('Error: The auto buy filter supports only one query')
                return
            end

            if Aux.util.size(queries[1].blizzard_query) > 0 then
                Aux.log('Error: The real time mode does not support blizzard filters')
                return
            end

            aux_auto_buy_filter = m.auto_buy_filter_editbox:GetText()
            m.auto_buy_validator = queries[1].validator
            m.auto_buy_filter_checkbox:SetChecked(1)
            m.auto_buy_filter_editbox:ClearFocus()
        end
    end,
    timeout = 0,
    hideOnEscape = 1,
}

private.RESULTS, private.SAVED, private.FILTER = 1, 2, 3

private.elements = {
    [m.RESULTS] = {},
    [m.SAVED] = {},
    [m.FILTER] = {},
}

function public.FRAMES(f)
    private.create_frames = f
end

function public.LOAD()
    m.create_frames(m, public, private)
    m.update_search()
    m.update_tab(m.SAVED)
end

function public.OPEN()
    m.frame:Show()
    m.update_search_listings()
end

function public.CLOSE()
    m.close_settings()
    m.results_listing:SetSelectedRecord()
    m.frame:Hide()
end

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
    m.favorite_searches_listing:SetData(favorite_search_rows)

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
    m.recent_searches_listing:SetData(recent_search_rows)
end

function private.update_tab(tab)

    m.search_results_button:UnlockHighlight()
    m.saved_searches_button:UnlockHighlight()
    m.new_filter_button:UnlockHighlight()
    m.frame.results:Hide()
    m.frame.saved:Hide()
    m.frame.filter:Hide()

    if tab == m.RESULTS then
        m.frame.results:Show()
        m.search_results_button:LockHighlight()
    elseif tab == m.SAVED then
        m.frame.saved:Show()
        m.saved_searches_button:LockHighlight()
    elseif tab == m.FILTER then
        m.frame.filter:Show()
        m.new_filter_button:LockHighlight()
    end
end

function public.set_filter(filter_string)
    m.search_box:SetText(filter_string)
end

function private.add_filter(filter_string, replace)
    filter_string = filter_string or m.get_form_filter()


    local old_filter_string
    if not replace then
        old_filter_string = m.search_box:GetText()
        old_filter_string = Aux.util.trim(old_filter_string)

        if strlen(old_filter_string) > 0 then
            old_filter_string = old_filter_string..';'
        end
    end

    m.search_box:SetText((old_filter_string or '')..filter_string)
end

function private.close_settings()
    if m.settings_button.open then
        m.settings_button:Click()
    end
end

function private.clear_form()
    m.name_input:SetText('')
    m.exact_checkbox:SetChecked(nil)
    m.min_level_input:SetText('')
    m.max_level_input:SetText('')
    m.usable_checkbox:SetChecked(nil)
    UIDropDownMenu_ClearAll(m.class_dropdown)
    UIDropDownMenu_ClearAll(m.subclass_dropdown)
    UIDropDownMenu_ClearAll(m.slot_dropdown)
    UIDropDownMenu_ClearAll(m.quality_dropdown)
end

function private.get_form_filter()
    local filter_term = ''

    local function add(part)
        filter_term = filter_term == '' and part or filter_term..'/'..part
    end

    add(m.name_input:GetText())

    if m.exact_checkbox:GetChecked() then
        add('exact')
    end

    if tonumber(m.min_level_input:GetText()) then
        add(max(1, min(60, tonumber(m.min_level_input:GetText()))))
    end

    if tonumber(m.max_level_input:GetText()) then
        add(max(1, min(60, tonumber(m.max_level_input:GetText()))))
    end

    if m.usable_checkbox:GetChecked() then
        add('usable')
    end

    local class = UIDropDownMenu_GetSelectedValue(m.class_dropdown) ~= 0 and UIDropDownMenu_GetSelectedValue(m.class_dropdown)
    if class then
        local classes = { GetAuctionItemClasses() }
        add(strlower(classes[class]))
        local subclass = UIDropDownMenu_GetSelectedValue(m.subclass_dropdown) ~= 0 and UIDropDownMenu_GetSelectedValue(m.subclass_dropdown)
        if subclass then
            local subclasses = {GetAuctionItemSubClasses(class)}
            add(strlower(subclasses[subclass]))
            local slot = UIDropDownMenu_GetSelectedValue(m.slot_dropdown) ~= 0 and UIDropDownMenu_GetSelectedValue(m.slot_dropdown)
            if slot then
                add(strlower(getglobal(slot)))
            end
        end
    end

    local quality = UIDropDownMenu_GetSelectedValue(m.quality_dropdown) ~= 0 and UIDropDownMenu_GetSelectedValue(m.quality_dropdown)
    if quality then
        add(strlower(getglobal('ITEM_QUALITY'..quality..'_DESC')))
    end

    return filter_term
end

function private.discard_continuation()
    Aux.scan.abort(m.search_scan_id)
    m.current_search().continuation = nil
    m.update_continuation()
end

function private:enable_stop()
    Aux.scan.abort(m.search_scan_id)
    m.stop_button:Show()
    m.start_button:Hide()
end

function private:enable_start()
    m.start_button:Show()
    m.stop_button:Hide()
end

function private.start_real_time_scan(query, search, continuation)

    local ignore_page
    if not search then
        search = m.current_search()
        query.blizzard_query.first_page = tonumber(continuation) or 0
        query.blizzard_query.last_page = tonumber(continuation) or 0
        ignore_page = not tonumber(continuation)
    end

    local next_page
    local new_records = {}
    m.search_scan_id = Aux.scan.start{
        type = 'list',
        queries = {query},
        auto_buy_validator = m.auto_buy_validator,
        on_scan_start = function()
            m.status_bar:update_status(99.99, 99.99)
            m.status_bar:set_text('Scanning last page ...')
        end,
        on_page_loaded = function(_, _, last_page)
            next_page = last_page
            if last_page == 0 then
                ignore_page = false
            end
        end,
        on_auction = function(auction_record, ctrl)
            if not ignore_page then
                if m.auto_buy_checkbox:GetChecked() then
                    ctrl.suspend()
                    Aux.place_bid('list', auction_record.index, auction_record.buyout_price, function() ctrl.resume(true) end)
                else
                    tinsert(new_records, auction_record)
                end
            end
        end,
        on_complete = function()
            local map = {}
            for _, record in search.records do
                map[record.sniping_signature] = record
            end
            for _, record in new_records do
                map[record.sniping_signature] = record
            end
            new_records = {}
            for _, record in map do
                tinsert(new_records, record)
            end

            if getn(new_records) > 1000 then
                StaticPopup_Show('AUX_SEARCH_TABLE_FULL')
            else
                search.records = new_records
                m.results_listing:SetDatabase(search.records)
            end

            query.blizzard_query.first_page = next_page
            query.blizzard_query.last_page = next_page
            m.start_real_time_scan(query, search)
        end,
        on_abort = function()
            m.status_bar:update_status(100, 100)
            m.status_bar:set_text('Scan paused')

            search.continuation = next_page or not ignore_page and query.blizzard_query.first_page or true

            if m.current_search() == search then
                m.update_continuation()
            end

            m:enable_start()
        end,
    }
end

function private.start_search(queries, continuation)
    local current_query, current_page, total_queries, start_query, start_page

    total_queries = getn(queries)

    if continuation then
        start_query, start_page = unpack(continuation)
        for i=1,start_query-1 do
            tremove(queries, 1)
        end
        queries[1].blizzard_query.first_page = (queries[1].blizzard_query.first_page or 0) + start_page - 1
        m.results_listing:SetSelectedRecord()
    else
        start_query, start_page = 1, 1
    end

    local search = m.current_search()
    m.search_scan_id = Aux.scan.start{
        type = 'list',
        queries = queries,
        auto_buy_validator = m.auto_buy_validator,
        on_scan_start = function()
            m.status_bar:update_status(0,0)
            if continuation then
                m.status_bar:set_text('Resuming scan...')
            else
                m.status_bar:set_text('Scanning auctions...')
            end
        end,
        on_page_loaded = function(_, total_scan_pages)
            current_page = current_page + 1
            total_scan_pages = total_scan_pages + (start_page - 1)
            total_scan_pages = max(total_scan_pages, 1)
            current_page = min(current_page, total_scan_pages)
            m.status_bar:update_status(100 * (current_query - 1) / getn(queries), 100 * (current_page - 1) / total_scan_pages)
            m.status_bar:set_text(format('Scanning %d / %d (Page %d / %d)', current_query, total_queries, current_page, total_scan_pages))
        end,
        on_page_scanned = function()
            m.results_listing:SetDatabase()
        end,
        on_start_query = function(query)
            current_query = current_query and current_query + 1 or start_query
            current_page = current_page and 0 or start_page - 1
        end,
        on_auction = function(auction_record, ctrl)
            if m.auto_buy_checkbox:GetChecked() then
                ctrl.suspend()
                Aux.place_bid('list', auction_record.index, auction_record.buyout_price, function() ctrl.resume(true) end)
            elseif getn(search.records) < 1000 then
                tinsert(search.records, auction_record)
                if getn(search.records) == 1000 then
                    StaticPopup_Show('AUX_SEARCH_TABLE_FULL')
                end
            end
        end,
        on_complete = function()
            m.status_bar:update_status(100, 100)
            m.status_bar:set_text('Scan complete')

            if m.current_search() == search and m.frame.results:IsVisible() and getn(search.records) == 0 then
                m.update_tab(m.SAVED)
            end

            m.enable_start()
        end,
        on_abort = function()
            m.status_bar:update_status(100, 100)
            m.status_bar:set_text('Scan paused')

            if current_query then
                search.continuation = {current_query, current_page + 1}
            else
                search.continuation = {start_query, start_page}
            end
            if m.current_search() == search then
                m.update_continuation()
            end

            m.enable_start()
        end,
    }
end

function public.execute(resume)
    if resume then
        m.search_box:SetText(m.current_search().filter_string)
    end
    local filter_string = m.search_box:GetText()

    local queries = Aux.scan_util.parse_filter_string(filter_string)
    if not queries then
        return
    elseif m.real_time_checkbox:GetChecked() then
        if getn(queries) > 1 then
            Aux.log('Invalid filter: The sniping mode does not support multiple queries')
            return
        elseif queries[1].blizzard_query.first_page or queries[1].blizzard_query.last_page then
            Aux.log('Invalid filter: The sniping mode does not support page range filters')
            return
        end
    end

    if filter_string ~= m.current_search().filter_string then
        m.new_search(filter_string, Aux.util.join(Aux.util.map(queries, function(filter) return filter.prettified end), ';'))
    else
        m.search_box:ClearFocus()
        if resume then
            m.results_listing:SetSelectedRecord()
        else
            if m.current_search().real_time ~= m.real_time_checkbox:GetChecked() then
                m.results_listing:Reset()
            end
            m.current_search().records = {}
            m.results_listing:SetDatabase(m.current_search().records)
        end
    end

    local continuation = resume and m.current_search().continuation
    m.discard_continuation()
    m:enable_stop()

    m.close_settings()
    m.update_tab(m.RESULTS)
    m.current_search().real_time = m.real_time_checkbox:GetChecked()
    if m.real_time_checkbox:GetChecked() then
        m.start_real_time_scan(queries[1], nil, continuation)
    else
        for _, query in queries do
            if tonumber(m.first_page_input:GetText()) then
                query.blizzard_query.first_page = Aux.round(max(0, m.first_page_input:GetNumber() - 1))
            end
            if tonumber(m.last_page_input:GetText()) then
                query.blizzard_query.last_page = Aux.round(max(0, m.last_page_input:GetNumber() - 1))
            end
        end
        m.start_search(queries, continuation)
    end
end

function private.test(record)
    return function(index)
        local auction_info = Aux.info.auction(index)
        return auction_info and auction_info.search_signature == record.search_signature
    end
end

function private.record_remover(record)
    return function()
        m.results_listing:RemoveAuctionRecord(record)
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
        if not m.results_listing:ContainsRecord(record) or Aux.is_player(record.owner) then
            return
        end

        Aux.scan.abort(scan_id)
        state = SEARCHING
        scan_id = Aux.scan_util.find(
            record,
            m.status_bar,
            function()
                state = IDLE
            end,
            function()
                state = IDLE
                m.record_remover(record)()
            end,
            function(index)
                state = FOUND
                found_index = index

                if not record.high_bidder then
                    m.bid_button:SetScript('OnClick', function()
                        if m.test(record)(index) and m.results_listing:ContainsRecord(record) then
                            Aux.place_bid('list', index, record.bid_price, record.bid_price < record.buyout_price and function()
                                Aux.info.bid_update(record)
                                m.results_listing:SetDatabase()
                            end or m.record_remover(record))
                        end
                    end)
                    m.bid_button:Enable()
                end

                if record.buyout_price > 0 then
                    m.buyout_button:SetScript('OnClick', function()
                        if m.test(record)(index) and m.results_listing:ContainsRecord(record) then
                            Aux.place_bid('list', index, record.buyout_price, m.record_remover(record))
                        end
                    end)
                    m.buyout_button:Enable()
                end
            end
        )
    end

    function private.on_update()
        if state == IDLE or state == SEARCHING then
            m.buyout_button:Disable()
            m.bid_button:Disable()
        end

        if state == SEARCHING then
            return
        end

        local selection = m.results_listing:GetSelection()
        if not selection then
            state = IDLE
        elseif selection and state == IDLE then
            m.find_auction(selection.record)
        elseif state == FOUND and not m.test(selection.record)(found_index) then
            m.buyout_button:Disable()
            m.bid_button:Disable()
            if not Aux.bid_in_progress() then
                state = IDLE
            end
        end
    end
end

function private.update_continuation()
    if m.current_search().continuation and m.current_search().real_time == m.real_time_checkbox:GetChecked() then
        m.resume_button:Show()
        m.search_box:SetPoint('RIGHT', m.resume_button, 'LEFT', -4, 0)
    else
        m.resume_button:Hide()
        m.search_box:SetPoint('RIGHT', m.start_button, 'LEFT', -4, 0)
    end
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
        Aux.scan.abort(m.search_scan_id)
        m.search_box:ClearFocus()
        m.search_box:SetText(searches[search_index].filter_string)
        m.results_listing:Reset()
        m.results_listing:SetDatabase(searches[search_index].records)
        if search_index == 1 or search_index == 0 then
            m.previous_button:Disable()
        else
            m.previous_button:Enable()
        end
        if search_index == getn(searches) or search_index == 0 then
            m.next_button:Hide()
            m.search_box:SetPoint('LEFT', m.previous_button, 'RIGHT', 4, 0)
        else
            m.next_button:Show()
            m.search_box:SetPoint('LEFT', m.next_button, 'RIGHT', 4, 0)
        end
        m.update_continuation()
    end

    function private.new_search(filter_string, prettified)
        tinsert(aux_recent_searches, 1, {
            filter_string = filter_string,
            prettified = prettified,
        })
        while getn(aux_recent_searches) > 50 do
            tremove(aux_recent_searches)
        end
        m.update_search_listings()

        tinsert(searches, search_index + 1, {
            filter_string = filter_string,
            records = {},
        })
        while getn(searches) > search_index + 1 do
            tremove(searches)
        end
        if getn(searches) > 5 then
            tremove(searches, 1)
        end
        search_index = getn(searches)
        m.update_search()
    end

    function private.previous_search()
        search_index = search_index - 1
        m.update_search()
        m.update_tab(m.RESULTS)
    end

    function private.next_search()
        search_index = search_index + 1
        m.update_search()
        m.update_tab(m.RESULTS)
    end
end

function private.initialize_class_dropdown()
    local function on_click()
        if this.value ~= UIDropDownMenu_GetSelectedValue(m.class_dropdown) then
            UIDropDownMenu_ClearAll(m.subclass_dropdown)
            UIDropDownMenu_ClearAll(m.slot_dropdown)
        end
        UIDropDownMenu_SetSelectedValue(m.class_dropdown, this.value)
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
        if this.value ~= UIDropDownMenu_GetSelectedValue(m.subclass_dropdown) then
            UIDropDownMenu_ClearAll(m.slot_dropdown)
        end
        UIDropDownMenu_SetSelectedValue(m.subclass_dropdown, this.value)
    end

    local class_index = UIDropDownMenu_GetSelectedValue(m.class_dropdown)

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
        UIDropDownMenu_SetSelectedValue(m.slot_dropdown, this.value)
    end

    local class_index = UIDropDownMenu_GetSelectedValue(m.class_dropdown)
    local subclass_index = UIDropDownMenu_GetSelectedValue(m.subclass_dropdown)

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
        UIDropDownMenu_SetSelectedValue(m.quality_dropdown, this.value)
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

