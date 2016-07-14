local private, public = {}, {}
Aux.sort = public

public.LT = {}
public.EQ = {}
public.GT = {}

function public.invert_order(ordering)
    if ordering == public.LT then
        return public.GT
    elseif ordering == public.GT then
        return public.LT
    else
        return public.EQ
    end
end

function public.compare(a, b, desc)
    if a < b then
        return desc and public.GT or public.LT
    elseif a > b then
        return desc and public.LT or public.GT
    else
        return public.EQ
    end
end

function public.compare_from_lt(lt)
    return function(a, b)
        if lt(a, b) then
            return public.LT
        elseif lt(b, a) then
            return public.GT
        else
            return public.EQ
        end
    end
end

function public.multi_lt(xs, ys)
    local i = 1
    while true do
        if xs[i] and ys[i] and xs[i] ~= ys[i] then
            return xs[i] < ys[i]
        elseif not xs[i] and ys[i] then
            return true
        elseif not ys[i] then
            return false
        end

        i = i + 1
    end
end