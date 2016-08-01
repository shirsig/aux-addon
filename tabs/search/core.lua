local m, public, private = Aux.tab(1, 'search_tab')

aux_favorite_searches = {}
aux_recent_searches = {}
aux_auto_buy_filter = ''

private.search_scan_id = 0
private.auto_buy_validator = nil

StaticPopupDialogs['AUX_SEARCH_TABLE_FULL'] = {
    text = 'Table full!\nFurther results from this search will still be processed but no longer displayed in the table.',
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
        m.auto_buy_button:SetChecked(true)
    end,
    timeout = 0,
    hideOnEscape = 1,
}
do
    local function action()
        aux_auto_buy_filter = getglobal(this:GetParent():GetName()..'EditBox'):GetText()
        m.update_auto_buy_filter()
    end

    StaticPopupDialogs['AUX_SEARCH_AUTO_BUY_FILTER'] = {
        text = 'Enter a filter for automatic buyout.',
        button1 = 'Accept',
        button2 = 'Cancel',
        hasEditBox = 1,
        OnShow = function()
            local edit_box = getglobal(this:GetName()..'EditBox')
            edit_box:SetMaxLetters(nil)
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
    m.new_search('')
    m.update_tab(m.SAVED)
    m.update_auto_buy_filter()
end

function public.OPEN()
    m.frame:Show()
    m.update_search_listings()
end

function public.CLOSE()
    m.close_settings()
    m.current_search().table:SetSelectedRecord()
    m.frame:Hide()
end

function private.update_search_listings()
    local favorite_search_rows = {}
    for i, favorite_search in ipairs(aux_favorite_searches) do
        local name = strsub(favorite_search.prettified, 1, 250)
        tinsert(favorite_search_rows, {
            cols = {{value=name}},
            search = favorite_search,
            index = i,
        })
    end
    m.favorite_searches_listing:SetData(favorite_search_rows)

    local recent_search_rows = {}
    for i, recent_search in ipairs(aux_recent_searches) do
        local name = strsub(recent_search.prettified, 1, 250)
        tinsert(recent_search_rows, {
            cols = {{value=name}},
            search = recent_search,
            index = i,
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

function private.update_auto_buy_filter()
    if aux_auto_buy_filter ~= '' then
        local queries = Aux.scan_util.parse_filter_string(aux_auto_buy_filter)
        if queries then
            if getn(queries) > 1 then
                Aux.log('Error: The automatic buyout filter may contain only one query')
            elseif Aux.util.size(queries[1].blizzard_query) > 0 then
                Aux.log('Error: The automatic buyout filter does not support Blizzard filters')
            else
                m.auto_buy_validator = queries[1].validator
                m.auto_buy_filter_button.prettified = queries[1].prettified
                m.auto_buy_filter_button:SetChecked(true)
                return
            end
        end
    end
    aux_auto_buy_filter = ''
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

    local min_level = m.blizzard_level(m.min_level_input:GetText())
    if min_level then
        add(min_level)
    end

    local max_level = m.blizzard_level(m.min_level_input:GetText())
    if max_level then
        add(max_level)
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

function private:update_start_stop()
    if m.current_search().active then
        m.stop_button:Show()
        m.start_button:Hide()
    else
        m.start_button:Show()
        m.stop_button:Hide()
    end
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
        auto_buy_validator = search.auto_buy_validator,
        on_scan_start = function()
            search.status_bar:update_status(99.99, 99.99)
            search.status_bar:set_text('Scanning last page ...')
        end,
        on_page_loaded = function(_, _, last_page)
            next_page = last_page
            if last_page == 0 then
                ignore_page = false
            end
        end,
        on_auction = function(auction_record, ctrl)
            if not ignore_page then
                if search.auto_buy then
                    ctrl.suspend()
                    Aux.place_bid('list', auction_record.index, auction_record.buyout_price, Aux.f(ctrl.resume, true))
                    Aux.control.new_thread(Aux.control.sleep, 10, Aux.f(ctrl.resume, false))
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
                search.table:SetDatabase(search.records)
            end

            query.blizzard_query.first_page = next_page
            query.blizzard_query.last_page = next_page
            m.start_real_time_scan(query, search)
        end,
        on_abort = function()
            search.status_bar:update_status(100, 100)
            search.status_bar:set_text('Scan paused')

            search.continuation = next_page or not ignore_page and query.blizzard_query.first_page or true

            if m.current_search() == search then
                m.update_continuation()
            end

            search.active = false
            m.update_start_stop()
        end,
    }
end

function private.start_search(queries, continuation)
    local current_query, current_page, total_queries, start_query, start_page

    local search = m.current_search()

    total_queries = getn(queries)

    if continuation then
        start_query, start_page = unpack(continuation)
        for i=1,start_query-1 do
            tremove(queries, 1)
        end
        queries[1].blizzard_query.first_page = (queries[1].blizzard_query.first_page or 0) + start_page - 1
        search.table:SetSelectedRecord()
    else
        start_query, start_page = 1, 1
    end


    m.search_scan_id = Aux.scan.start{
        type = 'list',
        queries = queries,
        auto_buy_validator = search.auto_buy_validator,
        on_scan_start = function()
            search.status_bar:update_status(0,0)
            if continuation then
                search.status_bar:set_text('Resuming scan...')
            else
                search.status_bar:set_text('Scanning auctions...')
            end
        end,
        on_page_loaded = function(_, total_scan_pages)
            current_page = current_page + 1
            total_scan_pages = total_scan_pages + (start_page - 1)
            total_scan_pages = max(total_scan_pages, 1)
            current_page = min(current_page, total_scan_pages)
            search.status_bar:update_status(100 * (current_query - 1) / getn(queries), 100 * (current_page - 1) / total_scan_pages)
            search.status_bar:set_text(format('Scanning %d / %d (Page %d / %d)', current_query, total_queries, current_page, total_scan_pages))
        end,
        on_page_scanned = function()
            search.table:SetDatabase()
        end,
        on_start_query = function(query)
            current_query = current_query and current_query + 1 or start_query
            current_page = current_page and 0 or start_page - 1
        end,
        on_auction = function(auction_record, ctrl)
            if search.auto_buy then
                ctrl.suspend()
                Aux.place_bid('list', auction_record.index, auction_record.buyout_price, Aux.f(ctrl.resume, true))
                Aux.control.new_thread(Aux.control.sleep, 10, Aux.f(ctrl.resume, false))
            elseif getn(search.records) < 1000 then
                tinsert(search.records, auction_record)
                if getn(search.records) == 1000 then
                    StaticPopup_Show('AUX_SEARCH_TABLE_FULL')
                end
            end
        end,
        on_complete = function()
            search.status_bar:update_status(100, 100)
            search.status_bar:set_text('Scan complete')

            if m.current_search() == search and m.frame.results:IsVisible() and getn(search.records) == 0 then
                m.update_tab(m.SAVED)
            end

            search.active = false
            m.update_start_stop()
        end,
        on_abort = function()
            search.status_bar:update_status(100, 100)
            search.status_bar:set_text('Scan paused')

            if current_query then
                search.continuation = {current_query, current_page + 1}
            else
                search.continuation = {start_query, start_page}
            end
            if m.current_search() == search then
                m.update_continuation()
            end

            search.active = false
            m.update_start_stop()
        end,
    }
end

function public.execute(resume, real_time)

    if resume then
        real_time = m.current_search().real_time
    elseif real_time == nil then
        real_time = m.real_time_button:GetChecked()
    end

    if resume then
        m.search_box:SetText(m.current_search().filter_string)
    end
    local filter_string = m.search_box:GetText()

    local queries = Aux.scan_util.parse_filter_string(filter_string)
    if not queries then
        return
    elseif real_time then
        if getn(queries) > 1 then
            Aux.log('Invalid filter: The real time mode does not support multiple queries')
            return
        elseif queries[1].blizzard_query.first_page or queries[1].blizzard_query.last_page then
            Aux.log('Invalid filter: The real time mode does not support page range filters')
            return
        end
    end

    m.search_box:ClearFocus()

    if resume then
        m.current_search().table:SetSelectedRecord()
    else
        if filter_string ~= m.current_search().filter_string then
            m.new_search(filter_string, Aux.util.join(Aux.util.map(queries, function(filter) return filter.prettified end), ';'))
        else
            m.current_search().records = {}
            m.current_search().table:SetDatabase(m.current_search().records)
            if m.current_search().real_time ~= real_time then
                m.current_search().table:Reset()
            end
        end
        m.current_search().real_time = m.real_time_button:GetChecked()
        m.current_search().auto_buy = m.auto_buy_button:GetChecked()
        m.current_search().auto_buy_validator = m.auto_buy_validator
    end

    local continuation = resume and m.current_search().continuation
    m.discard_continuation()
    m.current_search().active = true
    m.update_start_stop()

    m.update_tab(m.RESULTS)
    if real_time then
        m.start_real_time_scan(queries[1], nil, continuation)
    else
        for _, query in queries do
            query.blizzard_query.first_page = m.blizzard_page_index(m.first_page_input:GetText())
            query.blizzard_query.last_page = m.blizzard_page_index(m.last_page_input:GetText())
        end
        m.start_search(queries, continuation)
    end
end

function private.blizzard_page_index(str)
    if tonumber(str) then
        return Aux.round(max(0, tonumber(str) - 1))
    end
end

function private.blizzard_level(str)
    if tonumber(str) then
        return Aux.round(max(1, min(60, tonumber(str))))
    end
end

function private.test(record)
    return function(index)
        local auction_info = Aux.info.auction(index)
        return auction_info and auction_info.search_signature == record.search_signature
    end
end

do
    local scan_id = 0
    local IDLE, SEARCHING, FOUND = {}, {}, {}
    local state = IDLE
    local found_index

    function private.find_auction(record)
        local search = m.current_search()

        if not search.table:ContainsRecord(record) or Aux.is_player(record.owner) then
            return
        end

        Aux.scan.abort(scan_id)
        state = SEARCHING
        scan_id = Aux.scan_util.find(
            record,
            m.current_search().status_bar,
            function()
                state = IDLE
            end,
            function()
                state = IDLE
                search.table:RemoveAuctionRecord(record)
            end,
            function(index)
                if Aux.safe(search.table:GetSelection()).record/nil ~= record then
                    return
                end

                state = FOUND
                found_index = index

                if not record.high_bidder then
                    m.bid_button:SetScript('OnClick', function()
                        if m.test(record)(index) and search.table:ContainsRecord(record) then
                            Aux.place_bid('list', index, record.bid_price, record.bid_price < record.buyout_price and function()
                                Aux.info.bid_update(record)
                                search.table:SetDatabase()
                            end or Aux.f(search.table.RemoveAuctionRecord, search.table, record))
                        end
                    end)
                    m.bid_button:Enable()
                end

                if record.buyout_price > 0 then
                    m.buyout_button:SetScript('OnClick', function()
                        if m.test(record)(index) and search.table:ContainsRecord(record) then
                            Aux.place_bid('list', index, record.buyout_price, Aux.f(search.table.RemoveAuctionRecord, search.table, record))
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

        local selection = m.current_search().table:GetSelection()
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
    if m.current_search().continuation then
        m.resume_button:Show()
        m.search_box:SetPoint('RIGHT', m.resume_button, 'LEFT', -4, 0)
    else
        m.resume_button:Hide()
        m.search_box:SetPoint('RIGHT', m.start_button, 'LEFT', -4, 0)
    end
end

do
    local searches = {}
    local search_index = 1

    function private.current_search()
        return searches[search_index]
    end

    function private.update_search(index)
        searches[search_index].status_bar:Hide()
        searches[search_index].table:Hide()
        searches[search_index].table:SetSelectedRecord()

        search_index = index

        searches[search_index].status_bar:Show()
        searches[search_index].table:Show()

        m.search_box:SetText(searches[search_index].filter_string)
        if search_index == 1 then
            m.previous_button:Disable()
        else
            m.previous_button:Enable()
        end
        if search_index == getn(searches) then
            m.next_button:Hide()
            m.search_box:SetPoint('LEFT', m.previous_button, 'RIGHT', 4, 0)
        else
            m.next_button:Show()
            m.search_box:SetPoint('LEFT', m.next_button, 'RIGHT', 4, 0)
        end
        m.update_start_stop()
        m.update_continuation()
    end

    function private.new_search(filter_string, prettified)
        if prettified then
            tinsert(aux_recent_searches, 1, {
                filter_string = filter_string,
                prettified = prettified,
            })
            while getn(aux_recent_searches) > 50 do
                tremove(aux_recent_searches)
            end
            m.update_search_listings()
        end

        while getn(searches) > search_index do
            tremove(searches)
        end
        local search = {
            filter_string = filter_string,
            records = {},
        }
        tinsert(searches, search)
        if getn(searches) > 5 then
            tremove(searches, 1)
            tinsert(m.status_bars, tremove(m.status_bars, 1))
            tinsert(m.tables, tremove(m.tables, 1))
            search_index = 4
        end

        search.status_bar = m.status_bars[getn(searches)]
        search.status_bar:update_status(100, 100)
        search.status_bar:set_text('')

        search.table = m.tables[getn(searches)]
        search.table:SetSort(1,2,3,4,5,6,7,8,9)
        search.table:Reset()
        search.table:SetDatabase(search.records)

        m.update_search(getn(searches))
    end

    function private.previous_search()
        m.search_box:ClearFocus()
        m.update_search(search_index - 1)
        m.update_tab(m.RESULTS)
    end

    function private.next_search()
        m.search_box:ClearFocus()
        m.update_search(search_index + 1)
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

