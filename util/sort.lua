aux.module 'sorting'

public.LT = {}
public.EQ = {}
public.GT = {}

function public.compare(a, b, desc)
    if a < b then
        return desc and m.GT or m.LT
    elseif a > b then
        return desc and m.LT or m.GT
    else
        return m.EQ
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