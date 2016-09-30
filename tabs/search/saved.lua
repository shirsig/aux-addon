aux_search_tab_saved = module

include (green_t)
include (aux)
include (aux_util)
include (aux_control)
include (aux_util_color)

aux_favorite_searches = t
aux_recent_searches = t

function private.update_search_listings()
	local favorite_search_rows = t
	for i, favorite_search in aux_favorite_searches do
		local name = strsub(favorite_search.prettified, 1, 250)
		tinsert(favorite_search_rows, {
			cols = {{ value=name }},
			search = favorite_search,
			index = i,
		})
	end
	aux_search_tab.favorite_searches_listing:SetData(favorite_search_rows)

	local recent_search_rows = t
	for i, recent_search in aux_recent_searches do
		local name = strsub(recent_search.prettified, 1, 250)
		tinsert(recent_search_rows, {
			cols = {{ value=name }},
			search = recent_search,
			index = i,
		})
	end
	aux_search_tab.recent_searches_listing:SetData(recent_search_rows)
end

function public.new_recent_search(filter_string, prettified)
	tinsert(aux_recent_searches, 1, {
		filter_string = filter_string,
		prettified = prettified,
	})
	while getn(aux_recent_searches) > 50 do
		tremove(aux_recent_searches)
	end
	update_search_listings()
end