select(2, ...) 'aux.core.milling'

local aux = require 'aux'
local history = require 'aux.core.history'

function M.value(item_id)
    local expectation
    for _, event in pairs(distribution(item_id)) do
        local value = history.value(event.item_id .. ':' .. 0)
        expectation = (expectation or 0) + event.probability * (event.min_quantity + event.max_quantity) / 2 * (value or 0)
    end
    return expectation
end

function M.distribution(item_id)
    if item_id == 2447 or item_id == 765 or item_id == 2449 then
        return {
            { item_id = 39151, min_quantity = 2, max_quantity = 4, probability = 1 },
        }
    elseif item_id == 785 then
        return {
            { item_id = 39334, min_quantity = 2, max_quantity = 3, probability = 1 },
            { item_id = 43103, min_quantity = 1, max_quantity = 3, probability = 0.25 },
        }
    elseif item_id == 2450 or item_id == 2452 then
        return {
            { item_id = 39334, min_quantity = 2, max_quantity = 4, probability = 1 },
            { item_id = 43103, min_quantity = 1, max_quantity = 3, probability = 0.25 },
        }
    elseif item_id == 2453 or item_id == 3820 then
        return {
            { item_id = 39334, min_quantity = 2, max_quantity = 4, probability = 1 },
            { item_id = 43103, min_quantity = 1, max_quantity = 3, probability = 0.5 },
        }
    elseif item_id == 3355 or item_id == 3369 then
        return {
            { item_id = 39338, min_quantity = 2, max_quantity = 3, probability = 1 },
            { item_id = 43104, min_quantity = 1, max_quantity = 3, probability = 0.25 },
        }
    elseif item_id == 3356 or item_id == 3357 then
        return {
            { item_id = 39338, min_quantity = 2, max_quantity = 4, probability = 1 },
            { item_id = 43104, min_quantity = 1, max_quantity = 3, probability = 0.5 },
        }
    elseif item_id == 3818 or item_id == 3821 then
        return {
            { item_id = 39339, min_quantity = 2, max_quantity = 3, probability = 1 },
            { item_id = 43105, min_quantity = 1, max_quantity = 3, probability = 0.25 },
        }
    elseif item_id == 3358 or item_id == 3819 then
        return {
            { item_id = 39339, min_quantity = 2, max_quantity = 4, probability = 1 },
            { item_id = 43105, min_quantity = 1, max_quantity = 3, probability = 0.5 },
        }
    elseif item_id == 4625 or item_id == 8831 or item_id == 8836 or item_id == 8838 then
        return {
            { item_id = 39340, min_quantity = 2, max_quantity = 3, probability = 1 },
            { item_id = 43106, min_quantity = 1, max_quantity = 3, probability = 0.25 },
        }
    elseif item_id == 8839 or item_id == 8845 or item_id == 8846 then
        return {
            { item_id = 39340, min_quantity = 2, max_quantity = 4, probability = 1 },
            { item_id = 43106, min_quantity = 1, max_quantity = 3, probability = 0.5 },
        }
    elseif item_id == 13463 or item_id == 13464 then
        return {
            { item_id = 39341, min_quantity = 2, max_quantity = 4, probability = 1 },
            { item_id = 43107, min_quantity = 1, max_quantity = 3, probability = 0.25 },
        }
    elseif item_id == 13465 then
        return {
            { item_id = 39341, min_quantity = 2, max_quantity = 4, probability = 1 },
        }
    elseif item_id == 13466 or item_id == 13467 then
        return {
            { item_id = 39341, min_quantity = 2, max_quantity = 4, probability = 1 },
            { item_id = 43107, min_quantity = 1, max_quantity = 3, probability = 0.5 },
        }
    elseif item_id == 22785 then
        return {
            { item_id = 39342, min_quantity = 2, max_quantity = 4, probability = 1 },
            { item_id = 43108, min_quantity = 1, max_quantity = 3, probability = 0.25 },
        }
    elseif item_id == 22786 or item_id == 22787 or item_id == 22789 then
        return {
            { item_id = 39342, min_quantity = 2, max_quantity = 3, probability = 1 },
            { item_id = 43108, min_quantity = 1, max_quantity = 3, probability = 0.25 },
        }
    elseif item_id == 22790 or item_id == 22791 or item_id == 22792 or item_id == 22793 then
        return {
            { item_id = 39342, min_quantity = 2, max_quantity = 4, probability = 1 },
            { item_id = 43108, min_quantity = 1, max_quantity = 3, probability = 0.5 },
        }
    elseif item_id == 36901  or item_id == 36907 or item_id == 37921 or item_id == 39970 then
        return {
            { item_id = 39343, min_quantity = 2, max_quantity = 3, probability = 1 },
            { item_id = 43109, min_quantity = 1, max_quantity = 3, probability = 0.25 },
        }
    elseif item_id == 36903 then
        return {
            { item_id = 39343, min_quantity = 2, max_quantity = 4, probability = 1 },
            { item_id = 43109, min_quantity = 1, max_quantity = 4, probability = 0.5 },
        }
    elseif item_id == 36904 then
        return {
            { item_id = 39343, min_quantity = 2, max_quantity = 4, probability = 1 },
            { item_id = 43109, min_quantity = 1, max_quantity = 3, probability = 0.25 },
        }
    elseif item_id == 36905 or item_id == 36906 then
        return {
            { item_id = 39343, min_quantity = 2, max_quantity = 4, probability = 1 },
            { item_id = 43109, min_quantity = 1, max_quantity = 3, probability = 0.5 },
        }
    end
    return {}
end
