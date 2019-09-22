select(2, ...) 'aux.tabs.search'

local T = require 'T'
local aux = require 'aux'
local info = require 'aux.util.info'
local filter_util = require 'aux.util.filter'
local scan_util = require 'aux.util.scan'
local scan = require 'aux.core.scan'

StaticPopupDialogs.AUX_SCAN_ALERT = {
    text = 'One of your alert queries matched!',
    button1 = 'Ok',
    showAlert = 1,
    timeout = 0,
    hideOnEscape = 1,
}

search_scan_id = 0

function aux.handle.LOAD()
	new_search()
end

function update_real_time(enable)
	if enable then
		range_button:Hide()
		real_time_button:Show()
		search_box:SetPoint('LEFT', real_time_button, 'RIGHT', 4, 0)
	else
		real_time_button:Hide()
		range_button:Show()
		search_box:SetPoint('LEFT', last_page_input, 'RIGHT', 4, 0)
	end
end

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

		search_box:SetText(searches[search_index].filter_string or '')
		first_page_input:SetText(searches[search_index].first_page and searches[search_index].first_page + 1 or '')
		last_page_input:SetText(searches[search_index].last_page and searches[search_index].last_page + 1 or '')
		if search_index == 1 then
			previous_button:Disable()
		else
			previous_button:Enable()
		end
		if search_index == #searches then
			next_button:Hide()
			range_button:SetPoint('LEFT', previous_button, 'RIGHT', 4, 0)
			real_time_button:SetPoint('LEFT', previous_button, 'RIGHT', 4, 0)
		else
			next_button:Show()
			range_button:SetPoint('LEFT', next_button, 'RIGHT', 4, 0)
			real_time_button:SetPoint('LEFT', next_button, 'RIGHT', 4, 0)
		end
		update_real_time(searches[search_index].real_time)
		update_start_stop()
		update_continuation()
	end

	function new_search(filter_string, first_page, last_page, real_time)
		while #searches > search_index do
			tremove(searches)
		end
		local search = T.map('records', {}, 'filter_string', filter_string, 'first_page', first_page, 'last_page', last_page, 'real_time', real_time)
		tinsert(searches, search)
		if #searches > 5 then
			tremove(searches, 1)
			tinsert(status_bars, tremove(status_bars, 1))
			tinsert(tables, tremove(tables, 1))
			search_index = 4
		end

		search.status_bar = status_bars[#searches]
		search.status_bar:update_status(1, 1)
		search.status_bar:set_text('')

		search.table = tables[#searches]
		search.table:SetSort(1, 2, 3, 4, 5, 6, 7, 8, 9)
		search.table:Reset()
		search.table:SetDatabase(search.records)

		update_search(#searches)
	end

	function clear_control_focus()
		search_box:ClearFocus()
		first_page_input:ClearFocus()
		last_page_input:ClearFocus()
	end

	function previous_search()
		clear_control_focus()
		update_search(search_index - 1)
		set_subtab(RESULTS)
	end

	function next_search()
		clear_control_focus()
		update_search(search_index + 1)
		set_subtab(RESULTS)
	end
end

function update_continuation()
	if current_search().continuation then
		resume_button:Show()
		search_box:SetPoint('RIGHT', resume_button, 'LEFT', -4, 0)
	else
		resume_button:Hide()
		search_box:SetPoint('RIGHT', start_button, 'LEFT', -4, 0)
	end
end

function discard_continuation()
	scan.abort(search_scan_id)
	current_search().continuation = nil
	update_continuation()
end

function update_start_stop()
	if current_search().active then
		stop_button:Show()
		start_button:Hide()
	else
		start_button:Show()
		stop_button:Hide()
	end
end

function start_real_time_scan(query, search, continuation)

	if not search then
		search = current_search()
		query.blizzard_query.first_page = 0
		query.blizzard_query.last_page = 0
		ignore_page = not tonumber(continuation)
	end

	local new_records = {}
	search_scan_id = scan.start{
		type = 'list',
		queries = {query},
		on_scan_start = function()
			search.status_bar:update_status(.9999, .9999)
			search.status_bar:set_text('Scanning ...')
		end,
		on_auction = function(auction_record)
            if (search.alert_validator or pass)(auction_record) then
                StaticPopup_Show('AUX_SCAN_ALERT') -- TODO retail improve this
            end
			tinsert(new_records, auction_record)
		end,
		on_complete = function()
			local map = {}
			for _, record in pairs(search.records) do
				map[record.sniping_signature] = record
			end
			for _, record in pairs(new_records) do
				map[record.sniping_signature] = record
			end
			new_records = aux.values(map)

			if #new_records > 2000 then
				StaticPopup_Show('AUX_SEARCH_TABLE_FULL')
			else
				search.records = new_records
				search.table:SetDatabase(search.records)
			end

			start_real_time_scan(query, search)
		end,
		on_abort = function()
			search.status_bar:update_status(1, 1)
			search.status_bar:set_text('Scan paused')

			search.continuation = true

			if current_search() == search then
				update_continuation()
			end

			search.active = false
			update_start_stop()
		end,
	}
end

function start_search(queries, continuation)
	local current_query, current_page, total_queries, start_query, start_page

	local search = current_search()

	total_queries = #queries

	if continuation then
		start_query, start_page = unpack(continuation)
		for i = 1, start_query - 1 do
			tremove(queries, 1)
		end
		queries[1].blizzard_query.first_page = (queries[1].blizzard_query.first_page or 0) + start_page - 1
		search.table:SetSelectedRecord()
	else
		start_query, start_page = 1, 1
	end


	search_scan_id = scan.start{
		type = 'list',
		queries = queries,
        alert_validator = search.alert_validator,
		on_scan_start = function()
			search.status_bar:update_status(0, 0)
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
			search.status_bar:update_status((current_query - 1) / #queries, current_page / total_scan_pages)
			search.status_bar:set_text(format('Scanning %d / %d (Page %d / %d)', current_query, total_queries, current_page, total_scan_pages))
		end,
		on_page_scanned = function()
			search.table:SetDatabase()
		end,
		on_start_query = function(query)
			current_query = current_query and current_query + 1 or start_query
			current_page = current_page and 0 or start_page - 1
		end,
		on_auction = function(auction_record)
            if (search.alert_validator or pass)(auction_record) then
                StaticPopup_Show('AUX_SCAN_ALERT') -- TODO retail improve this
            end
			if #search.records < 2000 then
				tinsert(search.records, auction_record)
				if #search.records == 2000 then
					StaticPopup_Show('AUX_SEARCH_TABLE_FULL')
				end
			end
		end,
		on_complete = function()
			search.status_bar:update_status(1, 1)
			search.status_bar:set_text('Scan complete')

			if current_search() == search and frame.results:IsVisible() and #search.records == 0 then
				set_subtab(SAVED)
			end

			search.active = false
			update_start_stop()
		end,
		on_abort = function()
			search.status_bar:update_status(1, 1)
			search.status_bar:set_text('Scan paused')

			if current_query then
				search.continuation = {current_query, current_page + 1}
			else
				search.continuation = {start_query, start_page}
			end
			if current_search() == search then
				update_continuation()
			end

			search.active = false
			update_start_stop()
		end,
	}
end

function M.execute(_, resume, real_time)

	if resume then
		real_time = current_search().real_time
	elseif real_time == nil then
		real_time = real_time_button:IsShown()
	end

	if resume then
		search_box:SetText(current_search().filter_string)
	end
	local filter_string, first_page, last_page = search_box:GetText(), blizzard_page_index(first_page_input:GetText()), blizzard_page_index(last_page_input:GetText())

	local queries, error = filter_util.queries(filter_string)
	if not queries then
		aux.print('Invalid filter:', error)
		return
	elseif real_time then
		if #queries > 1 then
			aux.print('Error: The real time mode does not support multi-queries')
			return
		elseif queries[1].blizzard_query.first_page or queries[1].blizzard_query.last_page then
			aux.print('Error: The real time mode does not support page ranges')
			return
		end
	end

	if resume then
		current_search().table:SetSelectedRecord()
	else
		if filter_string ~= current_search().filter_string then
			if current_search().filter_string then
				new_search(filter_string, first_page, last_page, real_time)
			else
				current_search().filter_string = filter_string
			end
			new_recent_search(filter_string, aux.join(aux.map(aux.copy(queries), function(filter) return filter.prettified end), ';'))
		else
			local search = current_search()
			search.records = {}
			search.table:Reset()
			search.table:SetDatabase(search.records)
		end
		local search = current_search()
		search.first_page = first_page
		search.last_page = last_page
		search.real_time = real_time
		search.alert_validator = get_alert_validator()
	end

	local continuation = resume and current_search().continuation
	discard_continuation()
	current_search().active = true
	update_start_stop()
	clear_control_focus()
	set_subtab(RESULTS)
	if real_time then
		start_real_time_scan(queries[1], nil, continuation)
	else
		for _, query in pairs(queries) do
			query.blizzard_query.first_page = current_search().first_page
			query.blizzard_query.last_page = current_search().last_page
		end
		start_search(queries, continuation)
	end
end

do
	local scan_id = 0
	local IDLE, SEARCHING, FOUND = aux.enum(3)
	local state = IDLE
	local found_index

	function find_auction(record)
		local search = current_search()

		if not search.table:ContainsRecord(record) or info.is_player(record.owner) then
			return
		end

		scan.abort(scan_id)
		state = SEARCHING
		scan_id = scan_util.find(
			record,
			current_search().status_bar,
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
					bid_button:SetScript('OnClick', function()
						if scan_util.test(record, index) and search.table:ContainsRecord(record) then
							aux.place_bid('list', index, record.bid_price, record.bid_price < record.buyout_price and function()
								info.bid_update(record)
								search.table:SetDatabase()
							end or function() search.table:RemoveAuctionRecord(record) end)
						end
					end)
					bid_button:Enable()
				else
					bid_button:Disable()
				end

				if record.buyout_price > 0 then
					buyout_button:SetScript('OnClick', function()
						if scan_util.test(record, index) and search.table:ContainsRecord(record) then
							aux.place_bid('list', index, record.buyout_price, function() search.table:RemoveAuctionRecord(record) end)
						end
					end)
					buyout_button:Enable()
				else
					buyout_button:Disable()
				end
			end
		)
	end

	function on_update()
		if state == IDLE or state == SEARCHING then
			buyout_button:Disable()
			bid_button:Disable()
		end

		if state == SEARCHING then return end

		local selection = current_search().table:GetSelection()
		if not selection then
			state = IDLE
		elseif selection and state == IDLE then
			find_auction(selection.record)
		elseif state == FOUND and not scan_util.test(selection.record, found_index) then
			buyout_button:Disable()
			bid_button:Disable()
			if not aux.bid_in_progress() then
				state = IDLE
			end
		end
	end
end