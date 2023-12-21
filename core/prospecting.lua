select(2, ...) 'aux.core.prospecting'

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
    if item_id == 2770 then
        return {
            { item_id = 774, min_quantity = 1, max_quantity = 2, probability = 0.5 },
            { item_id = 818, min_quantity = 1, max_quantity = 2, probability = 0.5 },
            { item_id = 1210, min_quantity = 1, max_quantity = 1, probability = 0.1 },
        }
    elseif item_id == 2771 then
        return {
            { item_id = 1705, min_quantity = 1, max_quantity = 2, probability = 0.375 },
            { item_id = 1206, min_quantity = 1, max_quantity = 2, probability = 0.375 },
            { item_id = 1210, min_quantity = 1, max_quantity = 2, probability = 0.375 },
            { item_id = 7909, min_quantity = 1, max_quantity = 1, probability = 0.0333 },
            { item_id = 3864, min_quantity = 1, max_quantity = 1, probability = 0.0333 },
            { item_id = 1529, min_quantity = 1, max_quantity = 1, probability = 0.0333 },
        }
    elseif item_id == 2772 then
        return {
            { item_id = 1705, min_quantity = 1, max_quantity = 2, probability = 0.30 },
            { item_id = 3864, min_quantity = 1, max_quantity = 2, probability = 0.30 },
            { item_id = 1529, min_quantity = 1, max_quantity = 2, probability = 0.30 },
            { item_id = 7910, min_quantity = 1, max_quantity = 1, probability = 0.05 },
            { item_id = 7909, min_quantity = 1, max_quantity = 1, probability = 0.05 },
        }
    elseif item_id == 3858 then
        return {
            { item_id = 7910, min_quantity = 1, max_quantity = 2, probability = 0.30 },
            { item_id = 7909, min_quantity = 1, max_quantity = 2, probability = 0.30 },
            { item_id = 3864, min_quantity = 1, max_quantity = 2, probability = 0.30 },
            { item_id = 12361, min_quantity = 1, max_quantity = 1, probability = 0.025 },
            { item_id = 12799, min_quantity = 1, max_quantity = 1, probability = 0.025 },
            { item_id = 12800, min_quantity = 1, max_quantity = 1, probability = 0.025 },
            { item_id = 12364, min_quantity = 1, max_quantity = 1, probability = 0.025 },
        }
    elseif item_id == 10620 then
        return {
            { item_id = 7910, min_quantity = 1, max_quantity = 2, probability = 0.30 },
            { item_id = 12364, min_quantity = 1, max_quantity = 2, probability = 0.16 },
            { item_id = 12800, min_quantity = 1, max_quantity = 2, probability = 0.16 },
            { item_id = 12361, min_quantity = 1, max_quantity = 2, probability = 0.16 },
            { item_id = 12799, min_quantity = 1, max_quantity = 2, probability = 0.16 },
            { item_id = 23077, min_quantity = 1, max_quantity = 1, probability = 0.0166 },
            { item_id = 23079, min_quantity = 1, max_quantity = 1, probability = 0.0166 },
            { item_id = 21929, min_quantity = 1, max_quantity = 1, probability = 0.0166 },
            { item_id = 23112, min_quantity = 1, max_quantity = 1, probability = 0.0166 },
            { item_id = 23107, min_quantity = 1, max_quantity = 1, probability = 0.0166 },
            { item_id = 23117, min_quantity = 1, max_quantity = 1, probability = 0.0166 },
        }
    elseif item_id == 23424 then
        return {
            { item_id = 23077, min_quantity = 1, max_quantity = 2, probability = 0.17 },
            { item_id = 23079, min_quantity = 1, max_quantity = 2, probability = 0.17 },
            { item_id = 21929, min_quantity = 1, max_quantity = 2, probability = 0.17 },
            { item_id = 23112, min_quantity = 1, max_quantity = 2, probability = 0.17 },
            { item_id = 23107, min_quantity = 1, max_quantity = 2, probability = 0.17 },
            { item_id = 23117, min_quantity = 1, max_quantity = 2, probability = 0.17 },
            { item_id = 23439, min_quantity = 1, max_quantity = 1, probability = 0.01 },
            { item_id = 23440, min_quantity = 1, max_quantity = 1, probability = 0.01 },
            { item_id = 23436, min_quantity = 1, max_quantity = 1, probability = 0.01 },
            { item_id = 23441, min_quantity = 1, max_quantity = 1, probability = 0.01 },
            { item_id = 23438, min_quantity = 1, max_quantity = 1, probability = 0.01 },
            { item_id = 23437, min_quantity = 1, max_quantity = 1, probability = 0.01 },
        }
    elseif item_id == 23425 then
        return {
            { item_id = 24243, min_quantity = 1, max_quantity = 2, probability = 0.65 },
            { item_id = 23077, min_quantity = 1, max_quantity = 2, probability = 0.19 },
            { item_id = 23079, min_quantity = 1, max_quantity = 2, probability = 0.19 },
            { item_id = 21929, min_quantity = 1, max_quantity = 2, probability = 0.19 },
            { item_id = 23112, min_quantity = 1, max_quantity = 2, probability = 0.19 },
            { item_id = 23107, min_quantity = 1, max_quantity = 2, probability = 0.19 },
            { item_id = 23117, min_quantity = 1, max_quantity = 2, probability = 0.19 },
            { item_id = 23439, min_quantity = 1, max_quantity = 1, probability = 0.03 },
            { item_id = 23440, min_quantity = 1, max_quantity = 1, probability = 0.03 },
            { item_id = 23436, min_quantity = 1, max_quantity = 1, probability = 0.03 },
            { item_id = 23441, min_quantity = 1, max_quantity = 1, probability = 0.03 },
            { item_id = 23438, min_quantity = 1, max_quantity = 1, probability = 0.03 },
            { item_id = 23437, min_quantity = 1, max_quantity = 1, probability = 0.03 },
        }
    elseif item_id == 36909 then
        return {
            { item_id = 36917, min_quantity = 1, max_quantity = 2, probability = 0.166 },
            { item_id = 36923, min_quantity = 1, max_quantity = 2, probability = 0.166 },
            { item_id = 36932, min_quantity = 1, max_quantity = 2, probability = 0.166 },
            { item_id = 36929, min_quantity = 1, max_quantity = 2, probability = 0.166 },
            { item_id = 36926, min_quantity = 1, max_quantity = 2, probability = 0.166 },
            { item_id = 36920, min_quantity = 1, max_quantity = 2, probability = 0.166 },
            { item_id = 36933, min_quantity = 1, max_quantity = 1, probability = 0.013 },
            { item_id = 36918, min_quantity = 1, max_quantity = 1, probability = 0.013 },
            { item_id = 36921, min_quantity = 1, max_quantity = 1, probability = 0.013 },
            { item_id = 36930, min_quantity = 1, max_quantity = 1, probability = 0.013 },
            { item_id = 36924, min_quantity = 1, max_quantity = 1, probability = 0.013 },
            { item_id = 36927, min_quantity = 1, max_quantity = 1, probability = 0.013 },
        }
    elseif item_id == 36912 then
        return {
            { item_id = 36917, min_quantity = 1, max_quantity = 2, probability = 0.166 },
            { item_id = 36923, min_quantity = 1, max_quantity = 2, probability = 0.166 },
            { item_id = 36932, min_quantity = 1, max_quantity = 2, probability = 0.166 },
            { item_id = 36929, min_quantity = 1, max_quantity = 2, probability = 0.166 },
            { item_id = 36926, min_quantity = 1, max_quantity = 2, probability = 0.166 },
            { item_id = 36920, min_quantity = 1, max_quantity = 1, probability = 0.166 },
            { item_id = 36933, min_quantity = 1, max_quantity = 1, probability = 0.04 },
            { item_id = 36918, min_quantity = 1, max_quantity = 2, probability = 0.04 },
            { item_id = 36921, min_quantity = 1, max_quantity = 1, probability = 0.04 },
            { item_id = 36930, min_quantity = 1, max_quantity = 1, probability = 0.04 },
            { item_id = 36924, min_quantity = 1, max_quantity = 1, probability = 0.04 },
            { item_id = 36927, min_quantity = 1, max_quantity = 1, probability = 0.04 },
        }
    elseif item_id == 36910 then
        return {
            { item_id = 46849, min_quantity = 1, max_quantity = 1, probability = 1 },
            { item_id = 36917, min_quantity = 1, max_quantity = 1, probability = 0.166 },
            { item_id = 36923, min_quantity = 1, max_quantity = 1, probability = 0.166 },
            { item_id = 36932, min_quantity = 1, max_quantity = 1, probability = 0.166 },
            { item_id = 36929, min_quantity = 1, max_quantity = 1, probability = 0.166 },
            { item_id = 36926, min_quantity = 1, max_quantity = 1, probability = 0.166 },
            { item_id = 36920, min_quantity = 1, max_quantity = 1, probability = 0.166 },
            { item_id = 36933, min_quantity = 1, max_quantity = 1, probability = 0.04 },
            { item_id = 36918, min_quantity = 1, max_quantity = 1, probability = 0.04 },
            { item_id = 36921, min_quantity = 1, max_quantity = 1, probability = 0.04 },
            { item_id = 36930, min_quantity = 1, max_quantity = 1, probability = 0.04 },
            { item_id = 36924, min_quantity = 1, max_quantity = 1, probability = 0.04 },
            { item_id = 36927, min_quantity = 1, max_quantity = 1, probability = 0.04 },
            { item_id = 36931, min_quantity = 1, max_quantity = 1, probability = 0.05 },
            { item_id = 36928, min_quantity = 1, max_quantity = 1, probability = 0.05 },
            { item_id = 36934, min_quantity = 1, max_quantity = 1, probability = 0.05 },
            { item_id = 36919, min_quantity = 1, max_quantity = 1, probability = 0.05 },
            { item_id = 36922, min_quantity = 1, max_quantity = 1, probability = 0.05 },
            { item_id = 36925, min_quantity = 1, max_quantity = 1, probability = 0.05 },
        }
    end
    return {}
end

