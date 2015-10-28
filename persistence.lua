local on_load, load_dataset, new_dataset, get_dataset_key, get_snapshot, load_item_record, store_item_record, load_item_history, add_historical_point
local encode_median_list, decode_median_list, serialize, deserialize

local DATABASE_VERSION = 0

aux_database = {}

function on_load()
	perform_migration(aux_database)
    aux_database.version = DATABASE_VERSION
end

function get_dataset_key()
	local realm = GetCVar('realmName')
	local zone = GetMinimapZoneText()
	local faction
	if zone == 'Gadgetzan' or zone == 'Everlook' or zone == 'Booty Bay' then
		faction = 'Neutral'
	else
		faction = UnitFactionGroup('player')
	end
	return realm..'|'..faction
end

function new_dataset()
    return {
        snapshot = {},
        item_data = {},
        item_history = {}
    }
end

function load_dataset()
    local dataset_key = get_dataset_key()
    aux_database[dataset_key] = aux_database[dataset_key] or new_dataset()
    return aux_database[dataset_key]
end

function get_snapshot()
    local dataset = load_dataset()
    local snapshot = Aux.util.set()
    snapshot.set_data(dataset.snapshot)
    return snapshot
end

function load_item_history(item_key)
    local dataset = load_dataset()

    local serialized_points = deserialize(dataset.item_history(item_key) or '', ';')
    return Aux.util.map(serialized_points, function(serialized_point)
        local time, market_price = deserialize(serialized_point, '#')
        return { time=time, market_price=market_price }
    end)
end

function add_historical_point(item_key)
    local dataset = load_dataset()
    local serialized_historical_point = serialize({time(), Aux.history.get_market_value(item_key) }, '#')
    local serialized_history = dataset.item_history[item_key] or ''
    serialized_history = (serialized_history == '' and serialized_history..';' or '')..serialized_historical_point
    dataset.item_history[item_key] = serialized_history
end

function load_item_record(item_key)
    local dataset = load_dataset()

    if dataset.item_data[item_key] then
        local serialized_record = dataset.item_data[item_key]
        local count, accumulated_price, encoded_median_list = unpack(deserialize(serialized_record, '|'))
        assert(count and accumulated_price and encode_median_list)
        local median_list = decode_median_list(encoded_median_list)

        return {
            count = count,
            accumulated_price = accumulated_price,
            median_list = median_list
        }
    end
end

function store_item_record(item_key, record)
    local dataset = load_dataset()

    local encoded_median_list = encode_median_list(record.median_list)
    local serialized_record = serialize({record.count, record.accumulated_price, encoded_median_list}, '|')

    dataset.item_data[item_key] = serialized_record
end

function encode_median_list(list)
    local encoded_list = ''
    local function extend(value, count)
        if count == 1 then
            encoded_list = encoded_list == '' and value or string.format('%s:%d', encoded_list, value)
        elseif count > 1 then
            encoded_list = encoded_list == '' and string.format('%dx%d', value, count) or string.format('%s:%dx%d', encoded_list, value, count)
        end
    end
    local n = 0
    local last = 0
    for i, price in pairs(list) do
        if i == 1 then
            last = price
        elseif price ~= last then
            extend(last, n)
            last = price
            n = 0
        end
        n = n + 1
    end
    extend(last, n)
    return encoded_list
end

function decode_median_list(encoded_list)
    local array = {}
    for part, separator in string.gfind(encoded_list, '([^%:]*)(%:?)') do
        local _, _, value, count = strfind(part, '(%d*)x(%d*)')
        if not count then
            tinsert(array, tonumber(part))
        else
            for i = 1,count do
                tinsert(array, tonumber(value))
            end
        end
        if separator == '' then break end
    end
    return array
end

function serialize(data, separator)
    assert(getn(data) == 3)
    local data_string = ''
    for i, datum in ipairs(data) do
        data_string = data_string..(i == 1 and '' or separator)..datum
    end
    return data_string
end

function deserialize(data_string, separator)
    if data_string == '' then
        return {}
    end

    local data = {}
    while true do
        local start_index, _ = strfind(data_string, separator, 1, true)
        if start_index then
            tinsert(data, string.sub(data_string, 1, start_index - 1))
            data_string = string.sub(data_string, start_index + 1, strlen(data_string))
        else
            tinsert(data, string.sub(data_string, 1, strlen(data_string)))
            return data
        end
    end
end

Aux.persistence = {
    load_item_record = load_item_record,
    store_item_record = store_item_record,
    load_item_history = load_item_history,
    add_historical_point = add_historical_point,
    get_snapshot = get_snapshot,
}