aux.module 'search_tab'
aux.tab(1, 'Search')

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
        m.auto_buy_button:SetChecked(true)
    end,
    timeout = 0,
    hideOnEscape = 1,
}
do
    local function action()
        aux_auto_buy_filter = getglobal(this:GetParent():GetName()..'EditBox'):GetText()
        m.update_auto_buy_filter()
    end

    StaticPopupDialogs['AUX_SEARCH_AUTO_BUY_FILTER'] = {
        text = 'Enter a filter for automatic buyout.',
        button1 = 'Accept',
        button2 = 'Cancel',
        hasEditBox = 1,
        OnShow = function()
            local edit_box = getglobal(this:GetName()..'EditBox')
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

private.RESULTS, private.SAVED, private.FILTER = 1, 2, 3

function m.LOAD()
	m.create_frames()
	m.update_tab(m.SAVED)
	m.update_auto_buy_filter()
	m.new_search ''
	m.current_search().placeholder = true
end

function m.OPEN()
    m.frame:Show()
    m.update_search_listings()
end

function m.CLOSE()
    m.close_settings()
    m.current_search().table:SetSelectedRecord()
    m.frame:Hide()
end

function m.CLICK_LINK(item_info)
	m.set_filter(strlower(item_info.name)..'/exact')
	m.execute(nil, false)
end

function m.USE_ITEM(item_info)
	m.set_filter(strlower(item_info.name)..'/exact')
	m.execute(nil, false)
end

function private.update_tab(tab)

    m.search_results_button:UnlockHighlight()
    m.saved_searches_button:UnlockHighlight()
    m.new_filter_button:UnlockHighlight()
    m.frame.results:Hide()
    m.frame.saved:Hide()
    m.frame.filter:Hide()

    if tab == m.RESULTS then
        m.frame.results:Show()
        m.search_results_button:LockHighlight()
    elseif tab == m.SAVED then
        m.frame.saved:Show()
        m.saved_searches_button:LockHighlight()
    elseif tab == m.FILTER then
        m.frame.filter:Show()
        m.new_filter_button:LockHighlight()
    end
end

function public.set_filter(filter_string)
    m.search_box:SetText(filter_string)
end

function public.add_filter(filter_string)
    local old_filter_string = m.search_box:GetText()
    old_filter_string = aux.util.trim(old_filter_string)

    if old_filter_string ~= '' then
        old_filter_string = old_filter_string..';'
    end

    m.search_box:SetText(old_filter_string..filter_string)
end

function private.blizzard_page_index(str)
    if tonumber(str) then
        return max(0, tonumber(str) - 1)
    end
end

