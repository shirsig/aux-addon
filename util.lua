Aux.util = {}

function Aux.util.iter(array)
	local with_index = ipairs(array)
	return function()
		local _, value = with_index
		return value
	end
end

function Aux.util.dummy()
end