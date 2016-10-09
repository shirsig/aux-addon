module 'aux.util.sort'

include 'green_t'
include 'aux'
include 'aux.util'
include 'aux.control'
include 'aux.util.color'

public.EQ = 0
public.LT = 1
public.GT = 2

function public.compare(a, b, desc)
    if a < b then
        return desc and GT or LT
    elseif a > b then
        return desc and LT or GT
    else
        return EQ
    end
end

public.multi_lt = vararg-function(arg)
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