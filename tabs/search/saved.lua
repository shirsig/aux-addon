select(2, ...) 'aux.tabs.search'

local aux = require 'aux'
local filter_util = require 'aux.util.filter'

dragged_search = nil

function aux.event.AUX_LOADED()
	recent_searches, favorite_searches = aux.realm_data.recent_searches, aux.realm_data.favorite_searches
end

function update_search_listings()
	local favorite_search_rows = {}
	for i = 1, #favorite_searches do
		local search = favorite_searches[i]
		local name = strsub(search.prettified, 1, 250)
		tinsert(favorite_search_rows, {
			cols = {{ value = search.alert and aux.color.red'X' or '' }, { value = name }},
			search = search,
			index = i,
        })
	end
	favorite_searches_listing:SetData(favorite_search_rows)

	local recent_search_rows = {}
	for i = 1, #recent_searches do
		local search = recent_searches[i]
		local name = strsub(search.prettified, 1, 250)
		tinsert(recent_search_rows, {
			cols = {{ value = name }},
			search = search,
			index = i,
        })
	end
	recent_searches_listing:SetData(recent_search_rows)
end

function new_recent_search(filter_string, prettified)
	for i = #recent_searches, 1, -1 do
		if recent_searches[i].filter_string == filter_string then
			tremove(recent_searches, i)
		end
	end
	tinsert(recent_searches, 1, {
		filter_string = filter_string,
		prettified = prettified,
    })
	while #recent_searches > 50 do
		tremove(recent_searches)
	end
	update_search_listings()
end

handlers = {
	OnClick = function(st, data, _, button)
        if IsAltKeyDown() and st == favorite_searches_listing then
            if data.search.alert then
                data.search.alert = nil
            else
                enable_alert(data.search)
            end
            update_search_listings()
		elseif button == 'LeftButton' and IsShiftKeyDown() then
			set_filter(data.search.filter_string)
		elseif button == 'RightButton' and IsShiftKeyDown() then
			add_filter(data.search.filter_string)
		elseif button == 'LeftButton' then
			set_filter(data.search.filter_string)
			execute()
		elseif button == 'RightButton' then
			if st == recent_searches_listing then
                for _, entry in pairs(favorite_searches) do
                    if entry.filter_string == data.search.filter_string then
                        return
                    end
                end
				tinsert(favorite_searches, 1, data.search)
			elseif st == favorite_searches_listing then
                tremove(favorite_searches, data.index)
            end
            update_search_listings()
        end
	end,
    OnMouseDown = function(st, data)
        if st == favorite_searches_listing then
            dragged_search = favorite_searches[data.index]
        end
    end,
    OnMouseUp = function(st)
        if st == favorite_searches_listing then
            dragged_search = nil
        end
    end,
    OnEnter = function(st, data)
        if st == favorite_searches_listing and dragged_search then
            for i = #favorite_searches, 1, -1 do
                if favorite_searches[i] == dragged_search then
                    tremove(favorite_searches, i)
                end
            end
            tinsert(favorite_searches, data.index, dragged_search)
            update_search_listings()
        end
		GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
		GameTooltip:AddLine(gsub(data.search.prettified, ';', '\n\n'), 255/255, 254/255, 250/255, true)
		GameTooltip:Show()
	end,
	OnLeave = function()
		GameTooltip:ClearLines()
		GameTooltip:Hide()
	end
}

function get_alert_validator()
	local validators = {}
	for _, search in pairs(favorite_searches) do
		if search.alert then
			local queries, error = filter_util.queries(search.filter_string)
			if queries then
				tinsert(validators, queries[1].validator)
			else
				aux.print('Invalid alert filter:', error)
			end
		end
	end
	return function(record)
		return aux.any(validators, function(validator) return validator(record) end)
	end
end

function add_favorite(filter_string)
	local queries, error = filter_util.queries(filter_string)
	if queries then
		tinsert(favorite_searches, 1, {
			filter_string = filter_string,
			prettified = aux.join(aux.map(queries, function(query) return query.prettified end), ';')
        })
		update_search_listings()
	else
		aux.print('Invalid filter:', error)
	end
end

function enable_alert(search)
	local queries, error = filter_util.queries(search.filter_string)
	if queries then
		if #queries > 1 then
			aux.print('Error: Alert does not support multi-queries')
		elseif aux.size(queries[1].blizzard_query) > 0 and not filter_util.parse_filter_string(search.filter_string).blizzard.exact then
			aux.print('Error: Alert does not support Blizzard filters')
		else
			search.alert = true
		end
	else
		aux.print('Invalid filter:', error)
	end
end