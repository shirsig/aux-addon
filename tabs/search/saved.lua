module 'search_tab'

_g.aux_favorite_searches = {}
_g.aux_recent_searches = {}

function update_search_listings()
	local favorite_search_rows = {}
	for i, favorite_search in _g.aux_favorite_searches do
		local name = strsub(favorite_search.prettified, 1, 250)
		tinsert(favorite_search_rows, {
			cols = {{value=name}},
			search = favorite_search,
			index = i,
		})
	end
	favorite_searches_listing:SetData(favorite_search_rows)

	local recent_search_rows = {}
	for i, recent_search in _g.aux_recent_searches do
		local name = strsub(recent_search.prettified, 1, 250)
		tinsert(recent_search_rows, {
			cols = {{value=name}},
			search = recent_search,
			index = i,
		})
	end
	recent_searches_listing:SetData(recent_search_rows)
end

function new_recent_search(filter_string, prettified)
	tinsert(_g.aux_recent_searches, 1, {
		filter_string = filter_string,
		prettified = prettified,
	})
	while getn(_g.aux_recent_searches) > 50 do
		tremove(_g.aux_recent_searches)
	end
	update_search_listings()
end