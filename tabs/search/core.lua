select(2, ...) 'aux.tabs.search'

local aux = require 'aux'
local info = require 'aux.util.info'

local tab = aux.tab 'Search'

StaticPopupDialogs.AUX_SEARCH_TABLE_FULL = {
    text = 'Table full!\nFurther results from this search will still be processed but no longer displayed in the table.',
    button1 = 'Ok',
    showAlert = 1,
    timeout = 0,
    hideOnEscape = 1,
}

RESULTS, SAVED, FILTER = aux.enum(3)

function aux.event.AUX_LOADED()
	set_subtab(SAVED)
end

function tab.OPEN()
    frame:Show()
    update_search_listings()
    update_filter_display()
end

function tab.CLOSE()
    current_search().table:SetSelectedRecord()
    frame:Hide()
end

function tab.CLICK_LINK(item_info)
	set_filter(strlower(item_info.name) .. '/exact')
	execute(nil, false)
end

function tab.USE_ITEM(item_id)
	set_filter(strlower(info.item(item_id).name) .. '/exact')
	execute(nil, false)
end

function set_subtab(tab)
    search_results_button:UnlockHighlight()
    saved_searches_button:UnlockHighlight()
    new_filter_button:UnlockHighlight()
    frame.results:Hide()
    frame.saved:Hide()
    frame.filter:Hide()

    if tab == RESULTS then
        frame.results:Show()
        search_results_button:LockHighlight()
    elseif tab == SAVED then
        frame.saved:Show()
        saved_searches_button:LockHighlight()
    elseif tab == FILTER then
        frame.filter:Show()
        new_filter_button:LockHighlight()
    end
end

function M.set_filter(filter_string)
	search_box:SetFocus()
    search_box:SetText(filter_string)
end

function add_filter(filter_string)
    local old_filter_string = search_box:GetText()
    old_filter_string = aux.trim(old_filter_string)

    if old_filter_string ~= '' then
        old_filter_string = old_filter_string .. ';'
    end

    set_filter(old_filter_string .. filter_string)
end

