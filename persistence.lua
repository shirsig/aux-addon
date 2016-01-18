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

function public.serialize(data, separator, compactor)
    local data_string = ''
    local i = 1
    while i <= getn(data) do
        local element, count = data[i], 0
        repeat
            count = count + 1
            i = i + 1
        until (not compactor) or data[i] ~= element
        local part = (count > 1 and compactor) and element..compactor..count or element
        data_string = data_string..(data_string == '' and '' or separator)..part
    end

    return data_string
end

function public.deserialize(data_string, separator, compactor)
    if data_string == '' then
        return {}
    end

    local data = {}
    while true do
        local start_index, _ = strfind(data_string, separator, 1, true)

        local part
        if start_index then
            part = string.sub(data_string, 1, start_index - 1)
            data_string = string.sub(data_string, start_index + 1, strlen(data_string))
        else
            part = string.sub(data_string, 1, strlen(data_string))
        end

        if compactor and strfind(part, compactor, 1, true) then
            local compactor_index, _ = strfind(part, compactor, 1, true)
            for i=1, tonumber(string.sub(part, compactor_index + 1, strlen(part))) do
               tinsert(data, string.sub(part, 1, compactor_index - 1))
            end
        else
            tinsert(data, part)
        end

        if not start_index then
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
