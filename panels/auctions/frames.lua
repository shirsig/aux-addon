Aux.auctions_frame.FRAMES(function(m, private, public)
    private.listing = Aux.auction_listing.CreateAuctionResultsTable(AuxAuctionsFrameListing, Aux.auction_listing.auctions_config)
    m.listing:SetSort(1,2,3,4,5,6,7,8)
    m.listing:Reset()
    m.listing:SetHandler('OnCellClick', function(cell, button)
        if IsAltKeyDown() and m.listing:GetSelection().record == cell.row.data.record and m.cancel_button:IsEnabled() then
            m.cancel_button:Click()
        end
    end)
    m.listing:SetHandler('OnSelectionChanged', function(rt, datum)
        if not datum then return end
        m.find_auction(datum.record)
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
        btn:SetPoint('TOPLEFT', m.status_bar, 'TOPRIGHT', 5, 0)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Cancel')
        btn:Disable()
        private.cancel_button = btn
    end
    do
        local btn = Aux.gui.button(AuxAuctionsFrame, 16)
        btn:SetPoint('TOPLEFT', m.cancel_button, 'TOPRIGHT', 5, 0)
        btn:SetWidth(80)
        btn:SetHeight(24)
        btn:SetText('Refresh')
        btn:SetScript('OnClick', function()
            m.scan_auctions()
        end)
    end
end)