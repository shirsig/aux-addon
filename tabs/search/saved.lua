module 'aux.tabs.search'

local filter_util = require 'aux.util.filter'
local gui = require 'aux.gui'

_G.aux_favorite_searches = T
_G.aux_recent_searches = T

function update_search_listings()
	local favorite_search_rows = T
	for i, search in ipairs(aux_favorite_searches) do
		local name = strsub(search.prettified, 1, 250)
		tinsert(favorite_search_rows, O(
			'cols', A(O('value', search.auto_buy and color.red'A' or ''), O('value', name)),
			'search', search,
			'index', i
		))
	end
	favorite_searches_listing:SetData(favorite_search_rows)

	local recent_search_rows = T
	for i, recent_search in ipairs(aux_recent_searches) do
		local name = strsub(recent_search.prettified, 1, 250)
		tinsert(recent_search_rows, O(
			'cols', A(O('value', name)),
			'search', recent_search,
			'index', i
		))
	end
	recent_searches_listing:SetData(recent_search_rows)
end

function new_recent_search(filter_string, prettified)
	tinsert(aux_recent_searches, 1, O(
		'filter_string', filter_string,
		'prettified', prettified
	))
	while getn(aux_recent_searches) > 50 do
		tremove(aux_recent_searches)
	end
	update_search_listings()
end

handlers = {
	OnClick = function(st, data, _, button)
		if not data then return end
		if button == 'LeftButton' and IsShiftKeyDown() then
			search_box:SetText(data.search.filter_string)
		elseif button == 'RightButton' and IsShiftKeyDown() then
			add_filter(data.search.filter_string)
		elseif button == 'LeftButton' then
			search_box:SetText(data.search.filter_string)
			execute()
		elseif button == 'RightButton' then
			local u = update_search_listings
			if st == recent_searches_listing then
				gui.menu(
					'Favorite', function() tinsert(aux_favorite_searches, 1, data.search); u() end
				)
			elseif st == favorite_searches_listing then
				local auto_buy = data.search.auto_buy
				gui.menu(
					(auto_buy and 'Disable' or 'Enable') .. ' Auto Buy', function() if auto_buy then data.search.auto_buy = nil else enable_auto_buy(data.search) end u() end,
					'Move Up', function() move_up(aux_favorite_searches, data.index); u() end,
					'Move Down', function() move_down(aux_favorite_searches, data.index); u() end,
					'Delete', function() tremove(aux_favorite_searches, data.index); u() end
				)
			end
		end
	end,
	OnEnter = function(st, data, self)
		if not data then return end
		GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
		GameTooltip:AddLine(gsub(data.search.prettified, ';', '\n\n'), 255/255, 254/255, 250/255, true)
		GameTooltip:Show()
	end,
	OnLeave = function()
		GameTooltip:ClearLines()
		GameTooltip:Hide()
	end
}

function get_auto_buy_validator()
	local validators = T
	for _, search in aux_favorite_searches do
		if search.auto_buy then
			local queries, error = filter_util.queries(search.filter_string)
			if queries then
				tinsert(validators, queries[1].validator)
			else
				print('Invalid auto buy filter:', error)
			end
		end
	end
	return function(record)
		return any(validators, function(validator) return validator(record) end)
	end
end

function add_favorite(filter_string)
	local queries, error = filter_util.queries(filter_string)
	if queries then
		tinsert(aux_favorite_searches, 1, O(
			'filter_string', filter_string,
			'prettified', join(map(queries, function(query) return query.prettified end), ';')
		))
		update_search_listings()
	else
		print('Invalid filter:', error)
	end
end

function enable_auto_buy(search)
	local queries, error = filter_util.queries(search.filter_string)
	if queries then
		if getn(queries) > 1 then
			print('Error: Auto Buy does not support multi-queries')
		elseif size(queries[1].blizzard_query) > 0 and not filter_util.parse_filter_string(search.filter_string).blizzard.exact then
			print('Error: Auto Buy does not support Blizzard filters')
		else
			search.auto_buy = true
		end
	else
		print('Invalid filter:', error)
	end
end

function move_up(list, index)
	if list[index - 1] then
		list[index], list[index - 1] = list[index - 1], list[index]
	end
end

function move_down(list, index)
	if list[index + 1] then
		list[index], list[index + 1] = list[index + 1], list[index]
	end
end