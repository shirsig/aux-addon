module 'aux.tabs.auctions'

local gui = require 'aux.gui'
local auction_listing = require 'aux.gui.auction_listing'

frame = CreateFrame('Frame', nil, AuxFrame)
frame:SetAllPoints()
frame:SetScript('OnUpdate', on_update)
frame:Hide()

frame.listing = gui.panel(frame)
frame.listing:SetPoint('TOP', frame, 'TOP', 0, -8)
frame.listing:SetPoint('BOTTOMLEFT', AuxFrame.content, 'BOTTOMLEFT', 0, 0)
frame.listing:SetPoint('BOTTOMRIGHT', AuxFrame.content, 'BOTTOMRIGHT', 0, 0)

listing = auction_listing.CreateAuctionResultsTable(frame.listing, auction_listing.auctions_config)
listing:SetSort(1, 2, 3, 4, 5, 6, 7, 8)
listing:Reset()
listing:SetHandler('OnCellClick', function(cell, button)
    if IsAltKeyDown() and listing:GetSelection().record == cell.row.data.record then
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
    status_bar:SetPoint('TOPLEFT', AuxFrame.content, 'BOTTOMLEFT', 0, -6)
    status_bar:update_status(1, 1)
    status_bar:set_text('')
end
do
    local btn = gui.button(frame)
    btn:SetPoint('TOPLEFT', status_bar, 'TOPRIGHT', 5, 0)
    btn:SetText('Cancel')
    btn:Disable()
    cancel_button = btn
end
do
    local btn = gui.button(frame)
    btn:SetPoint('TOPLEFT', cancel_button, 'TOPRIGHT', 5, 0)
    btn:SetText('Refresh')
    btn:SetScript('OnClick', function()
        scan_auctions()
    end)
end