local MAX_HISTORY_SIZE = 100
local MIN_SEEN = 1
local UNDERCUT_FACTOR = 0.2

Aux.history = {}

local process_auction, balanced_list, update_snapshot
local get_market_price, get_usable_median, get_historical_median, get_median, get_percentile

local auction_cache

function Aux.history.on_close()

end

function Aux.history.on_open()

end

function Aux.history.start_scan()

    if not AuxHistoryScanButton:IsVisible() then
        return
    end

    AuxHistoryScanButton:Hide()
    AuxHistoryStopButton:Show()

    auction_cache = {}

    Aux.log('Scanning auctions ...')
    Aux.scan.start{
        query = {},
        page = 0,
        on_page_loaded = function(page, total_pages)
            Aux.log('Scanning page '..(page+1)..' out of '..total_pages..' ...')
        end,
        on_read_auction = function(i)
            process_auction(i)
        end,
        on_complete = function()
            process_scanned_auctions()

            AuxHistoryStopButton:Hide()
            AuxHistoryScanButton:Show()
        end,
        on_abort = function()
            process_scanned_auctions()

            AuxHistoryStopButton:Hide()
            AuxHistoryScanButton:Show()
        end,
        next_page = function(page, total_pages)
            if AuxBuyAllPagesCheckButton:GetChecked() then
                local last_page = max(total_pages - 1, 0)
                if page < last_page then
                    return page + 1
                end
            end
        end,
    }
end

function process_scanned_auctions()
    local time = time()
	for item_key, auctions in pairs(auction_cache) do
        local min_price, accumulated_price
        for _, auction in ipairs(auctions) do
            min_price = min_price and min(min_price, auction.price) or auction.price
            accumulated_price = (accumulated_price or 0) + auction.price
        end
        Aux.persistence.store_scan_record(item_key, {
            time = time,
            count = getn(auctions),
            min_price = min_price,
            accumulated_price = accumulated_price,
        })
	end
end

function Aux.history.stop_scan()
    Aux.scan.abort()
end

function process_auction(index)
    local auction_info = Aux.info.auction_item(index)
    local buyout_price = Aux.util.safe_index{auction_info, 'buyout_price'}
    if buyout_price and buyout_price > 0 then
        local aux_quantity = auction_info.charges or auction_info.count
        local price = ceil(buyout_price / aux_quantity)
        local item_key = auction_info.item_signature

        auction_cache[item_key] = auction_cache[item_key] or {}
        tinsert(auction_cache[item_key], { price=price })
    end
end
