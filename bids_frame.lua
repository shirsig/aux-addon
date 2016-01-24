local private, public = {}, {}
Aux.bids_frame = public

local bid_records

public.bid_listing_config = {
    on_row_click = function(sheet, row_index, column_index)
        local data_index = row_index + FauxScrollFrame_GetOffset(sheet.scroll_frame)
        public.on_bid_click(sheet.data[data_index])
    end,

    on_row_enter = function(sheet, row_index, column_index)
        sheet.rows[row_index].highlight:SetAlpha(.5)
    end,

    on_row_leave = function(sheet, row_index, column_index)
        sheet.rows[row_index].highlight:SetAlpha(0)
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

    columns = {
        {
            title = 'Auction Item',
            width = 280,
            comparator = function(row1, row2) return Aux.util.compare(row1.tooltip[1][1].text, row2.tooltip[1][1].text, Aux.util.GT) end,
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
                private.auction_alpha_setter(cell, datum)
            end,
        },
        {
            title = 'Qty',
            width = 25,
            comparator = function(row1, row2) return Aux.util.compare(row1.stack_size, row2.stack_size, Aux.util.LT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, datum)
                cell.text:SetText(datum.aux_quantity)
                private.auction_alpha_setter(cell, datum)
            end,
        },
        {
            title = 'Status',
            width = 70,
            comparator = function(auction1, auction2) return Aux.util.compare(auction1.status, auction2.status, Aux.util.GT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('CENTER'),
            cell_setter = function(cell, auction)
                cell.text:SetText(auction.status)
                private.auction_alpha_setter(cell, auction)
            end,
        },
        {
            title = 'Left',
            width = 30,
            comparator = function(row1, row2) return Aux.util.compare(row1.duration, row2.duration, Aux.util.GT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('CENTER'),
            cell_setter = function(cell, datum)
                local text
                if datum.duration == 1 then
                    text = '30m'
                elseif datum.duration == 2 then
                    text = '2h'
                elseif datum.duration == 3 then
                    text = '8h'
                elseif datum.duration == 4 then
                    text = '24h'
                end
                cell.text:SetText(text)
                private.auction_alpha_setter(cell, datum)
            end,
        },
        {
            title = 'Owner',
            width = 90,
            comparator = function(row1, row2) return Aux.util.compare(row1.owner, row2.owner, Aux.util.GT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('LEFT'),
            cell_setter = function(cell, datum)
                cell.text:SetText(datum.owner)
                private.auction_alpha_setter(cell, datum)
            end,
        },
        {
            title = 'Your Bid',
            width = 90,
            comparator = function(auction1, auction2) return Aux.util.compare(auction1.current_bid, auction2.current_bid, Aux.util.GT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('CENTER'),
            cell_setter = function(cell, auction)
                cell.text:SetText(Aux.util.money_string(auction.current_bid))
                private.auction_alpha_setter(cell, auction)
            end,
        },
        {
            title = 'Buy',
            width = 90,
            comparator = function(row1, row2) return Aux.util.compare(row1.buyout_price, row2.buyout_price, Aux.util.GT) end,
            cell_initializer = Aux.sheet.default_cell_initializer('RIGHT'),
            cell_setter = function(cell, datum)
                cell.text:SetText(Aux.util.money_string(datum.buyout_price))
                private.auction_alpha_setter(cell, datum)
            end,
        },
    },
    sort_order = {{ column = 1, order = 'ascending' }},
}

function public.on_open()
    public.update_bid_records()
    public.update_listing()
end

function public.on_close()
end

function private.auction_alpha_setter(cell, auction)
    cell:SetAlpha(auction.gone and 0.3 or 1)
end

function public.update_bid_records()
    Aux.log('Scanning bids ...')
    bid_records = {}
    Aux.scan.start{
        type = 'bidder',
        page = 0,
        on_page_loaded = function(page, total_pages)
			Aux.log('Scanning bid page '..(page+1)..' out of '..total_pages..' ...')
        end,
        on_read_auction = function(auction_info)
            private.create_bid_record(auction_info)
        end,
        on_complete = function()
            Aux.log('Scan complete: '..getn(bid_records)..' '..Aux_PluralizeIf('bid', getn(bid_records))..' found.')
            public.update_listing()
        end,
        on_abort = function()
        end,
        next_page = function(page, total_pages)
            local last_page = max(total_pages - 1, 0)
            if page < last_page then
                return page + 1
            end
        end,
    }
end

function public.update_listing()
    AuxBidsFrameListingBidListing:Show()
    Aux.sheet.populate(AuxBidsFrameListingBidListing.sheet, bid_records)
    AuxBidsFrameListing:SetWidth(AuxBidsFrameListingBidListing:GetWidth() + 40)
    AuxFrame:SetWidth(AuxBidsFrameListing:GetWidth() + 15)
end

function private.create_record(auction_info)

    local aux_quantity = auction_info.charges or auction_info.count
    local bid = (auction_info.current_bid > 0 and auction_info.current_bid or auction_info.min_bid) + auction_info.min_increment
    local buyout_price = auction_info.buyout_price > 0 and auction_info.buyout_price or nil
    local buyout_price_per_unit = buyout_price and Aux.round(auction_info.buyout_price / aux_quantity)

    local status
    if auction_info.high_bidder then
        status = GREEN_FONT_COLOR_CODE..'High Bidder'..FONT_COLOR_CODE_CLOSE
    else
        status = RED_FONT_COLOR_CODE..'Outbid'..FONT_COLOR_CODE_CLOSE
    end

    return {
        item_id = auction_info.item_id,
        key = auction_info.item_signature,
        signature = Aux.auction_signature(auction_info.hyperlink, aux_quantity, bid, auction_info.buyout_price),

        name = auction_info.name,
        tooltip = auction_info.tooltip,
        aux_quantity = aux_quantity,
        buyout_price = buyout_price,
        buyout_price_per_unit = buyout_price_per_unit,
        quality = auction_info.quality,
        hyperlink = auction_info.hyperlink,
        itemstring = auction_info.itemstring,
        bid = bid,
        owner = auction_info.owner,
        duration = auction_info.duration,
        usable = auction_info.usable,
        high_bidder = auction_info.high_bidder,
        current_bid = auction_info.current_bid > 0 and auction_info.current_bid or nil,
        status = status,

        EnhTooltip_info = auction_info.EnhTooltip_info,
    }
end

function private.create_bid_record(auction_info)
    tinsert(bid_records, private.create_record(auction_info))
end

function public.dialog_cancel()
    Aux.scan.abort()
    AuxBidsFrameListingDialog:Hide()
    public.update_listing()
end

function private.find_auction(entry, action, express_mode)

    if entry.gone then
        Aux.log('Auction not available.')
        return
    end

    if action == 'buyout' and not entry.buyout_price then
        Aux.log('Auction has no buyout price.')
        return
    end

    local amount
    if action == 'buyout' then
        amount = entry.buyout_price
    elseif action == 'bid' then
        amount = entry.bid
    end

    Aux.log('Searching auction ...')

    if not express_mode then
        private.show_dialog(action, entry, amount)
    end

    PlaySound('igMainMenuOptionCheckBoxOn')

    local found

    Aux.scan.start{
        type = 'bidder',
        page = entry.page,
        on_read_auction = function(auction_info, ctrl)

            local auction_record = private.create_record(auction_info)

            if entry.signature == auction_record.signature then
                ctrl.suspend()
                found = true
                Aux.log('Matching auction found.')

                if express_mode then
                    if GetMoney() >= amount then
                        Aux.place_bid('bidder', auction_info.index, amount)
                        Aux.log((action == 'buyout' and 'Purchased ' or 'Bid on ')..auction_record.hyperlink..' ('..auction_record.aux_quantity..').')
                        entry.gone = true
                    else
                        Aux.log((action == 'buyout' and 'Purchase' or 'Bid')..' failed: Not enough money.')
                    end
                    Aux.scan.abort()
                else
                    public.dialog_action = function()
                        if private.create_record(Aux.info.auction(auction_info.index, 'bidder')).signature == entry.signature then
                            if GetMoney() >= amount then
                                Aux.place_bid('bidder', auction_info.index, action == 'bid' and MoneyInputFrame_GetCopper(AuxBidsFrameListingDialogContentBid) or amount)
                                Aux.log((action == 'buyout' and 'Purchased ' or 'Bid on ')..auction_record.hyperlink..' ('..auction_record.aux_quantity..').')
                                entry.gone = true
                            else
                                Aux.log('Not enough money.')
                            end
                            Aux.scan.abort()
                            AuxBidsFrameListingDialog:Hide()
                            public.update_listing()
                        end
                    end
                    AuxBidsFrameListingDialogContentActionButton:Enable()
                end
            end
        end,
        on_complete = function()
            if not found then
                Aux.log('No matching auction found. Removing entry from the cache.')
                entry.gone = true
                public.dialog_cancel()
            end
        end,
        on_abort = function()
            public.update_listing()
        end,
        next_page = function(page, total_pages)
            if not page or page == entry.page then
                return entry.page - 1
            end
        end,
    }
end

function public.on_bid_click(bid_record)

    local express_mode = IsAltKeyDown()
    local action = arg1 == 'LeftButton' and 'buyout' or 'bid'

    if IsControlKeyDown() then
        DressUpItemLink(bid_record.hyperlink)
    else
        private.find_auction(bid_record, action, express_mode)
    end
end

function private.show_dialog(action, entry, amount)
    AuxBidsFrameListingDialogContentItem.itemstring = Aux.info.itemstring(entry.item_id, entry.suffix_id, entry.unique_id, entry.enchant_id)
    AuxBidsFrameListingDialogContentItem.EnhTooltip_info = entry.EnhTooltip_info

    AuxBidsFrameListingDialogContentActionButton:Disable()
    AuxBidsFrameListingDialogContentItemIconTexture:SetTexture(Aux.info.item(entry.item_id).texture)
    AuxBidsFrameListingDialogContentItemName:SetText(entry.name)
    local color = ITEM_QUALITY_COLORS[entry.quality]
    AuxBidsFrameListingDialogContentItemName:SetTextColor(color.r, color.g, color.b)

    if entry.aux_quantity > 1 then
        AuxBidsFrameListingDialogContentItemCount:SetText(entry.aux_quantity);
        AuxBidsFrameListingDialogContentItemCount:Show()
    else
        AuxBidsFrameListingDialogContentItemCount:Hide()
    end

    if action == 'buyout' then
        AuxBidsFrameListingDialogContentActionButton:SetText('Buy')
        AuxBidsFrameListingDialogContentCancelButton:SetText('Cancel')
        MoneyFrame_Update('AuxBidsFrameListingDialogContentBuyoutPrice', amount)
        AuxBidsFrameListingDialogContentBid:Hide()
        AuxBidsFrameListingDialogContentBuyoutPrice:Show()
    elseif action == 'bid' then
        AuxBidsFrameListingDialogContentActionButton:SetText('Bid')
        AuxBidsFrameListingDialogContentCancelButton:SetText('Cancel')
        MoneyInputFrame_SetCopper(AuxBidsFrameListingDialogContentBid, amount)
        AuxBidsFrameListingDialogContentBuyoutPrice:Hide()
        AuxBidsFrameListingDialogContentBid:Show()
    end
    AuxBidsFrameListingDialog:Show()
end


