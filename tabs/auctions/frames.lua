aux.module 'auctions_tab'

function create_frames()
	frame = CreateFrame('Frame', nil, aux.frame)
	m.frame:SetAllPoints()
	m.frame:SetScript('OnUpdate', m.on_update)
	m.frame:Hide()

	m.frame.listing = aux.gui.panel(m.frame)
	m.frame.listing:SetPoint('TOP', aux.frame, 'TOP', 0, -8)
	m.frame.listing:SetPoint('BOTTOMLEFT', aux.frame.content, 'BOTTOMLEFT', 0, 0)
	m.frame.listing:SetPoint('BOTTOMRIGHT', aux.frame.content, 'BOTTOMRIGHT', 0, 0)

	listing = aux.auction_listing.CreateAuctionResultsTable(m.frame.listing, aux.auction_listing.auctions_config)
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
	    local status_bar = aux.gui.status_bar(m.frame)
	    status_bar:SetWidth(265)
	    status_bar:SetHeight(25)
	    status_bar:SetPoint('TOPLEFT', aux.frame.content, 'BOTTOMLEFT', 0, -6)
	    status_bar:update_status(100, 100)
	    status_bar:set_text('')
	    status_bar = status_bar
	end
	do
	    local btn = aux.gui.button(m.frame, 16)
	    btn:SetPoint('TOPLEFT', m.status_bar, 'TOPRIGHT', 5, 0)
	    btn:SetWidth(80)
	    btn:SetHeight(24)
	    btn:SetText('Cancel')
	    btn:Disable()
	    cancel_button = btn
	end
	do
	    local btn = aux.gui.button(m.frame, 16)
	    btn:SetPoint('TOPLEFT', m.cancel_button, 'TOPRIGHT', 5, 0)
	    btn:SetWidth(80)
	    btn:SetHeight(24)
	    btn:SetText('Refresh')
	    btn:SetScript('OnClick', function()
	        m.scan_auctions()
	    end)
	end
end