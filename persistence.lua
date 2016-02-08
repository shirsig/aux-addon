local private, public = {}, {}
Aux.persistence = public

aux_database = {}

function public.on_load()
end

function private.get_dataset_key()
	local realm = GetCVar('realmName')
	local faction = UnitFactionGroup('player')
	return realm..'|'..faction
end

function public.load_dataset()
    local dataset_key = private.get_dataset_key()
    aux_database[dataset_key] = aux_database[dataset_key] or {}
    return aux_database[dataset_key]
end

function public.serialize(data, separator, compactor)
    local data_string = ''
    local i = 1
    while i <= getn(data) do
        local element, count = data[i], 1
        while compactor and data[i + 1] == element do
            count = count + 1
            i = i + 1
        end
        local part = count > 1 and element..compactor..count or element
        data_string = data_string..(i == 1 and '' or separator)..part
        i = i + 1
    end

    return data_string
end

function public.deserialize(data_string, separator, compactor)
    if not data_string or data_string == '' then
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