aux.module 'search_tab'

aux_favorite_searches = {}
aux_recent_searches = {}

function private.update_search_listings()
	local favorite_search_rows = {}
	for i, favorite_search in aux_favorite_searches do
		local name = strsub(favorite_search.prettified, 1, 250)
		tinsert(favorite_search_rows, {
			cols = {{value=name}},
			search = favorite_search,
			index = i,
		})
	end
	m.favorite_searches_listing:SetData(favorite_search_rows)

	local recent_search_rows = {}
	for i, recent_search in aux_recent_searches do
		local name = strsub(recent_search.prettified, 1, 250)
		tinsert(recent_search_rows, {
			cols = {{value=name}},
			search = recent_search,
			index = i,
		})
	end
	m.recent_searches_listing:SetData(recent_search_rows)
end

function private.new_recent_search(filter_string, prettified)
	tinsert(aux_recent_searches, 1, {
		filter_string = filter_string,
		prettified = prettified,
	})
	while getn(aux_recent_searches) > 50 do
		tremove(aux_recent_searches)
	end
	m.update_search_listings()
end