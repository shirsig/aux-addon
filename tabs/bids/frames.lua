aux.module 'bids_tab'

function create_frames()
	frame = CreateFrame('Frame', nil, aux.frame)
	frame:SetAllPoints()
	frame:SetScript('OnUpdate', on_update)
	frame:Hide()

	frame.listing = aux.gui.panel(frame)
	frame.listing:SetPoint('TOP', aux.frame, 'TOP', 0, -8)
	frame.listing:SetPoint('BOTTOMLEFT', aux.frame.content, 'BOTTOMLEFT', 0, 0)
	frame.listing:SetPoint('BOTTOMRIGHT', aux.frame.content, 'BOTTOMRIGHT', 0, 0)

	listing = aux.auction_listing.CreateAuctionResultsTable(frame.listing, aux.auction_listing.bids_config)
	listing:SetSort(1,2,3,4,5,6,7,8)
	listing:Reset()
	listing:SetHandler('OnCellClick', function(cell, button)
	    if IsAltKeyDown() and listing:GetSelection().record == cell.row.data.record then
	        if button == 'LeftButton' and buyout_button:IsEnabled() then
	            buyout_button:Click()
	        elseif button == 'RightButton' and bid_button:IsEnabled() then
	            bid_button:Click()
	        end
	    end
	end)
	listing:SetHandler('OnSelectionChanged', function(rt, datum)
	    if not datum then return end
	    find_auction(datum.record)
	end)

	do
	    status_bar = aux.gui.status_bar(frame)
	    status_bar:SetWidth(265)
	    status_bar:SetHeight(25)
	    status_bar:SetPoint('TOPLEFT', aux.frame.content, 'BOTTOMLEFT', 0, -6)
	    status_bar:update_status(100, 0)
	    status_bar:set_text('')
	end
	do
	    local btn = aux.gui.button(frame, 16)
	    btn:SetPoint('TOPLEFT', status_bar, 'TOPRIGHT', 5, 0)
	    btn:SetWidth(80)
	    btn:SetHeight(24)
	    btn:SetText('Bid')
	    btn:Disable()
	    bid_button = btn
	end
	do
	    local btn = aux.gui.button(frame, 16)
	    btn:SetPoint('TOPLEFT', bid_button, 'TOPRIGHT', 5, 0)
	    btn:SetWidth(80)
	    btn:SetHeight(24)
	    btn:SetText('Buyout')
	    btn:Disable()
	    buyout_button = btn
	end
	do
	    local btn = aux.gui.button(frame, 16)
	    btn:SetPoint('TOPLEFT', buyout_button, 'TOPRIGHT', 5, 0)
	    btn:SetWidth(80)
	    btn:SetHeight(24)
	    btn:SetText('Refresh')
	    btn:SetScript('OnClick', function()
	        scan_bids()
	    end)
	end
end