module 'aux.core.disenchant'

include 'aux'

local T = require 'T'

local history = require 'aux.core.history'

local UNCOMMON, RARE, EPIC = 2, 3, 4

local ARMOR = T.set(
	'INVTYPE_HEAD',
	'INVTYPE_NECK',
	'INVTYPE_SHOULDER',
	'INVTYPE_BODY',
	'INVTYPE_CHEST',
	'INVTYPE_ROBE',
	'INVTYPE_WAIST',
	'INVTYPE_LEGS',
	'INVTYPE_FEET',
	'INVTYPE_WRIST',
	'INVTYPE_HAND',
	'INVTYPE_FINGER',
	'INVTYPE_TRINKET',
	'INVTYPE_CLOAK',
	'INVTYPE_HOLDABLE'
)

local WEAPON = T.set(
	'INVTYPE_2HWEAPON',
	'INVTYPE_WEAPONMAINHAND',
	'INVTYPE_WEAPON',
	'INVTYPE_WEAPONOFFHAND',
	'INVTYPE_SHIELD',
	'INVTYPE_RANGED',
	'INVTYPE_RANGEDRIGHT'
)

function M.value(slot, quality, level)
    local expectation
    for _, event in pairs(distribution(slot, quality, level)) do
        local value = history.value(event.item_id .. ':' .. 0)
        if not value then
            return
        else
            expectation = (expectation or 0) + event.probability * (event.min_quantity + event.max_quantity) / 2 * value
        end
    end
    return expectation
end

function M.distribution(slot, quality, level)
    if not ARMOR[slot] and not WEAPON[slot] or level == 0 then
        return T.acquire()
    end

    local function p(probability_armor, probability_weapon)
        if ARMOR[slot] then
            return probability_armor
        elseif WEAPON[slot] then
            return probability_weapon
        end
    end

    if quality == UNCOMMON then
        if level <= 10 then
            return T.temp-T.list(
	            T.temp-T.map('item_id', 10940, 'min_quantity', 1, 'max_quantity', 2, 'probability', p(.8, .2)),
	            T.temp-T.map('item_id', 10938, 'min_quantity', 1, 'max_quantity', 2, 'probability', p(.2, .8))
            )
        elseif level <= 15 then
            return T.temp-T.list(
	            T.temp-T.map('item_id', 10940, 'min_quantity', 2, 'max_quantity', 3, 'probability', p(.75, .2)),
	            T.temp-T.map('item_id', 10939, 'min_quantity', 1, 'max_quantity', 2, 'probability', p(.2, .75)),
	            T.temp-T.map('item_id', 10978, 'min_quantity', 1, 'max_quantity', 1, 'probability', .05)
            )
        elseif level <= 20 then
            return T.temp-T.list(
	            T.temp-T.map('item_id', 10940, 'min_quantity', 4, 'max_quantity', 6, 'probability', p(.75, .15)),
	            T.temp-T.map('item_id', 10998, 'min_quantity', 1, 'max_quantity', 2, 'probability', p(.15, .75)),
	            T.temp-T.map('item_id', 10978, 'min_quantity', 1, 'max_quantity', 1, 'probability', .10)
            )
        elseif level <= 25 then
            return T.temp-T.list(
	            T.temp-T.map('item_id', 11083, 'min_quantity', 1, 'max_quantity', 2, 'probability', p(.75, .2)),
	            T.temp-T.map('item_id', 11082, 'min_quantity', 1, 'max_quantity', 2, 'probability', p(.2, .75)),
	            T.temp-T.map('item_id', 11084, 'min_quantity', 1, 'max_quantity', 1, 'probability', .05)
			)
        elseif level <= 30 then
            return T.temp-T.list(
	            T.temp-T.map('item_id', 11083, 'min_quantity', 2, 'max_quantity', 5, 'probability', p(.75, .2)),
	            T.temp-T.map('item_id', 11134, 'min_quantity', 1, 'max_quantity', 2, 'probability', p(.2, .75)),
	            T.temp-T.map('item_id', 11138, 'min_quantity', 1, 'max_quantity', 1, 'probability', .05)
            )
        elseif level <= 35 then
            return T.temp-T.list(
	            T.temp-T.map('item_id', 11137, 'min_quantity', 1, 'max_quantity', 2, 'probability', p(.75, .2)),
	            T.temp-T.map('item_id', 11135, 'min_quantity', 1, 'max_quantity', 2, 'probability', p(.2, .75)),
	            T.temp-T.map('item_id', 11139, 'min_quantity', 1, 'max_quantity', 1, 'probability', .05)
            )
        elseif level <= 40 then
            return T.temp-T.list(
	            T.temp-T.map('item_id', 11137, 'min_quantity', 2, 'max_quantity', 5, 'probability', p(.75, .2)),
	            T.temp-T.map('item_id', 11174, 'min_quantity', 1, 'max_quantity', 2, 'probability', p(.2, .75)),
	            T.temp-T.map('item_id', 11177, 'min_quantity', 1, 'max_quantity', 1, 'probability', .05)
            )
        elseif level <= 45 then
            return T.temp-T.list(
	            T.temp-T.map('item_id', 11176, 'min_quantity', 1, 'max_quantity', 2, 'probability', p(.75, .2)),
	            T.temp-T.map('item_id', 11175, 'min_quantity', 1, 'max_quantity', 2, 'probability', p(.2, .75)),
	            T.temp-T.map('item_id', 11178, 'min_quantity', 1, 'max_quantity', 1, 'probability', .05)
            )
        elseif level <= 50 then
            return T.temp-T.list(
	            T.temp-T.map('item_id', 11176, 'min_quantity', 2, 'max_quantity', 5, 'probability', p(.75, .22)),
	            T.temp-T.map('item_id', 16202, 'min_quantity', 1, 'max_quantity', 2, 'probability', p(.2, .75)),
	            T.temp-T.map('item_id', 14343, 'min_quantity', 1, 'max_quantity', 1, 'probability', p(.05, .03))
            )
        elseif level <= 55 then
            return T.temp-T.list(
	            T.temp-T.map('item_id', 16204, 'min_quantity', 1, 'max_quantity', 2, 'probability', p(.75, .22)),
	            T.temp-T.map('item_id', 16203, 'min_quantity', 1, 'max_quantity', 2, 'probability', p(.2, .75)),
	            T.temp-T.map('item_id', 14344, 'min_quantity', 1, 'max_quantity', 1, 'probability', p(.05, .03))
			)
        elseif level <= 60 then
            return T.temp-T.list(
	            T.temp-T.map('item_id', 16204, 'min_quantity', 2, 'max_quantity', 5, 'probability', p(.75, .22)),
	            T.temp-T.map('item_id', 16203, 'min_quantity', 2, 'max_quantity', 3, 'probability', p(.2, .75)),
	            T.temp-T.map('item_id', 14344, 'min_quantity', 1, 'max_quantity', 1, 'probability', p(.05, .03))
			)
        end
    elseif quality == RARE then
        if level <= 20 then
            return T.temp-T.list(T.temp-T.map('item_id', 10978, 'min_quantity', 1, 'max_quantity', 1, 'probability', 1))
        elseif level <= 25 then
            return T.temp-T.list(T.temp-T.map('item_id', 11084, 'min_quantity', 1, 'max_quantity', 1, 'probability', 1))
        elseif level <= 30 then
            return T.temp-T.list(T.temp-T.map('item_id', 11138, 'min_quantity', 1, 'max_quantity', 1, 'probability', 1))
        elseif level <= 35 then
            return T.temp-T.list(T.temp-T.map('item_id', 11139, 'min_quantity', 1, 'max_quantity', 1, 'probability', 1))
        elseif level <= 40 then
            return T.temp-T.list(T.temp-T.map('item_id', 11177, 'min_quantity', 1, 'max_quantity', 1, 'probability', 1))
        elseif level <= 45 then
            return T.temp-T.list(T.temp-T.map('item_id', 11178, 'min_quantity', 1, 'max_quantity', 1, 'probability', 1))
        elseif level <= 50 then
            return T.temp-T.list(T.temp-T.map('item_id', 14343, 'min_quantity', 1, 'max_quantity', 1, 'probability', 1))
        elseif level <= 55 then
            return T.temp-T.list(T.temp-T.map('item_id', 14344, 'min_quantity', 1, 'max_quantity', 1, 'probability', .995), T.temp-T.map('item_id', 20725, 'min_quantity', 1, 'max_quantity', 1, 'probability', .005))
        elseif level <= 60 then
            return T.temp-T.list(T.temp-T.map('item_id', 14344, 'min_quantity', 1, 'max_quantity', 1, 'probability', .995), T.temp-T.map('item_id', 20725, 'min_quantity', 1, 'max_quantity', 1, 'probability', .005))
        end
    elseif quality == EPIC then
        if level <= 40 then
            return T.temp-T.list(T.temp-T.map('item_id', 11177, 'min_quantity', 2, 'max_quantity', 4, 'probability', 1))
        elseif level <= 45 then
            return T.temp-T.list(T.temp-T.map('item_id', 11178, 'min_quantity', 2, 'max_quantity', 4, 'probability', 1))
        elseif level <= 50 then
            return T.temp-T.list(T.temp-T.map('item_id', 14343, 'min_quantity', 2, 'max_quantity', 4, 'probability', 1))
        elseif level <= 55 then
            return T.temp-T.list(T.temp-T.map('item_id', 20725, 'min_quantity', 1, 'max_quantity', 1, 'probability', 1))
        elseif level <= 60 then
            return T.temp-T.list(T.temp-T.map('item_id', 20725, 'min_quantity', 1, 'max_quantity', 2, 'probability', 1))
        end
    end
    return T.acquire()
end