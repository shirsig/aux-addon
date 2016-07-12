function Aux.bids_frame.create_frames(private, public)
    private.listing = Aux.auction_listing.CreateAuctionResultsTable(AuxBidsFrameListing, Aux.auction_listing.bids_config)
    private.listing:SetSort(1,2,3,4,5,6,7,8)
    private.listing:Reset()
    private.listing:SetHandler('OnCellClick', function(cell, button)
        if IsAltKeyDown() and private.listing:GetSelection().record == cell.row.data.record then
            if button == 'LeftButton' and private.buyout_button:IsEnabled() then
                private.buyout_button:Click()
            elseif button == 'RightButton' and private.bid_button:IsEnabled() then
                private.bid_button:Click()
            end
        end
    end)
    private.listing:SetHandler('OnSelectionChanged', function(rt, datum)
        if not datum then return end
        private.find_auction(datum.record)
    end)

    do
        local status_bar = Aux.gui.status_bar(AuxBidsFrame)
        status_bar:SetWidth(265)
        status_bar:SetHeight(25)
        status_bar:SetPoint('TOPLEFT', AuxFrameContent, 'BOTTOMLEFT', 0, -6)
        status_bar:update_status(100, 0)
        status_bar:set_text('')
        private.status_bar = status_bar
    end
    do
        local btn = Aux.gui.button(AuxBidsFrame, 16)
        btn:SetPoint('TOPLEFT', private.status_bar, 'TOPRIGHT', 5, 0)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Bid')
        btn:Disable()
        private.bid_button = btn
    end
    do
        local btn = Aux.gui.button(AuxBidsFrame, 16)
        btn:SetPoint('TOPLEFT', private.bid_button, 'TOPRIGHT', 5, 0)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Buyout')
        btn:Disable()
        private.buyout_button = btn
    end
    do
        local btn = Aux.gui.button(AuxBidsFrame, 16)
        btn:SetPoint('TOPLEFT', private.buyout_button, 'TOPRIGHT', 5, 0)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Refresh')
        btn:SetScript('OnClick', function()
            public.scan_bids()
        end)
    end
end