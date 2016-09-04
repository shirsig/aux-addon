aux 'search_tab' local scan, scan_util = aux.scan, aux.scan_util

StaticPopupDialogs['AUX_SEARCH_TABLE_FULL'] = {
    text = 'Table full!\nFurther results from this search will still be processed but no longer displayed in the table.',
    button1 = 'Ok',
    showAlert = 1,
    timeout = 0,
    hideOnEscape = 1,
}
StaticPopupDialogs['AUX_SEARCH_AUTO_BUY'] = {
    text = 'Are you sure you want to activate automatic buyout?',
    button1 = 'Yes',
    button2 = 'No',
    OnAccept = function()
        auto_buy_button:SetChecked(true)
    end,
    timeout = 0,
    hideOnEscape = 1,
}
do
    local function action()
        _G.aux_auto_buy_filter = _G[this:GetParent():GetName() .. 'EditBox']:GetText()
        update_auto_buy_filter()
    end

    StaticPopupDialogs['AUX_SEARCH_AUTO_BUY_FILTER'] = {
        text = 'Enter a filter for automatic buyout.',
        button1 = 'Accept',
        button2 = 'Cancel',
        hasEditBox = 1,
        OnShow = function()
            local edit_box = _G[this:GetName() .. 'EditBox']
            edit_box:SetMaxLetters(nil)
            edit_box:SetFocus()
            edit_box:HighlightText()
        end,
        OnAccept = action,
        EditBoxOnEnterPressed = function()
            action()
            this:GetParent():Hide()
        end,
        EditBoxOnEscapePressed = function()
            this:GetParent():Hide()
        end,
        timeout = 0,
        hideOnEscape = 1,
    }
end

RESULTS, SAVED, FILTER = 1, 2, 3

function LOAD()
	create_frames()
	subtab = SAVED
	update_auto_buy_filter()
	new_search('')
	current_search.placeholder = true
end

function OPEN()
    frame:Show()
    update_search_listings()
end

function CLOSE()
    close_settings()
    current_search.table:SetSelectedRecord()
    frame:Hide()
end

function CLICK_LINK(item_info)
	set_filter(strlower(item_info.name) .. '/exact')
	execute(nil, false)
end

function USE_ITEM(item_info)
	set_filter(strlower(item_info.name) .. '/exact')
	execute(nil, false)
end

function private.subtab.set(tab)
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

function public.set_filter(filter_string)
    search_box:SetText(filter_string)
end

function public.add_filter(filter_string)
    local old_filter_string = search_box:GetText()
    old_filter_string = trim(old_filter_string)

    if old_filter_string ~= '' then
        old_filter_string = old_filter_string .. ';'
    end

    search_box:SetText(old_filter_string .. filter_string)
end

function blizzard_page_index(str)
    if tonumber(str) then
        return max(0, tonumber(str) - 1)
    end
end

