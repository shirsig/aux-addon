select(2, ...) 'aux.core.disenchant'

local aux = require 'aux'
local history = require 'aux.core.history'

local UNCOMMON, RARE, EPIC = 2, 3, 4

local ARMOR = aux.set(
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
    'INVTYPE_HOLDABLE',
    'INVTYPE_SHIELD',
    'INVTYPE_RELIC'
)

local WEAPON = aux.set(
    'INVTYPE_2HWEAPON',
    'INVTYPE_WEAPONMAINHAND',
    'INVTYPE_WEAPON',
    'INVTYPE_WEAPONOFFHAND',
    'INVTYPE_RANGED',
    'INVTYPE_RANGEDRIGHT',
    'INVTYPE_THROWN'
)

do
    local item_ids = {
         1700,  4614, 11287, 11288, 11289, 11290, 13209, 16315, 16334, 16336, 16337, 16340, 18348, 18492, 18584, 18665, 18703, 18704,
        18708, 18713, 18715, 18724, 18834, 18845, 18846, 18849, 18850, 18851, 18852, 18853, 18854, 18856, 18857, 18858, 18859,
        18862, 18863, 18864, 19574, 19575, 19576, 19577, 19579, 19585, 19586, 19588, 19591, 19592, 19593, 19594, 19598, 19599,
        19600, 19601, 19602, 19603, 19604, 19605, 19606, 19607, 19608, 19609, 19610, 19611, 19612, 19613, 19614, 19615, 19616,
        19617, 19618, 19619, 19620, 19621, 19812, 19822, 19823, 19824, 19825, 19826, 19827, 19828, 19829, 19830, 19831, 19832,
        19833, 19834, 19835, 19836, 19838, 19839, 19840, 19841, 19842, 19843, 19845, 19846, 19848, 19849, 20033, 20034, 20402,
        20406, 20407, 20408, 20644, 20949, 21103, 21104, 21105, 21106, 21107, 21108, 21109, 21110, 21176, 21189, 21190, 21196,
        21197, 21198, 21199, 21200, 21201, 21202, 21203, 21204, 21205, 21206, 21207, 21208, 21209, 21210, 21218, 21220, 21221,
        21321, 21323, 21324, 21392, 21393, 21394, 21395, 21396, 21397, 21398, 21399, 21400, 21401, 21402, 21403, 21404, 21405,
        21406, 21407, 21408, 21409, 21410, 21411, 21412, 21413, 21414, 21415, 21416, 21417, 21418, 21766, 22373, 22374, 22375,
        22376, 22727, 22985, 22986, 22987, 22990, 22991, 22992, 22993, 23205, 23206, 23207, 23218, 23239, 23248, 23270, 23458,
        23459, 23462, 23705, 23709, 23720, 23767, 25823, 25824, 25825, 25826, 25835, 25836, 25838, 28155, 28158, 28162, 28164,
        28234, 28235, 28236, 28237, 28238, 28239, 28240, 28241, 28242, 28243, 29115, 29116, 29117, 29118, 29119, 29121, 29122,
        29123, 29124, 29125, 29126, 29127, 29128, 29129, 29130, 29131, 29132, 29133, 29134, 29135, 29136, 29137, 29138, 29139,
        29140, 29141, 29142, 29143, 29144, 29147, 29148, 29151, 29152, 29153, 29155, 29156, 29165, 29166, 29167, 29168, 29169,
        29170, 29171, 29172, 29173, 29174, 29175, 29176, 29177, 29180, 29181, 29182, 29183, 29184, 29185, 29276, 29277, 29278,
        29280, 29281, 29282, 29283, 29284, 29285, 29286, 29288, 29289, 29291, 29294, 29297, 29298, 29301, 29302, 29305, 29307,
        29309, 29456, 29457, 29592, 29593, 30343, 30344, 30345, 30346, 30348, 30349, 30350, 30351, 30830, 30832, 30834, 30835,
        30836, 30841, 30847, 31113, 31245, 31341, 31778, 32148, 32485, 32486, 32487, 32488, 32489, 32490, 32491, 32492, 32493,
        32538, 32539, 32542, 32770, 32771, 33292, 33717, 33808, 33957, 33999, 34073, 34075, 34100, 34105, 34106, 34484, 34486,
        34648, 34649, 34650, 34651, 34652, 34653, 34655, 34656, 34657, 34658, 34659, 34665, 34666, 34667, 34670, 34671, 34672,
        34673, 34674, 34675, 34676, 34677, 34678, 34679, 34680, 35279, 35280, 35328, 35329, 35330, 35331, 35332, 35333, 35334,
        35335, 35336, 35337, 35338, 35339, 35340, 35341, 35342, 35343, 35344, 35345, 35346, 35347, 35356, 35357, 35358, 35359,
        35360, 35361, 35362, 35363, 35364, 35365, 35366, 35367, 35368, 35369, 35370, 35371, 35372, 35373, 35374, 35375, 35376,
        35377, 35378, 35379, 35380, 35381, 35382, 35383, 35384, 35385, 35386, 35387, 35388, 35389, 35390, 35391, 35392, 35393,
        35394, 35395, 35402, 35403, 35404, 35405, 35406, 35407, 35408, 35409, 35410, 35411, 35412, 35413, 35414, 35415, 35416,
        35464, 35465, 35466, 35467, 35468, 35469, 35470, 35471, 35472, 35473, 35474, 35475, 35476, 35477, 35478, 35494, 35495,
        35496, 35497, 35507, 35508, 35509, 35511, 36941, 37012, 37739, 37740, 37864, 37865, 38145, 38147, 38287, 38288, 38289,
        38290, 38309, 38310, 38311, 38312, 38313, 38314, 38452, 38453, 38454, 38455, 38456, 38457, 38458, 38459, 38460, 38461,
        38462, 38463, 38464, 38465, 38588, 38589, 38632, 38633, 38661, 38662, 38663, 38664, 38665, 38666, 38667, 38668, 38669,
        38670, 38671, 38672, 38674, 38675, 38683, 38707, 39208, 39320, 39322, 39370, 40476, 40477, 40483, 40643, 42630, 42631,
        42633, 42634, 42685, 42689, 42713, 42714, 42715, 42716, 42717, 43154, 43155, 43156, 43157, 43300, 43348, 43349, 44050,
        44051, 44052, 44053, 44054, 44055, 44057, 44058, 44059, 44060, 44061, 44062, 44073, 44074, 44104, 44106, 44108, 44109,
        44110, 44111, 44112, 44116, 44117, 44120, 44121, 44122, 44123, 44166, 44167, 44170, 44171, 44173, 44174, 44176, 44179,
        44180, 44181, 44182, 44183, 44187, 44188, 44189, 44190, 44191, 44192, 44193, 44194, 44195, 44196, 44197, 44198, 44199,
        44200, 44201, 44202, 44203, 44204, 44205, 44214, 44216, 44239, 44240, 44241, 44242, 44243, 44244, 44245, 44247, 44248,
        44249, 44250, 44256, 44257, 44258, 44283, 44295, 44296, 44297, 44302, 44303, 44305, 44306, 44447, 44448, 44579, 44597,
        44719, 44723, 44885, 45858, 49052, 49054, 49086, 49121, 49123, 49126, 49888, 50250, 50818, 51377, 51378, 51534, 52200,
        54801, 54802, 54803, 54804, 54805, 54811
    }
    IGNORE = {}
    for _, id in pairs(item_ids) do
        IGNORE[id] = true
    end
end

function M.value(item_id, slot, quality, level)
    local expectation
    for _, event in pairs(distribution(item_id, slot, quality, level)) do
        local value = history.value(event.item_id .. ':' .. 0)
        expectation = (expectation or 0) + event.probability * (event.min_quantity + event.max_quantity) / 2 * (value or 0)
    end
    return expectation
end

function M.distribution(item_id, slot, quality, level)
    assert(item_id, '`item_id` parameter is mandatory')
    if IGNORE[item_id] or not ARMOR[slot] and not WEAPON[slot] or level == 0 then
        return {}
    end

    local function probability(probability_armor, probability_weapon)
        if ARMOR[slot] then
            return probability_armor
        elseif WEAPON[slot] then
            return probability_weapon
        end
    end

    if quality == UNCOMMON then
        if level <= 15 then
            return {
	            { item_id = 10940, min_quantity = 1, max_quantity = 2, probability = probability(.8, .2) },
	            { item_id = 10938, min_quantity = 1, max_quantity = 2, probability = probability(.2, .8) },
            }
        elseif level <= 20 then
            return {
	            { item_id = 10940, min_quantity = 2, max_quantity = 3, probability = probability(.75, .2) },
	            { item_id = 10939, min_quantity = 1, max_quantity = 2, probability = probability(.2, .75) },
	            { item_id = 10978, min_quantity = 1, max_quantity = 1, probability = .05 },
            }
        elseif level <= 25 then
            return {
	            { item_id = 10940, min_quantity = 4, max_quantity = 6, probability = probability(.75, .15) },
	            { item_id = 10998, min_quantity = 1, max_quantity = 2, probability = probability(.15, .75) },
	            { item_id = 10978, min_quantity = 1, max_quantity = 1, probability = .10 },
            }
        elseif level <= 30 then
            return {
	            { item_id = 11083, min_quantity = 1, max_quantity = 2, probability = probability(.75, .2) },
	            { item_id = 11082, min_quantity = 1, max_quantity = 2, probability = probability(.2, .75) },
	            { item_id = 11084, min_quantity = 1, max_quantity = 1, probability = .05 },
			}
        elseif level <= 35 then
            return {
	            { item_id = 11083, min_quantity = 2, max_quantity = 5, probability = probability(.75, .2) },
	            { item_id = 11134, min_quantity = 1, max_quantity = 2, probability = probability(.2, .75) },
	            { item_id = 11138, min_quantity = 1, max_quantity = 1, probability = .05 },
            }
        elseif level <= 40 then
            return {
	            { item_id = 11137, min_quantity = 1, max_quantity = 2, probability = probability(.75, .2) },
	            { item_id = 11135, min_quantity = 1, max_quantity = 2, probability = probability(.2, .75) },
	            { item_id = 11139, min_quantity = 1, max_quantity = 1, probability = .05 },
            }
        elseif level <= 45 then
            return {
	            { item_id = 11137, min_quantity = 2, max_quantity = 5, probability = probability(.75, .2) },
	            { item_id = 11174, min_quantity = 1, max_quantity = 2, probability = probability(.2, .75) },
	            { item_id = 11177, min_quantity = 1, max_quantity = 1, probability = .05 },
            }
        elseif level <= 50 then
            return {
	            { item_id = 11176, min_quantity = 1, max_quantity = 2, probability = probability(.75, .2) },
	            { item_id = 11175, min_quantity = 1, max_quantity = 2, probability = probability(.2, .75) },
	            { item_id = 11178, min_quantity = 1, max_quantity = 1, probability = .05 },
            }
        elseif level <= 55 then
            return {
	            { item_id = 11176, min_quantity = 2, max_quantity = 5, probability = probability(.75, .22) },
	            { item_id = 16202, min_quantity = 1, max_quantity = 2, probability = probability(.2, .75) },
	            { item_id = 14343, min_quantity = 1, max_quantity = 1, probability = probability(.05, .03) },
            }
        elseif level <= 60 then
            return {
	            { item_id = 16204, min_quantity = 1, max_quantity = 2, probability = probability(.75, .22) },
	            { item_id = 16203, min_quantity = 1, max_quantity = 2, probability = probability(.2, .75) },
	            { item_id = 14344, min_quantity = 1, max_quantity = 1, probability = probability(.05, .03) },
            }
        elseif level <= 65 then
            return {
                { item_id = 16204, min_quantity = 2, max_quantity = 5, probability = probability(.75, .22) },
                { item_id = 16203, min_quantity = 2, max_quantity = 3, probability = probability(.2, .75) },
                { item_id = 14344, min_quantity = 1, max_quantity = 1, probability = probability(.05, .03) },
            }
        elseif level <= 79 then
            return {
                { item_id = 22445, min_quantity = 1, max_quantity = 3, probability = probability(.75, .22) },
                { item_id = 22447, min_quantity = 1, max_quantity = 3, probability = probability(.22, .75) },
                { item_id = 22448, min_quantity = 1, max_quantity = 1, probability = probability(.03, .03) },
            }
        elseif level <= 99 then
            return {
                { item_id = 22445, min_quantity = 2, max_quantity = 3, probability = probability(.75, .22) },
                { item_id = 22447, min_quantity = 2, max_quantity = 3, probability = probability(.22, .75) },
                { item_id = 22448, min_quantity = 1, max_quantity = 1, probability = probability(.03, .03) },
            }
        elseif level <= 120 then
            return {
	            { item_id = 22445, min_quantity = 2, max_quantity = 5, probability = probability(.75, .22) },
	            { item_id = 22446, min_quantity = 1, max_quantity = 2, probability = probability(.22, .75) },
	            { item_id = 22449, min_quantity = 1, max_quantity = 1, probability = probability(.03, .03) },
            }
        elseif level <= 151 then
            return {
                { item_id = 34054, min_quantity = 2, max_quantity = 3, probability = probability(.75, .22) },
                { item_id = 34056, min_quantity = 1, max_quantity = 3, probability = probability(.22, .75) },
                { item_id = 34053, min_quantity = 1, max_quantity = 1, probability = probability(.03, .03) },
            }
        else
            return {
                { item_id = 34054, min_quantity = 4, max_quantity = 7, probability = probability(.75, .22) },
                { item_id = 34055, min_quantity = 1, max_quantity = 2, probability = probability(.22, .75) },
                { item_id = 34052, min_quantity = 1, max_quantity = 1, probability = probability(.03, .03) },
            }
        end
    elseif quality == RARE then
        if level <= 25 then
            return {
                { item_id = 10978, min_quantity = 1, max_quantity = 1, probability = 1 },
            }
        elseif level <= 30 then
            return {
                { item_id = 11084, min_quantity = 1, max_quantity = 1, probability = 1 },
            }
        elseif level <= 35 then
            return {
                { item_id = 11138, min_quantity = 1, max_quantity = 1, probability = 1 },
            }
        elseif level <= 40 then
            return {
                { item_id = 11139, min_quantity = 1, max_quantity = 1, probability = 1 },
            }
        elseif level <= 45 then
            return {
                { item_id = 11177, min_quantity = 1, max_quantity = 1, probability = 1 },
            }
        elseif level <= 50 then
            return {
                { item_id = 11178, min_quantity = 1, max_quantity = 1, probability = 1 },
            }
        elseif level <= 55 then
            return {
                { item_id = 14343, min_quantity = 1, max_quantity = 1, probability = 1 },
            }
        elseif level <= 65 then
            return {
                { item_id = 14344, min_quantity = 1, max_quantity = 1, probability = .995 },
                { item_id = 20725, min_quantity = 1, max_quantity = 1, probability = .005 },
            }
        elseif level <= 99 then
            return {
                { item_id = 22448, min_quantity = 1, max_quantity = 1, probability = .995 },
                { item_id = 20725, min_quantity = 1, max_quantity = 1, probability = .005 },
            }
        elseif level <= 115 then
            return {
                { item_id = 22449, min_quantity = 1, max_quantity = 1, probability = .995 },
                { item_id = 22450, min_quantity = 1, max_quantity = 1, probability = .005 },
            }
        elseif level <= 164 then
            return {
                { item_id = 34053, min_quantity = 1, max_quantity = 1, probability = .995 },
                { item_id = 34057, min_quantity = 1, max_quantity = 1, probability = .005 },
            }
        else
            return {
                { item_id = 34052, min_quantity = 1, max_quantity = 1, probability = .995 },
                { item_id = 34057, min_quantity = 1, max_quantity = 1, probability = .005 },
            }
        end
    elseif quality == EPIC then
        if level <= 45 then
            return {
                { item_id = 11177, min_quantity = 2, max_quantity = 4, probability = 1 },
            }
        elseif level <= 50 then
            return {
                { item_id = 11178, min_quantity = 2, max_quantity = 4, probability = 1 },
            }
        elseif level <= 55 then
            return {
                { item_id = 14343, min_quantity = 2, max_quantity = 4, probability = 1 },
            }
        elseif level <= 60 then
            return {
                { item_id = 20725, min_quantity = 1, max_quantity = 1, probability = 1 },
            }
        elseif level <= 75 then
            return {
                { item_id = 20725, min_quantity = 1, max_quantity = 2, probability = 1 },
            }
        elseif level <= 80 then
            return {
                { item_id = 20725, min_quantity = 1, max_quantity = 1, probability = probability(.5, .33) },
                { item_id = 20725, min_quantity = 2, max_quantity = 2, probability = probability(.5, .67) },
            }
        elseif level <= 100 then
            return {
                { item_id = 22450, min_quantity = 1, max_quantity = 2, probability = 1 },
            }
        elseif level <= 164 then
            return {
                { item_id = 22450, min_quantity = 1, max_quantity = 1, probability = .33 },
                { item_id = 22450, min_quantity = 2, max_quantity = 2, probability = .67 },
            }
        elseif level <= 200 then
            return {
                { item_id = 34057, min_quantity = 1, max_quantity = 1, probability = 1 },
            }
        else
            return {
                { item_id = 34057, min_quantity = 1, max_quantity = 2, probability = 1 },
            }
        end
    end
    return {}
end
