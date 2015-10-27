local on_load, load_dataset, new_dataset, get_dataset_key, get_snapshot, save_snapshot, get_item_record, save_item_record
local encode_median_list, decode_median_list, serialize, deserialize, deserializing_iterator

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
        snapshot = '',
        scan_data = '',
        item_data = {},
    }
end

function load_dataset()
    local dataset_key = get_dataset_key()
    aux_database[dataset_key] = aux_database[dataset_key] or new_dataset()
    return aux_database[dataset_key]
end

function get_snapshot()
    local dataset = load_dataset()
    local signatures = deserialize(dataset.snapshot, '#')
    local snapshot = Aux.util.set()
    snapshot.add_all(signatures)
    return snapshot
end

function save_snapshot(snapshot)
	local dataset = load_dataset()
    dataset.snapshot = serialize(snapshot.values(), '#')
end

--function load_scan_data()
--
--end
--
--function store_scan_data()
--
--end

function get_item_record(item_key)
    local dataset = load_dataset()

    if dataset.item_data[item_key] then
        local serialized_record = dataset.item_data[item_key]
        local count, accumulated_price, encoded_price_list = unpack(deserialize(serialized_record, '|'))
        local price_list = decode_median_list(encoded_price_list)

        return {
            count = count,
            accumulated_price = accumulated_price,
            price_list = price_list
        }
    end
end

function save_item_record(item_key, record)
    local dataset = load_dataset()

    local encoded_price_list = encode_median_list(record.price_list)
    local serialized_record = serialize({record.count, record.acumulated_price, encoded_price_list}, '|')

    dataset.item_data[item_key] = serialized_record
end

--    AuctionConfig.data[auctKey][itemKey] = string.format("%s|%s", iData.data, hist);
--    AuctionConfig.info[itemKey] = string.format("%s|%s", iData.category, iData.name);
--    Auctioneer.Storage.SetHistMed(auctKey, itemKey, Auctioneer.Statistic.GetMedian(iData.buyoutPricesHistoryList))

function encode_median_list(list)
    local encoded_list = ''
    local function extend(last, n)
        if n == 1 then
            encoded_list = encoded_list == '' and last or string.format('%s:%d', encoded_list, last)
        elseif n > 1 then
            encoded_list = encoded_list == '' and string.format('%dx%d', last, n) or string.format('%s:%dx%d', encoded_list, last, n)
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

function decode_median_list(str)
    local array = {}
    for x, c in string.gfind(str, '([^%:]*)(%:?)') do
        local _, _, y, n = strfind(x, '(%d*)x(%d*)')
        if y == nil then
            tinsert(array, tonumber(x))
        else
            for i = 1,n do
                tinsert(array, tonumber(y))
            end
        end
        if c == '' then break end
    end
    return array
end

function serialize(data, separator)
    local data_string = ''
    for i, datum in ipairs(data) do
        data_string = data_string..(i == 1 and separator or '')..datum
    end
    return data_string
end

function deserialize(data_string, separator)
    local data = {}
    while true do
        local start_index, _ = strfind(data_string, separator, 1, true)
        if start_index then
            local datum = string.sub(data_string, 1, start_index - 1)
            tinsert(data, datum)
            data_string = string.sub(data_string, start_index + 1, strlen(data_string))
        else
            return data
        end
    end
end

function deserializing_iterator(data_string, separator)
    return function()
        local start_index, _ = strfind(data_string, separator, 1, true)
        if start_index then
            local datum = string.sub(data_string, 1, start_index - 1)
            data_string = string.sub(data_string, start_index, strlen(data_string))
            return datum
        end
    end
end

Aux.persistence = {
    get_item_record = get_item_record,
    save_item_record = save_item_record,
    get_snapshot = get_snapshot,
    save_snapshot = save_snapshot,
}