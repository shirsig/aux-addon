local m, public, private = aux.tab(1, 'Search', 'search_tab')

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

	function private.new_search(filter_string)
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

function m.LOAD()
	m.create_frames()
	m.update_tab(m.SAVED)
	m.update_auto_buy_filter()
	m.new_search('')
	m.current_search().placeholder = true
end

function m.OPEN()
    m.frame:Show()
    m.update_search_listings()
end

function m.CLOSE()
    m.close_settings()
    m.current_search().table:SetSelectedRecord()
    m.frame:Hide()
end

function m.CLICK_LINK(item_info)
	m.set_filter(strlower(item_info.name)..'/exact')
	m.execute(nil, false)
end

function m.USE_ITEM(item_info)
	m.set_filter(strlower(item_info.name)..'/exact')
	m.execute(nil, false)
end

function private.update_search_listings()
    local favorite_search_rows = {}
    for i, favorite_search in aux_favorite_searches do
        local name = strsub(favorite_search.prettified, 1, 250)
        tinsert(favorite_search_rows, {
            cols = {{value=name}},
            search = favorite_search,
            index = i,
        })
    end
    m.favorite_searches_listing:SetData(favorite_search_rows)

    local recent_search_rows = {}
    for i, recent_search in aux_recent_searches do
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

function public.add_filter(filter_string)
    local old_filter_string = m.search_box:GetText()
    old_filter_string = aux.util.trim(old_filter_string)

    if old_filter_string ~= '' then
        old_filter_string = old_filter_string..';'
    end

    m.search_box:SetText(old_filter_string..filter_string)
end

function private.update_auto_buy_filter()
    if aux_auto_buy_filter ~= '' then
        local queries = aux.filter.queries(aux_auto_buy_filter)
        if queries then
            if getn(queries) > 1 then
                aux.log('Error: The automatic buyout filter may contain only one query')
            elseif aux.util.size(queries[1].blizzard_query) > 0 then
                aux.log('Error: The automatic buyout filter does not support Blizzard filters')
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
    m.name_input:ClearFocus()
    m.exact_checkbox:SetChecked(nil)
    m.min_level_input:SetText('')
    m.min_level_input:ClearFocus()
    m.max_level_input:SetText('')
    m.max_level_input:ClearFocus()
    m.usable_checkbox:SetChecked(nil)
    UIDropDownMenu_ClearAll(m.class_dropdown)
    UIDropDownMenu_ClearAll(m.subclass_dropdown)
    UIDropDownMenu_ClearAll(m.slot_dropdown)
    UIDropDownMenu_ClearAll(m.quality_dropdown)
    m.filter_input:ClearFocus()
    m.post_components = {}
    m.update_filter_display()
end

function private.discard_continuation()
    aux.scan.abort(m.search_scan_id)
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
    m.search_scan_id = aux.scan.start{
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
                    aux.place_bid('list', auction_record.index, auction_record.buyout_price, aux._(ctrl.resume, true))
                    aux.control.thread(aux.control.when, aux.util.later(GetTime(), 10), aux._(ctrl.resume, false))
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


    m.search_scan_id = aux.scan.start{
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
                aux.place_bid('list', auction_record.index, auction_record.buyout_price, aux._(ctrl.resume, true))
                aux.control.thread(aux.control.when, aux.util.later(GetTime(), 10), aux._(ctrl.resume, false))
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

    local queries = aux.filter.queries(filter_string)
    if not queries then
        return
    elseif real_time then
        if getn(queries) > 1 then
            aux.log('Invalid filter: The real time mode does not support multiple queries')
            return
        elseif queries[1].blizzard_query.first_page or queries[1].blizzard_query.last_page then
            aux.log('Invalid filter: The real time mode does not support page range filters')
            return
        end
    end

    m.search_box:ClearFocus()

    if resume then
        m.current_search().table:SetSelectedRecord()
    else
        if filter_string ~= m.current_search().filter_string or m.current_search().placeholder then
	        if m.current_search().placeholder then
		        m.current_search().filter_string = filter_string
		        m.current_search().placeholder = false
	        else
		        m.new_search(filter_string)
	        end
			m.new_recent_search(filter_string, aux.util.join(aux.util.map(queries, function(filter) return filter.prettified end), ';'))
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
        return aux.util.round(max(0, tonumber(str) - 1))
    end
end

function private.blizzard_level(str)
    if tonumber(str) then
        return aux.util.round(aux.util.bound(1, 60, tonumber(str)))
    end
end

function private.test(record)
    return function(index)
        local auction_info = aux.info.auction(index)
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

        if not search.table:ContainsRecord(record) or aux.is_player(record.owner) then
            return
        end

        aux.scan.abort(scan_id)
        state = SEARCHING
        scan_id = aux.scan_util.find(
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
                if search.table:GetSelection() and search.table:GetSelection().record ~= record then
                    return
                end

                state = FOUND
                found_index = index

                if not record.high_bidder then
                    m.bid_button:SetScript('OnClick', function()
                        if m.test(record)(index) and search.table:ContainsRecord(record) then
                            aux.place_bid('list', index, record.bid_price, record.bid_price < record.buyout_price and function()
                                aux.info.bid_update(record)
                                search.table:SetDatabase()
                            end or aux._(search.table.RemoveAuctionRecord, search.table, record))
                        end
                    end)
                    m.bid_button:Enable()
                end

                if record.buyout_price > 0 then
                    m.buyout_button:SetScript('OnClick', function()
                        if m.test(record)(index) and search.table:ContainsRecord(record) then
                            aux.place_bid('list', index, record.buyout_price, aux._(search.table.RemoveAuctionRecord, search.table, record))
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
            if not aux.bid_in_progress() then
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

function private.initialize_class_dropdown()
    local function on_click()
	    local old_value = UIDropDownMenu_GetSelectedValue(m.class_dropdown)
	    UIDropDownMenu_SetSelectedValue(m.class_dropdown, this.value)
	    if this.value ~= old_value then
            UIDropDownMenu_ClearAll(m.subclass_dropdown)
            UIDropDownMenu_Initialize(m.subclass_dropdown, m.initialize_subclass_dropdown)
            UIDropDownMenu_ClearAll(m.slot_dropdown)
            UIDropDownMenu_Initialize(m.slot_dropdown, m.initialize_slot_dropdown)
        end
    end

    UIDropDownMenu_AddButton{
        text = ALL,
        value = 0,
        func = on_click,
    }

    for i, class in { GetAuctionItemClasses() } do
        UIDropDownMenu_AddButton{
            text = class,
            value = i,
            func = on_click,
        }
    end
end

function private.initialize_subclass_dropdown()

    local function on_click()
	    local old_value = UIDropDownMenu_GetSelectedValue(m.subclass_dropdown)
	    UIDropDownMenu_SetSelectedValue(m.subclass_dropdown, this.value)
	    if this.value ~= old_value then
            UIDropDownMenu_ClearAll(m.slot_dropdown)
            UIDropDownMenu_Initialize(m.slot_dropdown, m.initialize_slot_dropdown)
        end
    end

    local class_index = UIDropDownMenu_GetSelectedValue(m.class_dropdown)

    if class_index and GetAuctionItemSubClasses(class_index) then
	    m.subclass_dropdown.button:Enable()

        UIDropDownMenu_AddButton{
            text = ALL,
            value = 0,
            func = on_click,
        }

        for i, subclass in { GetAuctionItemSubClasses(class_index) } do
            UIDropDownMenu_AddButton{
                text = subclass,
                value = i,
                func = on_click,
            }
        end
    else
	    m.subclass_dropdown.button:Disable()
    end
end

function private.initialize_slot_dropdown()

    local function on_click()
        UIDropDownMenu_SetSelectedValue(m.slot_dropdown, this.value)
    end

    local class_index = UIDropDownMenu_GetSelectedValue(m.class_dropdown)
    local subclass_index = UIDropDownMenu_GetSelectedValue(m.subclass_dropdown)

    if class_index and subclass_index and GetAuctionInvTypes(class_index, subclass_index) then
	    m.slot_dropdown.button:Enable()

        UIDropDownMenu_AddButton{
            text = ALL,
            value = 0,
            func = on_click,
        }

        for _, slot in { GetAuctionInvTypes(class_index, subclass_index) } do
            local slot_name = getglobal(slot)
            UIDropDownMenu_AddButton{
                text = slot_name,
                value = slot,
                func = on_click,
            }
        end
    else
	    m.slot_dropdown.button:Disable()
    end
end

function private.initialize_quality_dropdown()

    local function on_click()
        UIDropDownMenu_SetSelectedValue(m.quality_dropdown, this.value)
    end

	UIDropDownMenu_AddButton{
		text = ALL,
        value = -1,
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

function private.initialize_filter_dropdown()
    local function on_click()
        UIDropDownMenu_SetSelectedValue(m.filter_dropdown, this.value)
        m.filter_button:SetText(this.value)
        if (not aux.filter.filters[this.value] or aux.filter.filters[this.value].input_type == '') and this.value ~= 'and' and this.value ~= 'or' then
            m.filter_input:Hide()
        else
            local _, _, suggestions = aux.filter.parse_query_string(UIDropDownMenu_GetSelectedValue(m.filter_dropdown)..'/')
            m.filter_input:SetNumeric(not aux.filter.filters[this.value] or aux.filter.filters[this.value].input_type == 'number')
            m.filter_input.complete = aux.completion.complete(function() return suggestions or {} end)
            m.filter_input:Show()
            m.filter_input:SetFocus()
        end
    end

    for _, filter in {'and', 'or', 'not', 'min-unit-buy', 'max-unit-bid', 'max-unit-bid', 'max-unit-buy', 'bid-profit', 'buy-profit', 'bid-vend-profit', 'buy-vend-profit', 'bid-dis-profit', 'buy-dis-profit', 'bid-pct', 'buy-pct', 'item', 'tooltip', 'min-lvl', 'max-lvl', 'rarity', 'left', 'utilizable', 'discard'} do
        UIDropDownMenu_AddButton{
            text = filter,
            value = filter,
            func = on_click,
        }
    end
end

function private.get_form()
    local query_string = ''

    local function add(part)
        query_string = query_string == '' and part or query_string..'/'..part
    end

    local name = m.name_input:GetText()
    name = name == '' and name or aux.filter.quote(name)
    add(name)

    if m.exact_checkbox:GetChecked() then
        add('exact')
    end

    local min_level = m.blizzard_level(m.min_level_input:GetText())
    if min_level then
        add(min_level)
    end

    local max_level = m.blizzard_level(m.max_level_input:GetText())
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

    local quality = UIDropDownMenu_GetSelectedValue(m.quality_dropdown)
    if quality and quality >= 0 then
        add(strlower(getglobal('ITEM_QUALITY'..quality..'_DESC')))
    end

    return query_string
end

function private.set_form(components)
    m.clear_form()

    local class_index, subclass_index

    for _, filter in components.blizzard do
        if filter[1] == 'name' then
            local name = filter[2]
            if name and strsub(name, 1, 1) == '"' and strsub(name, -1, -1) == '"' then
                name = strsub(name, 2, -2)
            end
            m.name_input:SetText(aux.filter.unquote(filter[2]))
        elseif filter[1] == 'exact' then
            m.exact_checkbox:SetChecked(true)
        elseif filter[1] == 'min_level' then
            m.min_level_input:SetText(tonumber(filter[2]))
        elseif filter[1] == 'max_level' then
            m.max_level_input:SetText(tonumber(filter[2]))
        elseif filter[1] == 'usable' then
            m.usable_checkbox:SetChecked(true)
        elseif filter[1] == 'class' then
            class_index = aux.info.item_class_index(filter[2])
            UIDropDownMenu_SetSelectedValue(m.class_dropdown, class_index)
        elseif filter[1] == 'subclass' then
            subclass_index = aux.info.item_subclass_index(class_index, filter[2])
            UIDropDownMenu_SetSelectedValue(m.subclass_dropdown, subclass_index)
        elseif filter[1] == 'slot' then
            UIDropDownMenu_SetSelectedValue(m.slot_dropdown, ({GetAuctionInvTypes(class_index, subclass_index)})[aux.info.item_slot_index(class_index, subclass_index, filter[2])])
        elseif filter[1] == 'quality' then
            UIDropDownMenu_SetSelectedValue(m.quality_dropdown, aux.info.item_quality_index(filter[2]))
        end
    end

    m.post_components = components.post
    m.update_filter_display()
end

function private.import_query_string()
    local components, error = aux.filter.parse_query_string(({strfind(m.search_box:GetText(), '^([^;]*)')})[3])
    if components then
        m.set_form(components)
    else
        aux.log(error)
    end
end

function private.export_query_string()
    local components, error = aux.filter.parse_query_string(m.get_form())
    if components then
        m.search_box:SetText(aux.filter.query_string({blizzard=components.blizzard, post=m.post_components}))
        m.filter_input:ClearFocus()
        m.update_filter_display()
    else
        aux.log(error)
    end
end

private.post_components = {}

function private.add_post_component()
    local name = UIDropDownMenu_GetSelectedValue(m.filter_dropdown)
    if name then
        local filter = name
        if not aux.filter.filters[name] and filter == 'and' or filter == 'or' then
            local arity = m.filter_input:GetText()
            arity = tonumber(arity) and aux.util.round(tonumber(arity))
            if arity and arity < 2 then
                aux.log('Invalid operator suffix')
                return
            end
            filter = filter..(arity or '')
        end
        if aux.filter.filters[name] and aux.filter.filters[name].input_type ~= '' then
            filter = filter..'/'..m.filter_input:GetText()
        end

        local components, error, suggestions = aux.filter.parse_query_string(filter)

        if components then
            tinsert(m.post_components, components.post[1])
            m.update_filter_display()
            m.filter_input:SetText('')
            m.filter_input:ClearFocus()
        else
            aux.log(error)
        end
    end
end

function private.remove_post_filter()
    tremove(m.post_components)
    m.update_filter_display()
end

do
	local text

	function private.update_filter_display()
		text = aux.filter.indented_post_query_string(m.post_components)
		m.filter_display:SetWidth(m.filter_display_size())
		m.set_filter_display_offset()
		m.filter_display:SetText(text)
	end

	function private.filter_display_size()
		local font, font_size = m.filter_display:GetFont()
		m.filter_display.measure:SetFont(font, font_size)
		local lines = 0
		local width = 0

		for line in string.gfind(text, '<p>(.-)</p>') do
			lines = lines + 1
			m.filter_display.measure:SetText(line)
			width = max(width, m.filter_display.measure:GetStringWidth())
		end

		return width, lines * (font_size + .5)
	end
end

function private.set_filter_display_offset(x_offset, y_offset)
	local scroll_frame = m.filter_display:GetParent()
	x_offset, y_offset = x_offset or scroll_frame:GetHorizontalScroll(), y_offset or scroll_frame:GetVerticalScroll()
	local width, height = m.filter_display_size()
	local x_lower_bound = min(0, scroll_frame:GetWidth() - width - 10)
	local x_upper_bound = 0
	local y_lower_bound = 0
	local y_upper_bound = max(0, height - scroll_frame:GetHeight())
	scroll_frame:SetHorizontalScroll(aux.util.bound(x_lower_bound, x_upper_bound, x_offset))
	scroll_frame:SetVerticalScroll(aux.util.bound(y_lower_bound, y_upper_bound, y_offset))
end

function private.new_recent_search(filter_string, prettified)
	tinsert(aux_recent_searches, 1, {
		filter_string = filter_string,
		prettified = prettified,
	})
	while getn(aux_recent_searches) > 50 do
		tremove(aux_recent_searches)
	end
	m.update_search_listings()
end

