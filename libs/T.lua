select(2, ...) 'T'

function M.map(...)
	local t = {}
	for i = 1, select('#', ...), 2 do
		t[select(i, ...)] = select(i + 1, ...)
	end
	return t
end