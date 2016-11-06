module 'aux.tabs.post'

local info = require 'aux.util.info'
local money = require 'aux.util.money'
local gui = require 'aux.gui'
local listing = require 'aux.gui.listing'
local item_listing = require 'aux.gui.item_listing'
local search_tab = require 'aux.tabs.search'

frame = CreateFrame('Frame', nil, AuxFrame)
frame:SetAllPoints()
frame:SetScript('OnUpdate', on_update)
frame:Hide()

frame.content = CreateFrame('Frame', nil, frame)
frame.content:SetPoint('TOP', frame, 'TOP', 0, -8)
frame.content:SetPoint('BOTTOMLEFT', AuxFrame.content, 'BOTTOMLEFT', 0, 0)
frame.content:SetPoint('BOTTOMRIGHT', AuxFrame.content, 'BOTTOMRIGHT', 0, 0)

frame.inventory = gui.panel(frame.content)
frame.inventory:SetWidth(212)
frame.inventory:SetPoint('TOPLEFT', 0, 0)
frame.inventory:SetPoint('BOTTOMLEFT', 0, 0)

frame.parameters = gui.panel(frame.content)
frame.parameters:SetHeight(173)
frame.parameters:SetPoint('TOPLEFT', frame.inventory, 'TOPRIGHT', 2.5, 0)
frame.parameters:SetPoint('TOPRIGHT', 0, 0)

frame.auctions = gui.panel(frame.content)
frame.auctions:SetHeight(228)
frame.auctions:SetPoint('BOTTOMLEFT', frame.inventory, 'BOTTOMRIGHT', 2.5, 0)
frame.auctions:SetPoint('BOTTOMRIGHT', 0, 0)

do
    local checkbox = gui.checkbox(frame.inventory)
    checkbox:SetPoint('TOPLEFT', 49, -16)
    checkbox:SetScript('OnClick', function()
        refresh = true
    end)
    local label = gui.label(checkbox, gui.font_size.small)
    label:SetPoint('LEFT', checkbox, 'RIGHT', 4, 1)
    label:SetText('Show hidden items')
    show_hidden_checkbox = checkbox
end

gui.horizontal_line(frame.inventory, -48)

inventory_listing = item_listing.create(
    frame.inventory,
    function()
        if arg1 == 'LeftButton' then
            update_item(this.item_record)
        elseif arg1 == 'RightButton' then
            tab = 1
            search_tab.set_filter(strlower(info.item(this.item_record.item_id).name) .. '/exact')
            search_tab.execute(nil, false)
        end
    end,
    function(item_record)
        return item_record == selected_item
    end
)

auction_listing = listing.CreateScrollingTable(frame.auctions)
auction_listing:SetColInfo{
    {name='Auctions', width=.12, align='CENTER'},
    {name='Left', width=.1, align='CENTER'},
    {name='Qty', width=.08, align='CENTER'},
    {name='Bid/ea', width=.22, align='RIGHT'},
    {name='Bid Pct', width=.13, align='CENTER'},
    {name='Buy/ea', width=.22, align='RIGHT'},
    {name='Buy Pct', width=.13, align='CENTER'},
}
auction_listing:EnableSorting(false)
auction_listing:DisableSelection(true)
auction_listing:SetHandler('OnClick', function(table, row_data, column, button)
    local column_index = key(column, column.row.cols)
    local unit_start_price, unit_buyout_price = undercut(row_data.record, stack_size_slider:GetValue(), button == 'RightButton')
    if column_index == 3 then
        stack_size_slider:SetValue(row_data.record.stack_size)
    elseif column_index == 4 then
        set_unit_start_price(unit_start_price)
    elseif column_index == 6 then
        set_unit_buyout_price(unit_buyout_price)
    end
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
    local btn = gui.button(frame.parameters)
    btn:SetPoint('TOPLEFT', status_bar, 'TOPRIGHT', 5, 0)
    btn:SetText('Post')
    btn:SetScript('OnClick', post_auctions)
    post_button = btn
end
do
    local btn = gui.button(frame.parameters)
    btn:SetPoint('TOPLEFT', post_button, 'TOPRIGHT', 5, 0)
    btn:SetText('Refresh')
    btn:SetScript('OnClick', refresh_button_click)
    refresh_button = btn
end
do
	item = gui.item(frame.parameters)
    item:SetPoint('TOPLEFT', 10, -6)
    item.button:SetScript('OnEnter', function()
        if selected_item then
            info.set_tooltip(selected_item.itemstring, this, 'ANCHOR_RIGHT')
        end
    end)
    item.button:SetScript('OnLeave', function()
        GameTooltip:Hide()
    end)
end
do
    local slider = gui.slider(frame.parameters)
    slider:SetValueStep(1)
    slider:SetPoint('TOPLEFT', 13, -73)
    slider:SetWidth(190)
    slider:SetScript('OnValueChanged', function()
        quantity_update(true)
    end)
    slider.editbox.change = function()
        slider:SetValue(this:GetNumber())
        quantity_update(true)
        if selected_item then
            local settings = read_settings()
            settings.stack_size = this:GetNumber()
            write_settings(settings)
        end
    end
    slider.editbox:SetScript('OnTabPressed', function()
        if IsShiftKeyDown() then
            unit_buyout_price_input:SetFocus()
        elseif stack_count_slider.editbox:IsVisible() then
            stack_count_slider.editbox:SetFocus()
        else
            unit_start_price_input:SetFocus()
        end
    end)
    slider.editbox:SetNumeric(true)
    slider.editbox:SetMaxLetters(3)
    slider.label:SetText('Stack Size')
    stack_size_slider = slider
end
do
    local slider = gui.slider(frame.parameters)
    slider:SetValueStep(1)
    slider:SetPoint('TOPLEFT', stack_size_slider, 'BOTTOMLEFT', 0, -32)
    slider:SetWidth(190)
    slider:SetScript('OnValueChanged', function()
        quantity_update()
    end)
    slider.editbox.change = function()
        slider:SetValue(this:GetNumber())
        quantity_update()
    end
    slider.editbox:SetScript('OnTabPressed', function()
        if IsShiftKeyDown() then
            stack_size_slider.editbox:SetFocus()
        else
            unit_start_price_input:SetFocus()
        end
    end)
    slider.editbox:SetNumeric(true)
    slider.label:SetText('Stack Count')
    stack_count_slider = slider
end
do
    local dropdown = gui.dropdown(frame.parameters)
    dropdown:SetPoint('TOPLEFT', stack_count_slider, 'BOTTOMLEFT', 0, -21)
    dropdown:SetWidth(90)
    local label = gui.label(dropdown, gui.font_size.small)
    label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, -3)
    label:SetText('Duration')
    UIDropDownMenu_Initialize(dropdown, initialize_duration_dropdown)
    dropdown:SetScript('OnShow', function()
        UIDropDownMenu_Initialize(this, initialize_duration_dropdown)
    end)
    duration_dropdown = dropdown
end
do
    local label = gui.label(frame.parameters, gui.font_size.medium)
    label:SetPoint('LEFT', duration_dropdown, 'RIGHT', 25, 0)
    deposit = label
end
do
    local checkbox = gui.checkbox(frame.parameters)
    checkbox:SetPoint('TOPRIGHT', -83, -6)
    checkbox:SetScript('OnClick', function()
        local settings = read_settings()
        settings.hidden = this:GetChecked()
        write_settings(settings)
        refresh = true
    end)
    local label = gui.label(checkbox, gui.font_size.small)
    label:SetPoint('LEFT', checkbox, 'RIGHT', 4, 1)
    label:SetText('Hide this item')
    hide_checkbox = checkbox
end
do
    local editbox = gui.editbox(frame.parameters)
    editbox.name = 'start'
    editbox:SetPoint('TOPRIGHT', -71, -60)
    editbox:SetWidth(180)
    editbox:SetHeight(22)
    editbox:SetAlignment('RIGHT')
    editbox:SetFontSize(17)
    editbox:SetScript('OnTabPressed', function()
	    if IsShiftKeyDown() then
		    stack_count_slider.editbox:SetFocus()
	    else
		    unit_buyout_price_input:SetFocus()
	    end
    end)
    editbox.formatter = function() return money.to_string(get_unit_start_price(), true, nil, 3) end
    editbox.change = function() refresh = true end
    editbox.enter = function() this:ClearFocus() end
    editbox.focus_loss = function()
	    this:SetText(money.to_string(get_unit_start_price(), true, nil, 3, nil, true))
    end
    do
        local label = gui.label(editbox, gui.font_size.small)
        label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', -2, 1)
        label:SetText('Unit Starting Price')
    end
    do
        local label = gui.label(editbox, 14)
        label:SetPoint('LEFT', editbox, 'RIGHT', 8, 0)
        label:SetWidth(50)
        label:SetJustifyH('CENTER')
        start_price_percentage = label
    end
    unit_start_price_input = editbox
end
do
    local editbox = gui.editbox(frame.parameters)
    editbox.name = 'buy'
    editbox:SetPoint('TOPRIGHT', unit_start_price_input, 'BOTTOMRIGHT', 0, -19)
    editbox:SetWidth(180)
    editbox:SetHeight(22)
    editbox:SetAlignment('RIGHT')
    editbox:SetFontSize(17)
    editbox:SetScript('OnTabPressed', function()
        if IsShiftKeyDown() then
            unit_start_price_input:SetFocus()
        else
            stack_size_slider.editbox:SetFocus()
        end
    end)
    editbox.formatter = function() return money.to_string(get_unit_buyout_price(), true, nil, 3) end
    editbox.change = function() refresh = true end
    editbox.enter = function() this:ClearFocus() end
    editbox.focus_loss = function()
	    this:SetText(money.to_string(get_unit_buyout_price(), true, nil, 3, nil, true))
    end
    do
        local label = gui.label(editbox, gui.font_size.small)
        label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', -2, 1)
        label:SetText('Unit Buyout Price')
    end
    do
        local label = gui.label(editbox, 14)
        label:SetPoint('LEFT', editbox, 'RIGHT', 8, 0)
        label:SetWidth(50)
        label:SetJustifyH('CENTER')
        buyout_price_percentage = label
    end
    unit_buyout_price_input = editbox
end
do
    local btn = gui.button(frame.parameters, 14)
    btn:SetPoint('TOPRIGHT', -10, -146)
    gui.set_size(btn, 150, 20)
    btn:GetFontString():SetJustifyH('RIGHT')
    btn:GetFontString():SetPoint('RIGHT', -2, 0)
    btn:SetScript('OnClick', function()
        if this.amount then
            set_unit_start_price(this.amount)
            set_unit_buyout_price(this.amount)
        end
    end)
    local label = gui.label(btn, gui.font_size.small)
    label:SetPoint('BOTTOMLEFT', btn, 'TOPLEFT', -2, 1)
    label:SetText('Historical Value')
    historical_value_button = btn
end