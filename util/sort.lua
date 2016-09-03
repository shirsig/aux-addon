aux 'sorting' private()

public()

LT, EQ, GT = t, t, t

function compare(a, b, desc)
    if a < b then
        return desc and GT or LT
    elseif a > b then
        return desc and LT or GT
    else
        return EQ
    end
end

function multi_lt(xs, ys)
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