function Aux.auctions_frame.create_frames(private, public)
    private.listing = Aux.auction_listing.CreateAuctionResultsTable(AuxAuctionsFrameListing, Aux.auction_listing.auctions_config)
    private.listing:SetSort(1,2,3,4,5,6,7,8)
    private.listing:Reset()
    private.listing:SetHandler('OnCellClick', function(cell, button)
        if IsAltKeyDown() and private.listing:GetSelection().record == cell.row.data.record and private.cancel_button:IsEnabled() then
            private.cancel_button:Click()
        end
    end)
    private.listing:SetHandler('OnSelectionChanged', function(rt, datum)
        if not datum then return end
        private.find_auction(datum.record)
    end)

    do
        local status_bar = Aux.gui.status_bar(AuxAuctionsFrame)
        status_bar:SetWidth(265)
        status_bar:SetHeight(25)
        status_bar:SetPoint('TOPLEFT', AuxFrameContent, 'BOTTOMLEFT', 0, -6)
        status_bar:update_status(100, 100)
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