local DATABASE_VERSION = 0

local private, public = {}, {}
Aux.persistence = public

aux_database = {}

function public.on_load()
    private.perform_migration(aux_database)
    aux_database.version = DATABASE_VERSION
end

function private.perform_migration()

end

function private.get_dataset_key()
	local realm = GetCVar('realmName')
	local zone = GetMinimapZoneText()
	local faction
    -- TODO use UnitFactionGroup(unit) or race with auctioneer instead to work for all locales
	if zone == 'Gadgetzan' or zone == 'Everlook' or zone == 'Booty Bay' then
		faction = 'Neutral'
	else
		faction = UnitFactionGroup('player')
	end
	return realm..'|'..faction
end

function public.load_dataset()
    local dataset_key = private.get_dataset_key()
    aux_database[dataset_key] = aux_database[dataset_key] or {}
    return aux_database[dataset_key]
end

function public.load_snapshot()
    local dataset = public.load_dataset()
    dataset.snapshot = dataset.snapshot or {}
    local snapshot = private.snapshot(dataset.snapshot)
    return snapshot
end

--function public.load_scan_records(item_key)
--    local dataset = private.load_dataset()
--
--    local serialized_records = private.deserialize(dataset[item_key] or '', ';')
--    return Aux.util.map(serialized_records, function(serialized_record)
--        local time, count, min_price, accumulated_price = private.deserialize(serialized_record, '#')
--        return {
--            time = time,
--            count = count,
--            min_price = min_price,
--            accumulated_price = accumulated_price,
--        }
--    end)
--end
--
--function public.store_scan_record(item_key, record)
--    local dataset = private.load_dataset()
--    local serialized_record = private.serialize({ record.time, record.count, record.min_price, record.accumulated_price }, '#')
--    local serialized_records = dataset[item_key] or ''
--    serialized_records = serialized_records..(serialized_records == '' and '' or ';')..serialized_record
--    dataset[item_key] = serialized_records
--end

function public.serialize(data, separator)
    local data_string = ''
    for i, datum in ipairs(data) do
        data_string = data_string..(i == 1 and '' or separator)..datum
    end
    return data_string
end

function public.deserialize(data_string, separator)
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

function private.snapshot(data)
    local self = {}

    function self.add(signature, duration)
        local HOUR = 60 * 60 * 60
        local seconds
        if duration == 1 then
            seconds = HOUR / 2
        elseif duration == 2 then
            seconds = HOUR * 2
        elseif duration == 3 then
            seconds = HOUR * 8
        elseif duration == 4 then
            seconds = HOUR * 24
        end
        data[signature] = time() + seconds
    end

    function self.contains(signature)
        return data[signature] ~= nil and data[signature] >= time()
    end

    function self.signatures()
        local signatures = {}
        for signature, _ in pairs(data) do
            if data[signature] >= time() then
                tinsert(signatures, signature)
            end
        end
        return signatures
    end

    return self
end
