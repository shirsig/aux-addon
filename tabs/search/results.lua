select(2, ...) 'aux.tabs.search'

local aux = require 'aux'
local info = require 'aux.util.info'
local filter_util = require 'aux.util.filter'
local scan_util = require 'aux.util.scan'
local scan = require 'aux.core.scan'

NORMAL_MODE, FRESH_MODE, EXPIRING_MODE = {}, {}, {} -- TODO expiring

mode = nil

StaticPopupDialogs.AUX_SCAN_ALERT = {
    text = 'One of your alert queries matched!',
    button1 = 'Ok',
    showAlert = 1,
    timeout = 0,
    hideOnEscape = 1,
}

function aux.event.AUX_LOADED()
	new_search(nil, NORMAL_MODE)
end

function update_mode(mode)
    _M.mode = mode
	if mode == NORMAL_MODE then
		mode_button:SetText('Normal')
    else
        mode_button:SetText('Fresh')
	end
end

do
	local searches = {}
	local search_index = 1

    function M.clear_selection()
        if searches[search_index] then
            searches[search_index].table:SetSelectedRecord()
        end
    end

	function current_search()
		return searches[search_index]
	end

	function update_search(index)
		searches[search_index].table:Hide()
		searches[search_index].table:SetSelectedRecord()

		search_index = index

		searches[search_index].table:Show()

		search_box:SetText(searches[search_index].filter_string or '')
		if search_index == 1 then
			previous_button:Disable()
		else
			previous_button:Enable()
		end
		if search_index == #searches then
			next_button:Hide()
			mode_button:SetPoint('LEFT', previous_button, 'RIGHT', 4, 0)
		else
			next_button:Show()
			mode_button:SetPoint('LEFT', next_button, 'RIGHT', 4, 0)
		end
		update_mode(searches[search_index].mode)
		update_start_stop()
		update_continuation()
	end

	function new_search(filter_string, mode)
		while #searches > search_index do
			tremove(searches)
		end
		local search = { records = {}, filter_string = filter_string, mode = mode }
		tinsert(searches, search)
		if #searches > 5 then
			tremove(searches, 1)
			tinsert(tables, tremove(tables, 1))
			search_index = 4
		end

		aux.status_bar:update_status(1, 1)

		search.table = tables[#searches]
		search.table:SetSort(1, 2, 3, 4, 5, 6, 7, 8, 9)
		search.table:Reset()
		search.table:SetDatabase(search.records)

		update_search(#searches)
	end

	function previous_search()
        search_box:ClearFocus()
		update_search(search_index - 1)
		set_subtab(RESULTS)
	end

	function next_search()
        search_box:ClearFocus()
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
	scan.abort()
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

function start_fresh_scan(query, search, continuation)

    local ignore_page
    if not search then
		search = current_search()
		query.blizzard_query.first_page = tonumber(continuation) or 0
		query.blizzard_query.last_page = tonumber(continuation) or 0
		ignore_page = not tonumber(continuation)
    end

    local next_page
	local new_records = {}
	scan.start{
		type = 'list',
		queries = {query},
		on_scan_start = function()
			aux.status_bar:update_status(.9999, .9999)
		end,
        on_page_loaded = function(_, _, last_page)
            next_page = last_page
            if last_page == 0 then
                ignore_page = false
            end
        end,
		on_auction = function(auction_record)
            if not ignore_page then
                if (search.alert_validator or pass)(auction_record) then
                    StaticPopup_Show('AUX_SCAN_ALERT') -- TODO retail improve this
                end
                tinsert(new_records, auction_record)
            end
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

            query.blizzard_query.first_page = next_page
            query.blizzard_query.last_page = next_page
			start_fresh_scan(query, search)
		end,
		on_abort = function()
			aux.status_bar:update_status(1, 1)

			search.continuation = next_page or not ignore_page and query.blizzard_query.first_page or true

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


	scan.start{
		type = 'list',
		queries = queries,
        alert_validator = search.alert_validator,
		on_scan_start = function()
			aux.status_bar:update_status(0, 0)
		end,
		on_page_loaded = function(_, total_scan_pages)
			current_page = current_page + 1
			total_scan_pages = total_scan_pages + (start_page - 1)
			total_scan_pages = max(total_scan_pages, 1)
			current_page = min(current_page, total_scan_pages)
			aux.status_bar:update_status(current_page / total_scan_pages, current_query / #queries)
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
			aux.status_bar:update_status(1, 1)

			if current_search() == search and frame.results:IsVisible() and #search.records == 0 then
				set_subtab(SAVED)
			end

			search.active = false
			update_start_stop()
		end,
		on_abort = function()
			aux.status_bar:update_status(1, 1)

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

function M.execute(_, resume, mode)

	if resume then
		mode = current_search().mode
	elseif mode == nil then
		mode = _M.mode
	end

	if resume then
		search_box:SetText(current_search().filter_string)
	end
	local filter_string = search_box:GetText()

	local queries, error = filter_util.queries(filter_string)
	if not queries then
		aux.print('Invalid filter:', error)
		return
	elseif mode == FRESH_MODE then
		if #queries > 1 then
			aux.print('Error: The real time mode does not support multi-queries')
			return
		end
	end

	if resume then
		current_search().table:SetSelectedRecord()
	else
		if filter_string ~= current_search().filter_string then
			if current_search().filter_string then
				new_search(filter_string, mode)
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
		search.mode = mode
		search.alert_validator = get_alert_validator()
	end

	local continuation = resume and current_search().continuation
	discard_continuation()
	current_search().active = true
	update_start_stop()
    search_box:ClearFocus()
	set_subtab(RESULTS)
	if mode == FRESH_MODE then
		start_fresh_scan(queries[1], nil, continuation)
	else
		start_search(queries, continuation)
	end
end

do
	local IDLE, SEARCHING, FOUND = aux.enum(3)
	local state = IDLE
	local found_index

	function find_auction(record)
		local search = current_search()

		if not search.table:ContainsRecord(record) or info.is_player(record.owner) then
			return
		end

		scan.abort()
		state = SEARCHING
		scan_util.find(
			record,
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
						if scan_util.test('list', record, index) and search.table:ContainsRecord(record) then
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
						if scan_util.test('list', record, index) and search.table:ContainsRecord(record) then
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
		elseif state == FOUND and not scan_util.test('list', selection.record, found_index) then
			buyout_button:Disable()
			bid_button:Disable()
			if not aux.bid_in_progress() then
				state = IDLE
			end
		end
	end
end

