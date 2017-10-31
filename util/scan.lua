module 'aux.util.scan'

include 'aux'

local T = require 'T'

local info = require 'aux.util.info'
local filter_util = require 'aux.util.filter'
local scan = require 'aux.core.scan'

function M.test(record, index)
	local auction_record = T.temp-info.auction(index, record.query_type)
	return auction_record and auction_record.search_signature == record.search_signature
end

function M.find(auction_record, status_bar, on_abort, on_failure, on_success)

    local queries = T.list(T.acquire())

    if auction_record.blizzard_query then
        local blizzard_query1 = copy(auction_record.blizzard_query)
        blizzard_query1.first_page = auction_record.page
        blizzard_query1.last_page = auction_record.page
        tinsert(queries, T.map('blizzard_query', blizzard_query1))

        if auction_record.page > 0 then
            local blizzard_query2 = copy(auction_record.blizzard_query)
            blizzard_query2.first_page = auction_record.page - 1
            blizzard_query2.last_page = auction_record.page - 1
            tinsert(queries, T.map('blizzard_query', blizzard_query2))
        end

        local item_query = item_query(auction_record.item_id, 0, 0)
        if not eq(auction_record.blizzard_query, item_query.blizzard_query) then
            tinsert(queries, item_query)
        end
    end

    local found
    return scan.start{
        type = auction_record.query_type,
        queries = queries,
        on_scan_start = function()
            status_bar:update_status(0, 0)
            status_bar:set_text('Searching auction...')
        end,
        on_start_query = function(query_index)
            status_bar:update_status((query_index - 1) / getn(queries), 0)
        end,
        on_auction = function(record)
            if test(auction_record, record.index) then
                found = true
                scan.stop()
                status_bar:update_status(1, 1)
                status_bar:set_text('Auction found')
                return on_success(record.index)
            end
        end,
        on_abort = function()
            if not found then
                status_bar:update_status(1, 1)
                status_bar:set_text('Auction not found')
                return on_abort()
            end
        end,
        on_complete = function()
	        if not found then
	            status_bar:update_status(1, 1)
	            status_bar:set_text('Auction not found')
	            return on_failure()
	        end
        end,
    }
end

function M.item_query(item_id, first_page, last_page)
	local item_info = info.item(item_id)
    if item_info then
        local query = filter_util.query(item_info.name .. '/exact')
        query.blizzard_query.first_page = first_page
        query.blizzard_query.last_page = last_page
        return T.map('validator', query.validator, 'blizzard_query', query.blizzard_query)
    end
end