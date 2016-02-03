local private, public = {}, {}
Aux.sort = public

public.LT = {}
public.EQ = {}
public.GT = {}

-- stable sorting
function public.merge_sort(A, comp)
    local n = getn(A)
    local B = {}

    local width = 1
    while width <= n do

        for i=1, n, 2 * width do
            private.merge(A, i, min(i + width, n), min(i + 2 * width - 1, n), B, comp)
        end

        private.copy_array(B, A, n)

        width = 2 * width
    end
end

function private.merge(A, start1, start2, last, B, comp)
    local i1 = start1
    local i2 = start2

    for i=start1,last do
        if i1 < start2 and (i2 > last or comp(A[i1], A[i2]) == public.LT or comp(A[i1], A[i2]) == public.EQ) then
            B[i] = A[i1]
            i1 = i1 + 1
        else
            B[i] = A[i2]
            i2 = i2 + 1
        end
    end
end

function private.copy_array(A, B, n)
    for i=1,n do
        B[i] = A[i]
    end
end

function public.invert_order(ordering)
    if ordering == public.LT then
        return public.GT
    elseif ordering == public.GT then
        return public.LT
    else
        return public.EQ
    end
end

function public.compare(a, b, nil_ordering)
    nil_ordering = nil_ordering or public.EQ
    if not a and b then
        return nil_ordering
    elseif a and not b then
        return public.invert_order(nil_ordering)
    elseif not a and not b then
        return public.EQ
    elseif a < b then
        return public.LT
    elseif a > b then
        return public.GT
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

function public.multi_lt(...)
    for i=1,arg.n-1,2 do
        if arg[i] ~= arg[i+1] then
            return arg[i] < arg[i+1]
        end
    end
    return false
end