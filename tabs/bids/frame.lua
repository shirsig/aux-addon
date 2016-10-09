module'aux.bids_tab.frame'

local gui = require 'aux.gui'
local auction_listing = require 'aux.gui.auction_listing'

function public.create()
	setfenv(1, getfenv(2))
	private.frame = CreateFrame('Frame', nil, AuxFrame)
	frame:SetAllPoints()
	frame:SetScript('OnUpdate', on_update)
	frame:Hide()

	frame.listing = gui.panel(frame)
	frame.listing:SetPoint('TOP', frame, 'TOP', 0, -8)
	frame.listing:SetPoint('BOTTOMLEFT', AuxFrame.content, 'BOTTOMLEFT', 0, 0)
	frame.listing:SetPoint('BOTTOMRIGHT', AuxFrame.content, 'BOTTOMRIGHT', 0, 0)

	private.listing = auction_listing.CreateAuctionResultsTable(frame.listing, auction_listing.bids_config)
	listing:SetSort(1, 2, 3, 4, 5, 6, 7, 8)
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
		private.status_bar = gui.status_bar(frame)
	    status_bar:SetWidth(265)
	    status_bar:SetHeight(25)
	    status_bar:SetPoint('TOPLEFT', AuxFrame.content, 'BOTTOMLEFT', 0, -6)
	    status_bar:update_status(100, 0)
	    status_bar:set_text('')
	end
	do
	    local btn = gui.button(frame)
	    btn:SetPoint('TOPLEFT', status_bar, 'TOPRIGHT', 5, 0)
	    btn:SetText'Bid'
	    btn:Disable()
	    private.bid_button = btn
	end
	do
	    local btn = gui.button(frame)
	    btn:SetPoint('TOPLEFT', bid_button, 'TOPRIGHT', 5, 0)
	    btn:SetText'Buyout'
	    btn:Disable()
	    private.buyout_button = btn
	end
	do
	    local btn = gui.button(frame)
	    btn:SetPoint('TOPLEFT', buyout_button, 'TOPRIGHT', 5, 0)
	    btn:SetText'Refresh'
	    btn:SetScript('OnClick', function()
	        scan_bids()
	    end)
	end
end