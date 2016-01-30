local private, public = {}, {}
Aux.item_search_frame = public

aux_recently_searched = {}

local auctions
local search_query
local refresh
local selected_auction

function private.select_auction(entry)
    selected_auction = entry
    refresh = true
    private.buyout_button:Disable()
    private.bid_button:Disable()
end

function private.clear_selection(entry)
    selected_auction = nil
    refresh = true
    private.buyout_button:Disable()
    private.bid_button:Disable()
end

function public.on_close()
    private.clear_selection()
end

function public.on_open()
    public.update_item()
    private.update_recently_searched()
    if not private.item_id then
        AuxItemSearchFrameItemRefreshButton:Disable()
    end
end

function public.on_load()
    private.recently_searched_config = {
        plain = true,
        frame = AuxItemSearchFrameRecentlySearchedListing,
        on_row_click = function (sheet, row_index)
            PlaySound('igMainMenuOptionCheckBoxOn')
            local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
            AuxItemSearchFrameItemItemInputBox:Hide()
            public.set_item(sheet.data[data_index].item_id)
        end,
        columns = {
            {
                title = 'Item',
                width = 163,
                comparator = function(datum1, datum2)
                    return Aux.util.compare(datum1.time, datum2.time, Aux.util.GT)
                end,
                cell_initializer = function(cell)
                    local icon = CreateFrame('Button', nil, cell)
                    icon:EnableMouse(false)
                    local icon_texture = icon:CreateTexture(nil, 'BORDER')
                    icon_texture:SetAllPoints(icon)
                    icon.icon_texture = icon_texture
                    local normal_texture = icon:CreateTexture(nil)
                    normal_texture:SetPoint('CENTER', 0, 0)
                    normal_texture:SetWidth(22)
                    normal_texture:SetHeight(22)
                    normal_texture:SetTexture('Interface\\Buttons\\UI-Quickslot2')
                    icon:SetNormalTexture(normal_texture)
                    icon:SetPoint('LEFT', cell)
                    icon:SetWidth(12)
                    icon:SetHeight(12)
                    local text = cell:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
                    text:SetPoint('LEFT', icon, 'RIGHT', 1, 0)
                    text:SetPoint('TOPRIGHT', cell)
                    text:SetPoint('BOTTOMRIGHT', cell)
                    text:SetJustifyV('TOP')
                    text:SetJustifyH('LEFT')
                    text:SetTextColor(0.8, 0.8, 0.8)
                    cell.text = text
                    cell.icon = icon
                end,
                cell_setter = function(cell, datum)
                    local item_info = Aux.static.item_info(datum.item_id)
                    cell.icon.icon_texture:SetTexture(item_info.texture)
                    cell.text:SetText('['..item_info.name..']')
                    local color = ITEM_QUALITY_COLORS[item_info.quality]
                    cell.text:SetTextColor(color.r, color.g, color.b)
                end,
            },
        },
        sort_order = {},
    }
    private.results_config = {
        frame = AuxItemSearchFrameAuctionsBuyListing,
        on_row_click = function(sheet, row_index)
            local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
            private.on_row_click(sheet.data[data_index], true)
        end,
        on_row_enter = function(sheet, row_index)
            Aux.info.set_tooltip(sheet.rows[row_index].itemstring, sheet.rows[row_index].EnhTooltip_info, this, 'ANCHOR_RIGHT', 0, 0)
        end,
        on_row_leave = function(sheet, row_index)
            AuxTooltip:Hide()
            ResetCursor()
        end,
        on_row_update = function(sheet, row_index)
            if IsControlKeyDown() then
                ShowInspectCursor()
            elseif IsAltKeyDown() then
                SetCursor('BUY_CURSOR')
            else
                ResetCursor()
            end
        end,
        selected = function(datum)
            return Aux.util.any(datum, function(entry) return entry == selected_auction end)
        end,
        row_setter = function(row, group)
            row:SetAlpha(Aux.util.all(group, function(auction) return auction.gone end) and 0.3 or 1)
            row.itemstring = Aux.info.itemstring(group[1].item_id, group[1].suffix_id, nil, group[1].enchant_id)
            row.EnhTooltip_info = group[1].EnhTooltip_info
        end,
        columns = {
            {
                title = 'Qty',
                width = 25,
                comparator = function(group1, group2) return Aux.util.compare(group1[1].aux_quantity, group2[1].aux_quantity, Aux.util.LT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, group)
                    cell.text:SetText(group[1].aux_quantity)
                end,
            },
            Aux.listing_util.money_column('Bid', function(group) return group[1].bid_price end),
            Aux.listing_util.money_column('Buy', function(group) return group[1].buyout_price end),
            Aux.listing_util.money_column('Bid/ea', function(group) return group[1].unit_bid_price end),
            Aux.listing_util.money_column('Buy/ea', function(group) return group[1].unit_buyout_price end),
            {
                title = 'Lvl',
                width = 25,
                comparator = function(group1, group2) return Aux.util.compare(group1[1].level, group2[1].level, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, group)
                    local level = max(1, group[1].level)
                    local text
                    if level > UnitLevel('player') then
                        text = RED_FONT_COLOR_CODE..level..FONT_COLOR_CODE_CLOSE
                    else
                        text = level
                    end
                    cell.text:SetText(text)
                end,
            },
            {
                title = 'Status',
                width = 70,
                comparator = function(group1, group2) return Aux.util.compare(group1[1].status, group2[1].status, Aux.util.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('CENTER'),
                cell_setter = function(cell, group)
                    cell.text:SetText(group[1].status)
                end,
            },
            Aux.listing_util.duration_column(function(group) return group[1].duration end),
            Aux.listing_util.owner_column(function(group) return group[1].owner end),
            {
                title = 'Avail',
                width = 40,
                comparator = function(group1, group2) return Aux.util.compare(getn(Aux.util.filter(group1, function(auction) return not auction.gone end)), getn(Aux.util.filter(group2, function(auction) return not auction.gone end)), Aux.util.LT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, group)
                    cell.text:SetText(getn(Aux.util.filter(group, function(auction) return not auction.gone end)))
                end,
            },
            Aux.listing_util.percentage_market_column(function(group) return group[1].item_key end, function(group) return group[1].unit_buyout_price end),
        },
        sort_order = {{column = 3, order = 'ascending' }},
    }

    private.listings = {
        recently_searched = Aux.sheet.create(private.recently_searched_config),
        results = Aux.sheet.create(private.results_config),
    }
    do
        local btn = Aux.gui.button(AuxItemSearchFrameItem, 16, '$parentRefreshButton')
        btn:SetPoint('BOTTOMLEFT', 8, 15)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Refresh')
        btn:SetScript('OnClick', Aux.item_search_frame.start_search)
    end
    do
        local btn = Aux.gui.button(AuxItemSearchFrameItem, 16, '$parentStopButton')
        btn:SetPoint('BOTTOMLEFT', 8, 15)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Stop')
        btn:SetScript('OnClick', Aux.item_search_frame.stop_search)
        btn:Hide()
    end
    do
        local editbox = Aux.gui.editbox(AuxItemSearchFrameItem, '$parentItemInputBox')
        editbox.selector = Aux.completion.selector(editbox, function() AuxItemSearchFrameItemItemInputBox:ClearFocus() end)
        editbox:SetPoint('TOP', 0, -28)
        editbox:SetWidth(185)
        editbox:SetScript('OnTextChanged', function()
            this.selector.suggest()
        end)
        editbox:SetScript('OnTabPressed', function()
            if IsShiftKeyDown() then
                this.selector.previous()
            else
                this.selector.next()
            end
        end)
        editbox:SetScript('OnEnterPressed', function()
            if this.selector.selected_value() then
                this:ClearFocus()
            end
        end)
        editbox:SetScript('OnEditFocusLost', function()
            this.selector.close()
            if this.selector.selected_value() then
                Aux.item_search_frame.set_item(this.selector.selected_value())
            end
            if Aux.item_search_frame.item_set() then
                this:Hide()
                this.selector.clear()
                Aux.item_search_frame.update_item()
            end
        end)
        editbox:SetScript('OnEscapePressed', function()
            this.selector.clear()
            this:ClearFocus()
        end)
    end
    do
        local status_bar = Aux.gui.status_bar(AuxItemSearchFrame)
        status_bar:SetWidth(265)
        status_bar:SetHeight(30)
        status_bar:SetPoint('BOTTOMLEFT', AuxItemSearchFrame, 'BOTTOMLEFT', 6, 6)
        status_bar:update_status(100, 0)
        status_bar:set_text('')
        private.status_bar = status_bar
    end
    do
        local btn = Aux.gui.button(AuxItemSearchFrame, 16)
        btn:SetPoint('TOPLEFT', private.status_bar, 'TOPRIGHT', 5, 0)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Buyout')
        btn:Disable()
        private.buyout_button = btn
    end
    do
        local btn = Aux.gui.button(AuxItemSearchFrame, 16)
        btn:SetPoint('TOPLEFT', private.buyout_button, 'TOPRIGHT', 5, 0)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Bid')
        btn:Disable()
        private.bid_button = btn
    end
end

function public.stop_search()
	Aux.scan.abort()
end

function private.update_listing()

    if not AuxItemSearchFrame:IsVisible() then
        return
    end

	AuxItemSearchFrameAuctionsBuyListing:Hide()
    AuxItemSearchFrameAuctionsBidListing:Hide()
    AuxItemSearchFrameAuctionsFullListing:Hide()

    AuxItemSearchFrameAuctionsBuyListing:Show()
    local buy_records = auctions and Aux.util.filter(auctions, function(auction) return auction.owner ~= UnitName('player') and auction.buyout_price end) or {}
    Aux.sheet.populate(private.listings.results, auctions and Aux.util.group_by(buy_records, function(a1, a2)
        return a1.item_id == a2.item_id
                and a1.suffix_id == a2.suffix_id
                and a1.enchant_id == a2.enchant_id
                and a1.aux_quantity == a2.aux_quantity
                and a1.buyout_price == a2.buyout_price
                and a1.bid_price == a2.bid_price
                and a1.owner == a2.owner
    end) or {})
    AuxItemSearchFrameAuctions:SetWidth(AuxItemSearchFrameAuctionsBuyListing:GetWidth() + 40)
    AuxFrame:SetWidth(AuxItemSearchFrameItem:GetWidth() + AuxItemSearchFrameAuctions:GetWidth() + 15)
end

function private.update_recently_searched()
    Aux.sheet.populate(private.listings.recently_searched, aux_recently_searched)
end

function public.set_item(item_id)
    if item_id ~= private.item_id and Aux.static.item_info(item_id) then
        AuxItemSearchFrameItemRefreshButton:Enable()
        private.item_id = item_id
        public.update_item()

        local updated_recently_searched = Aux.util.filter(aux_recently_searched, function(item_entry)
            return item_entry.item_id ~= item_id
        end)
        tinsert(updated_recently_searched, 1, { item_id=item_id, time=time() })
        while getn(updated_recently_searched) > 50 do
            tremove(updated_recently_searched)
        end
        aux_recently_searched = updated_recently_searched

        private.update_recently_searched()
        public.start_search()
    elseif not private.item_id then
        AuxItemSearchFrameItemItemInputBox:Show()
    end
end

function public.item_set()
    return private.item_id ~= nil
end

function public.update_item()
    if private.item_id and not AuxItemSearchFrameItemItemInputBox:IsVisible() then
        local info = Aux.static.item_info(private.item_id)
        AuxItemSearchFrameItemItemIconTexture:SetTexture(info.texture)
        AuxItemSearchFrameItemItemName:SetText(info.name)
        local color = ITEM_QUALITY_COLORS[info.quality]
        AuxItemSearchFrameItemItemName:SetTextColor(color.r, color.g, color.b)
        AuxItemSearchFrameItemItem:Show()
    else
        AuxItemSearchFrameItemItem:Hide()
    end
end

function public.start_search()

    Aux.scan.abort(function()

        private.clear_selection()

        private.status_bar:update_status(0,0)
        private.status_bar:set_text('Scanning auctions...')

        AuxItemSearchFrameItemRefreshButton:Hide()
        AuxItemSearchFrameItemStopButton:Show()

        auctions = nil
        refresh = true

        local item_id = private.item_id

        local query = Aux.scan_util.create_item_query(item_id)

        Aux.scan.start{
            queries = { query },
            on_page_loaded = function(page, total_pages)
                private.status_bar:update_status(100 * (page + 1) / total_pages, 100 * (page + 1) / total_pages) -- TODO
                private.status_bar:set_text(format('Scanning (Page %d / %d)', page + 1, total_pages))
            end,
            on_page_complete = function()
                refresh = true
            end,
            on_read_auction = function(auction_info)
                auctions = auctions or {}
                tinsert(auctions, private.create_auction_record(auction_info))
            end,
            on_complete = function()
                auctions = auctions or {}
                private.status_bar:update_status(100, 100)
                private.status_bar:set_text('Done Scanning')

                AuxItemSearchFrameItemStopButton:Hide()
                AuxItemSearchFrameItemRefreshButton:Show()
                refresh = true
            end,
            on_abort = function()
                auctions = auctions or {}
                private.status_bar:update_status(100, 100)
                private.status_bar:set_text('Done Scanning')

                AuxItemSearchFrameItemStopButton:Hide()
                AuxItemSearchFrameItemRefreshButton:Show()
                refresh = true
            end,
        }
    end)
end

function private.process_request(entry, express_mode, buyout_mode)

    if entry.gone or (buyout_mode and not entry.buyout_price) or (express_mode and not buyout_mode and entry.high_bidder) or entry.owner == UnitName('player') then
        return
    end

    PlaySound('igMainMenuOptionCheckBoxOn')

    local function test(index)
        local auction_record = private.create_auction_record(Aux.info.auction(index))
        return auction_record.signature == entry.signature and auction_record.bid_price == entry.bid_price and auction_record.duration == entry.duration and auction_record.owner ~= UnitName('player')
    end

    local function remove_entry()
        entry.gone = true
        refresh = true
        private.clear_selection()
    end

    if express_mode then
        Aux.scan_util.find(test, entry.query, entry.page, private.status_bar, remove_entry, function(index)
            if not entry.gone then
                Aux.place_bid('list', index, buyout_mode and entry.buyout_price or entry.bid_price, remove_entry)
            end
        end)
    else
        private.select_auction(entry)

        Aux.scan_util.find(test, entry.query, entry.page, private.status_bar, remove_entry, function(index)

            if not entry.high_bidder then
                private.bid_button:SetScript('OnClick', function()
                    if test(index) and not entry.gone then
                        Aux.place_bid('list', index, entry.bid_price, remove_entry)
                    end
                    private.clear_selection()
                end)
                private.bid_button:Enable()
            end

            if entry.buyout_price then
                private.buyout_button:SetScript('OnClick', function()
                    if test(index) and not entry.gone then
                        Aux.place_bid('list', index, entry.buyout_price, remove_entry)
                    end
                    private.clear_selection()
                end)
                private.buyout_button:Enable()
            end
        end)
    end
end

function private.on_row_click(datum, grouped)

    local entry
    if grouped then
        entry = Aux.util.filter(datum, function(auction) return not auction.gone end)[1] or datum[1]
    else
        entry = datum
    end

    if IsControlKeyDown() then
        DressUpItemLink(entry.hyperlink)
    elseif IsShiftKeyDown() then
        if ChatFrameEditBox:IsVisible() then
            ChatFrameEditBox:Insert(entry.hyperlink)
        end
    else
        local express_mode = IsAltKeyDown()
        local buyout_mode = express_mode and arg1 == 'LeftButton'
        private.process_request(entry, express_mode, buyout_mode)
    end
end

function private.create_auction_record(auction_info)

	local buyout_price = auction_info.buyout_price > 0 and auction_info.buyout_price or nil
	local unit_buyout_price = buyout_price and Aux.round(auction_info.buyout_price / auction_info.aux_quantity)
    local status
    if auction_info.current_bid == 0 then
        status = 'No Bid'
    elseif auction_info.high_bidder then
        status = GREEN_FONT_COLOR_CODE..'Your Bid'..FONT_COLOR_CODE_CLOSE
    else
        status = 'Other Bidder'
    end

    return {
        query = auction_info.query,
        page = auction_info.page,

        item_id = auction_info.item_id,
        suffix_id = auction_info.suffix_id,
        unique_id = auction_info.unique_id,
        enchant_id = auction_info.enchant_id,

        item_key = auction_info.item_key,
        signature = auction_info.signature,

        name = auction_info.name,
        level = auction_info.level,
        aux_quantity = auction_info.aux_quantity,
        buyout_price = buyout_price,
        unit_buyout_price = unit_buyout_price,
        quality = auction_info.quality,
        hyperlink = auction_info.hyperlink,
        bid_price = auction_info.bid_price,
        unit_bid_price = Aux.round(auction_info.bid_price / auction_info.aux_quantity),
        owner = auction_info.owner,
        duration = auction_info.duration,
        usable = auction_info.usable,
        high_bidder = auction_info.high_bidder,
        status = status,

        EnhTooltip_info = auction_info.EnhTooltip_info,
    }
end

function public.on_update()
	if refresh then
		refresh = false
		private.update_listing()
	end
end