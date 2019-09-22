select(2, ...) 'aux.util.sort'

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

function M.multi_lt(...)
	for i = 1, select('#', ...), 2 do
        local arg1, arg2 = select(i, ...)
        if arg1 and arg2 and arg1 ~= arg2 then
            return arg1 < arg2
        elseif not arg1 and arg2 then
            return true
        elseif not arg2 then
            return false
        end
	end
	return false
end