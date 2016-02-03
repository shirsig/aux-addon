local private, public = {}, {}
Aux.auctions_frame = public

local refresh
local auction_records
local selected_auction

function private.select_auction(entry)
    selected_auction = entry
    refresh = true
    private.cancel_button:Disable()
end

function private.clear_selection(entry)
    selected_auction = nil
    refresh = true
    private.cancel_button:Disable()
end

function public.on_load()
    private.auction_listing_config = {
        frame = AuxAuctionsFrameListingAuctionListing,
        on_row_click = function(sheet, row_index)
            local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
            private.on_row_click(sheet.data[data_index])
        end,
        on_row_enter = function(sheet, row_index)
            Aux.info.set_tooltip(sheet.rows[row_index].itemstring, sheet.rows[row_index].EnhTooltip_info, this, 'ANCHOR_RIGHT', 0, 0)
        end,
        on_row_leave = function(sheet, row_index)
            GameTooltip:Hide()
            ResetCursor()
        end,
        on_row_update = function(sheet, row_index)
            if IsControlKeyDown() then
                ShowInspectCursor()
            else
                ResetCursor()
            end
        end,
        selected = function(datum)
            return datum == selected_auction
        end,
        row_setter = function(row, datum)
            row:SetAlpha(datum.gone and 0.3 or 1)
            row.itemstring = Aux.info.itemstring(datum.item_id, datum.suffix_id, nil, datum.enchant_id)
            row.EnhTooltip_info = datum.EnhTooltip_info
        end,
        columns = {
            {
                title = 'Auction Item',
                width = 280,
                comparator = function(row1, row2) return Aux.sort.compare(row1.tooltip[1][1].text, row2.tooltip[1][1].text, Aux.sort.GT) end,
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
                    text:SetPoint("LEFT", icon, "RIGHT", 1, 0)
                    text:SetPoint('TOPRIGHT', cell)
                    text:SetPoint('BOTTOMRIGHT', cell)
                    text:SetJustifyV('TOP')
                    text:SetJustifyH('LEFT')
                    text:SetTextColor(0.8, 0.8, 0.8)
                    cell.text = text
                    cell.icon = icon
                end,
                cell_setter = function(cell, datum)
                    cell.icon.icon_texture:SetTexture(Aux.info.item(datum.item_id).texture)
                    if not datum.usable then
                        cell.icon.icon_texture:SetVertexColor(1.0, 0.1, 0.1)
                    else
                        cell.icon.icon_texture:SetVertexColor(1.0, 1.0, 1.0)
                    end
                    cell.text:SetText('['..datum.tooltip[1][1].text..']')
                    local color = ITEM_QUALITY_COLORS[datum.quality]
                    cell.text:SetTextColor(color.r, color.g, color.b)
                end,
            },
            {
                title = 'Qty',
                width = 25,
                comparator = function(row1, row2) return Aux.sort.compare(row1.stack_size, row2.stack_size, Aux.sort.LT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
                cell_setter = function(cell, datum)
                    cell.text:SetText(datum.aux_quantity)
                end,
            },
            Aux.listing_util.duration_column(function(entry) return entry.duration end),
            {
                title = 'Current Bid',
                width = 80,
                comparator = function(auction1, auction2) return Aux.sort.compare(auction1.high_bid, auction2.high_bid, Aux.sort.GT) end,
                cell_initializer = Aux.sheet.default_cell_initializer('CENTER'),
                cell_setter = function(cell, auction)
                    cell.text:SetText(auction.high_bid and Aux.util.money_string(auction.high_bid) or RED_FONT_COLOR_CODE..'No Bids'..FONT_COLOR_CODE_CLOSE)
                end,
            },
            Aux.listing_util.money_column('Min Bid', function(entry) return entry.start_price end),
            Aux.listing_util.money_column('Buy', function(entry) return entry.buyout_price end),
        },
        sort_order = {{ column = 1, order = 'ascending' }},
    }

    private.listing =  Aux.sheet.create(private.auction_listing_config)
    do
        local status_bar = Aux.gui.status_bar(AuxAuctionsFrame)
        status_bar:SetWidth(265)
        status_bar:SetHeight(25)
        status_bar:SetPoint('TOPLEFT', AuxFrameContent, 'BOTTOMLEFT', 0, -6)
        status_bar:update_status(100, 0)
        status_bar:set_text('')
        private.status_bar = status_bar
    end
    do
        local btn = Aux.gui.button(AuxAuctionsFrame, 16)
        btn:SetPoint('TOPLEFT', private.status_bar, 'TOPRIGHT', 5, 0)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Cancel')
        btn:Disable()
        private.cancel_button = btn
    end
    do
        local btn = Aux.gui.button(AuxAuctionsFrame, 16)
        btn:SetPoint('TOPLEFT', private.cancel_button, 'TOPRIGHT', 5, 0)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Refresh')
        btn:SetScript('OnClick', function()
            public.scan_auctions()
        end)
    end
end

function public.on_open()
    public.scan_auctions()
    refresh = true
end

function public.on_close()
    private.clear_selection()
end

function public.scan_auctions()

    private.status_bar:update_status(0,0)
    private.status_bar:set_text('Scanning auctions...')

    auction_records = {}
    Aux.scan.start{
        queries = {
            {
                type = 'owner',
                start_page = 0,
            }
        },
        on_page_loaded = function(page, total_pages)
            private.status_bar:update_status(100 * (page + 1) / total_pages, 100 * (page + 1) / total_pages)
            private.status_bar:set_text(format('Scanning (Page %d / %d)', page + 1, total_pages))
        end,
        on_read_auction = function(auction_info)
            tinsert(auction_records, private.create_auction_record(auction_info))
        end,
        on_complete = function()
            private.status_bar:update_status(100, 100)
            private.status_bar:set_text('Done Scanning')
            refresh = true
        end,
        on_abort = function()
            private.status_bar:update_status(100, 100)
            private.status_bar:set_text('Done Scanning')
        end,
    }
end

function private.update_listing()
    if not AuxAuctionsFrame:IsVisible() then
        return
    end

    AuxAuctionsFrameListingAuctionListing:Show()
    Aux.sheet.populate(private.listing, auction_records)
    AuxAuctionsFrameListing:SetWidth(AuxAuctionsFrameListingAuctionListing:GetWidth() + 40)
end

function private.create_auction_record(auction_info)

    local buyout_price = auction_info.buyout_price > 0 and auction_info.buyout_price or nil

    local status
    if auction_info.high_bidder then
        status = GREEN_FONT_COLOR_CODE..'High Bidder'..FONT_COLOR_CODE_CLOSE
    else
        status = RED_FONT_COLOR_CODE..'Outbid'..FONT_COLOR_CODE_CLOSE
    end

    return {
        query = auction_info.query,
        page = auction_info.page,

        item_id = auction_info.item_id,
        item_key = auction_info.item_key,
        signature = auction_info.signature,

        name = auction_info.name,
        tooltip = auction_info.tooltip,
        aux_quantity = auction_info.aux_quantity,
        buyout_price = buyout_price,
        quality = auction_info.quality,
        hyperlink = auction_info.hyperlink,
        itemstring = auction_info.itemstring,
        duration = auction_info.duration,
        usable = auction_info.usable,
        high_bidder = auction_info.high_bidder,
        high_bid = auction_info.high_bid > 0 and auction_info.high_bid or nil,
        start_price = auction_info.start_price,
        status = status,

        EnhTooltip_info = auction_info.EnhTooltip_info,
    }
end

function private.process_request(entry, express_mode)

    if entry.gone then
        return
    end

    PlaySound('igMainMenuOptionCheckBoxOn')

    local function test(index)
        local auction_record = private.create_auction_record(Aux.info.auction(index, 'owner'))
        return auction_record.signature == entry.signature and auction_record.bid_price == entry.bid_price and auction_record.duration == entry.duration
    end

    local function remove_entry()
        entry.gone = true
        refresh = true
        private.clear_selection()
    end

    if express_mode then
        Aux.scan_util.find(test, entry.query, entry.page, private.status_bar, remove_entry, function(index)
            if not entry.gone then
                CancelAuction(index)
                remove_entry()
            end
        end)
    else
        private.select_auction(entry)

        Aux.scan_util.find(test, entry.query, entry.page, private.status_bar, remove_entry, function(index)

            private.cancel_button:SetScript('OnClick', function()
                if test(index) and not entry.gone then
                    CancelAuction(index)
                    remove_entry()
                else
                    private.clear_selection()
                end
            end)
            private.cancel_button:Enable()
        end)
    end
end

function private.on_row_click(datum)

    if IsControlKeyDown() then
        DressUpItemLink(datum.hyperlink)
    elseif IsShiftKeyDown() then
        if ChatFrameEditBox:IsVisible() then
            ChatFrameEditBox:Insert(datum.hyperlink)
        end
    else
        local express_mode = IsAltKeyDown()
        private.process_request(datum, express_mode)
    end
end

function public.on_update()
    if refresh then
        refresh = false
        private.update_listing()
    end
end


