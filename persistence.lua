local private, public = {}, {}
Aux.persistence = public

aux_datasets = {}

function public.on_load()
    Aux.control.as_soon_as(function() private.faction = UnitFactionGroup('player') return private.faction end, Aux.util.pass)
    private.realm = GetCVar('realmName')
end

function private.get_dataset_key()
	return private.realm..'|'..private.faction
end

function public.load_dataset()
    local dataset_key = private.get_dataset_key()
    aux_datasets[dataset_key] = aux_datasets[dataset_key] or {}
    return aux_datasets[dataset_key]
end

function private.read(type, str)
    if type == 'string' then
        return str
    elseif type == 'boolean' then
        return str == '1'
    elseif type == 'number' then
        return tonumber(str)
    end
end

function private.write(type, obj)
    if type == 'string' then
        return obj
    elseif type == 'boolean' then
        return obj and '1' or '0'
    elseif type == 'number' then
        return tostring(obj)
    end
end

function public.schema(separator, ...)
    return function(record)
        local fields
        local parts = Aux.util.split(record, separator)
        for i=1,arg.n do
            tinsert(fields, private.read(arg[i], parts[i]))
        end
        return fields
    end, function(fields)
        local parts = {}
        for i=1,arg.n do
            tinsert(parts, private.write(arg[i], fields[i]))
        end
        return Aux.util.join(parts, '#')
    end
end

function public.blizzard_boolean(boolean)
    return boolean and 1 or nil
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