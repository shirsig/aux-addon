module 'aux.util.sort'

local T = require 'T'

M.EQ = 0
M.LT = 1
M.GT = 2

function M.compare(a, b, desc)
    if a < b then
        return desc and GT or LT
    elseif a > b then
        return desc and LT or GT
    else
        return EQ
    end
end

M.multi_lt = T.vararg-function(arg)
	for i = 1, getn(arg), 2 do
        if arg[i] and arg[i + 1] and arg[i] ~= arg[i + 1] then
            return arg[i] < arg[i + 1]
        elseif not arg[i] and arg[i + 1] then
            return true
        elseif not arg[i + 1] then
            return false
        end
	end
	return false
end