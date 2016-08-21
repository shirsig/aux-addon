aux.module 'auctions_tab'

function create_frames()
	frame = CreateFrame('Frame', nil, frame)
	frame:SetAllPoints()
	frame:SetScript('OnUpdate', on_update)
	frame:Hide()

	frame.listing = gui.panel(frame)
	frame.listing:SetPoint('TOP', frame, 'TOP', 0, -8)
	frame.listing:SetPoint('BOTTOMLEFT', frame.content, 'BOTTOMLEFT', 0, 0)
	frame.listing:SetPoint('BOTTOMRIGHT', frame.content, 'BOTTOMRIGHT', 0, 0)

	listing = auction_listing.CreateAuctionResultsTable(frame.listing, auction_listing.auctions_config)
	listing:SetSort(1,2,3,4,5,6,7,8)
	listing:Reset()
	listing:SetHandler('OnCellClick', function(cell, button)
	    if IsAltKeyDown() and listing:GetSelection().record == cell.row.data.record and cancel_button:IsEnabled() then
	        cancel_button:Click()
	    end
	end)
	listing:SetHandler('OnSelectionChanged', function(rt, datum)
	    if not datum then return end
	    find_auction(datum.record)
	end)

	do
	    status_bar = gui.status_bar(frame)
	    status_bar:SetWidth(265)
	    status_bar:SetHeight(25)
	    status_bar:SetPoint('TOPLEFT', frame.content, 'BOTTOMLEFT', 0, -6)
	    status_bar:update_status(100, 100)
	    status_bar:set_text('')
	end
	do
	    local btn = gui.button(frame, 16)
	    btn:SetPoint('TOPLEFT', m.status_bar, 'TOPRIGHT', 5, 0)
	    btn:SetWidth(80)
	    btn:SetHeight(24)
	    btn:SetText('Cancel')
	    btn:Disable()
	    cancel_button = btn
	end
	do
	    local btn = gui.button(m.frame, 16)
	    btn:SetPoint('TOPLEFT', m.cancel_button, 'TOPRIGHT', 5, 0)
	    btn:SetWidth(80)
	    btn:SetHeight(24)
	    btn:SetText('Refresh')
	    btn:SetScript('OnClick', function()
	        m.scan_auctions()
	    end)
	end
end