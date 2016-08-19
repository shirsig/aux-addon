aux.module 'search_tab'

g.aux_auto_buy_filter = ''

search_scan_id = 0
auto_buy_validator = nil

do
	local searches = {}
	local search_index = 1

	function current_search()
		return searches[search_index]
	end

	function update_search(index)
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

	function new_search(filter_string)
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

	function previous_search()
		m.search_box:ClearFocus()
		m.update_search(search_index - 1)
		m.update_tab(m.RESULTS)
	end

	function next_search()
		m.search_box:ClearFocus()
		m.update_search(search_index + 1)
		m.update_tab(m.RESULTS)
	end
end

function close_settings()
	if m.settings_button.open then
		m.settings_button:Click()
	end
end

function update_continuation()
	if m.current_search().continuation then
		m.resume_button:Show()
		m.search_box:SetPoint('RIGHT', m.resume_button, 'LEFT', -4, 0)
	else
		m.resume_button:Hide()
		m.search_box:SetPoint('RIGHT', m.start_button, 'LEFT', -4, 0)
	end
end

function discard_continuation()
	aux.scan.abort(m.search_scan_id)
	m.current_search().continuation = nil
	m.update_continuation()
end

function update_start_stop()
	if m.current_search().active then
		m.stop_button:Show()
		m.start_button:Hide()
	else
		m.start_button:Show()
		m.stop_button:Hide()
	end
end

function update_auto_buy_filter()
	if g.aux_auto_buy_filter ~= '' then
		local queries = aux.filter.queries(g.aux_auto_buy_filter)
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
	g.aux_auto_buy_filter = ''
end

function start_real_time_scan(query, search, continuation)

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
					aux.place_bid('list', auction_record.index, auction_record.buyout_price, aux.C(ctrl.resume, true))
					aux.control.thread(aux.control.when, aux.util.later(GetTime(), 10), aux.C(ctrl.resume, false))
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

function start_search(queries, continuation)
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
				aux.place_bid('list', auction_record.index, auction_record.buyout_price, aux.C(ctrl.resume, true))
				aux.control.thread(aux.control.when, aux.util.later(GetTime(), 10), aux.C(ctrl.resume, false))
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
			m.new_recent_search(filter_string, table.concat(aux.util.map(queries, function(filter) return filter.prettified end), ';'))
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

function test(record)
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

	function find_auction(record)
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
							end or aux.C(search.table.RemoveAuctionRecord, search.table, record))
						end
					end)
					m.bid_button:Enable()
				end

				if record.buyout_price > 0 then
					m.buyout_button:SetScript('OnClick', function()
						if m.test(record)(index) and search.table:ContainsRecord(record) then
							aux.place_bid('list', index, record.buyout_price, aux.C(search.table.RemoveAuctionRecord, search.table, record))
						end
					end)
					m.buyout_button:Enable()
				end
			end
		)
	end

	function on_update()
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