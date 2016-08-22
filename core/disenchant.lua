module 'disenchant'

UNCOMMON = 2
RARE = 3
EPIC = 4

do
	local data = {
		[10940] = {'DUST', '1-20'},
		[11083] = {'DUST', '21-30'},
		[11137] = {'DUST', '31-40'},
		[11176] = {'DUST', '41-50'},
		[16204] = {'DUST', '51-60'},

		[10938] = {'ESSENCE', '1-10'},
		[10939] = {'ESSENCE', '11-15'},
		[10998] = {'ESSENCE', '16-20'},
		[11082] = {'ESSENCE', '21-25'},
		[11134] = {'ESSENCE', '26-30'},
		[11135] = {'ESSENCE', '31-35'},
		[11174] = {'ESSENCE', '36-40'},
		[11175] = {'ESSENCE', '41-45'},
		[16202] = {'ESSENCE', '46-50'},
		[16203] = {'ESSENCE', '51-60'},

		[10978] = {'SHARD', '1-20'},
		[11084] = {'SHARD', '21-25'},
		[11138] = {'SHARD', '26-30'},
		[11139] = {'SHARD', '31-35'},
		[11177] = {'SHARD', '36-40'},
		[11178] = {'SHARD', '41-45'},
		[14343] = {'SHARD', '46-50'},
		[14344] = {'SHARD', '51-60'},

		[20725] = {'CRYSTAL', '51+'},
	}

	function public.source(item_id)
	    return unpack(data[item_id] or {})
	end
end

function LOAD()
	armor = set-from
		'INVTYPE_HEAD'
		'INVTYPE_NECK'
		'INVTYPE_SHOULDER'
		'INVTYPE_BODY'
		'INVTYPE_CHEST'
		'INVTYPE_ROBE'
		'INVTYPE_WAIST'
		'INVTYPE_LEGS'
		'INVTYPE_FEET'
		'INVTYPE_WRIST'
		'INVTYPE_HAND'
		'INVTYPE_FINGER'
		'INVTYPE_TRINKET'
		'INVTYPE_CLOAK'
		'INVTYPE_HOLDABLE'
	weapon = set-from
		'INVTYPE_2HWEAPON'
		'INVTYPE_WEAPONMAINHAND'
		'INVTYPE_WEAPON'
		'INVTYPE_WEAPONOFFHAND'
		'INVTYPE_SHIELD'
		'INVTYPE_RANGED'
		'INVTYPE_RANGEDRIGHT'
end

function public.value(slot, quality, level)
    local expectation
    for _, event in distribution(slot, quality, level) do
        local value = history.value(event.item_id..':'..0)
        if not value then
            return
        else
            expectation = (expectation or 0) + event.probability * (event.min_quantity + event.max_quantity) / 2 * value
        end
    end
    return expectation
end

function public.distribution(slot, quality, level)
    if not (armor(slot) or weapon(slot)) or level == 0 then
        return {}
    end

    local function p(probability_armor, probability_weapon)
        if armor(slot) then
            return probability_armor
        elseif weapon(slot) then
            return probability_weapon
        end
    end

    if quality == UNCOMMON then
        if level <= 10 then
            return {
                {item_id=10940, min_quantity=1, max_quantity=2, probability=p(0.8, 0.2)},
                {item_id=10938, min_quantity=1, max_quantity=2, probability=p(0.2, 0.8)},
            }
        elseif level <= 15 then
            return {
                {item_id=10940, min_quantity=2, max_quantity=3, probability=p(0.75, 0.2)},
                {item_id=10939, min_quantity=1, max_quantity=2, probability=p(0.2, 0.75)},
                {item_id=10978, min_quantity=1, max_quantity=1, probability=0.05},
            }
        elseif level <= 20 then
            return {
                {item_id=10940, min_quantity=4, max_quantity=6, probability=p(0.75, 0.15)},
                {item_id=10998, min_quantity=1, max_quantity=2, probability=p(0.15, 0.75)},
                {item_id=10978, min_quantity=1, max_quantity=1, probability=0.10},
            }
        elseif level <= 25 then
            return {
                {item_id=11083, min_quantity=1, max_quantity=2, probability=p(0.75, 0.2)},
                {item_id=11082, min_quantity=1, max_quantity=2, probability=p(0.2, 0.75)},
                {item_id=11084, min_quantity=1, max_quantity=1, probability=0.05},
            }
        elseif level <= 30 then
            return {
                {item_id=11083, min_quantity=2, max_quantity=5, probability=p(0.75, 0.2)},
                {item_id=11134, min_quantity=1, max_quantity=2, probability=p(0.2, 0.75)},
                {item_id=11138, min_quantity=1, max_quantity=1, probability=0.05},
            }
        elseif level <= 35 then
            return {
                {item_id=11137, min_quantity=1, max_quantity=2, probability=p(0.75, 0.2)},
                {item_id=11135, min_quantity=1, max_quantity=2, probability=p(0.2, 0.75)},
                {item_id=11139, min_quantity=1, max_quantity=1, probability=0.05},
            }
        elseif level <= 40 then
            return {
                {item_id=11137, min_quantity=2, max_quantity=5, probability=p(0.75, 0.2)},
                {item_id=11174, min_quantity=1, max_quantity=2, probability=p(0.2, 0.75)},
                {item_id=11177, min_quantity=1, max_quantity=1, probability=0.05},
            }
        elseif level <= 45 then
            return {
                {item_id=11176, min_quantity=1, max_quantity=2, probability=p(0.75, 0.2)},
                {item_id=11175, min_quantity=1, max_quantity=2, probability=p(0.2, 0.75)},
                {item_id=11178, min_quantity=1, max_quantity=1, probability=0.05},
            }
        elseif level <= 50 then
            return {
                {item_id=11176, min_quantity=2, max_quantity=5, probability=p(0.75, 0.22)},
                {item_id=16202, min_quantity=1, max_quantity=2, probability=p(0.2, 0.75)},
                {item_id=14343, min_quantity=1, max_quantity=1, probability=p(0.05, 0.03)},
            }
        elseif level <= 55 then
            return {
                {item_id=16204, min_quantity=1, max_quantity=2, probability=p(0.75, 0.22)},
                {item_id=16203, min_quantity=1, max_quantity=2, probability=p(0.2, 0.75)},
                {item_id=14344, min_quantity=1, max_quantity=1, probability=p(0.05, 0.03)},
            }
        elseif level <= 60 then
            return {
                {item_id=16204, min_quantity=2, max_quantity=5, probability=p(0.75, 0.22)},
                {item_id=16203, min_quantity=2, max_quantity=3, probability=p(0.2, 0.75)},
                {item_id=14344, min_quantity=1, max_quantity=1, probability=p(0.05, 0.03)},
            }
        end
    elseif quality == RARE then
        if level <= 20 then
            return {{item_id=10978, min_quantity=1, max_quantity=1, probability=1}}
        elseif level <= 25 then
            return {{item_id=11084, min_quantity=1, max_quantity=1, probability=1}}
        elseif level <= 30 then
            return {{item_id=11138, min_quantity=1, max_quantity=1, probability=1}}
        elseif level <= 35 then
            return {{item_id=11139, min_quantity=1, max_quantity=1, probability=1}}
        elseif level <= 40 then
            return {{item_id=11177, min_quantity=1, max_quantity=1, probability=1}}
        elseif level <= 45 then
            return {{item_id=11178, min_quantity=1, max_quantity=1, probability=1}}
        elseif level <= 50 then
            return {{item_id=14343, min_quantity=1, max_quantity=1, probability=1}}
        elseif level <= 55 then
            return {{item_id=14344, min_quantity=1, max_quantity=1, probability=0.995}, {item_id=20725, min_quantity=1, max_quantity=1, probability=0.005}}
        elseif level <= 60 then
            return {{item_id=14344, min_quantity=1, max_quantity=1, probability=0.995}, {item_id=20725, min_quantity=1, max_quantity=1, probability=0.005}}
        end
    elseif quality == EPIC then
        if level <= 40 then
            return {{item_id=11177, min_quantity=2, max_quantity=4, probability=1}}
        elseif level <= 45 then
            return {{item_id=11178, min_quantity=2, max_quantity=4, probability=1}}
        elseif level <= 50 then
            return {{item_id=14343, min_quantity=2, max_quantity=4, probability=1}}
        elseif level <= 55 then
            return {{item_id=20725, min_quantity=1, max_quantity=1, probability=1}}
        elseif level <= 60 then
            return {{item_id=20725, min_quantity=1, max_quantity=2, probability=1}}
        end
    end
    return {}
end