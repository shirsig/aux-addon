aux 'persistence'

_G.aux_datasets = t

do
	local dataset
	function public.dataset.get()
		if not dataset then
		    local dataset_key = format('%s|%s', GetCVar 'realmName', UnitFactionGroup 'player')
		    dataset = _G.aux_datasets[dataset_key] or t
		    _G.aux_datasets[dataset_key] = dataset
	    end
	    return dataset
	end
end

function public.read(schema, str)
    if schema == 'string' then
        return str
    elseif schema == 'boolean' then
        return str == '1'
    elseif schema == 'number' then
        return tonumber(str)
    elseif type(schema) == 'table' and schema[1] == 'list' then
        return read_list(schema, str)
    elseif type(schema) == 'table' and schema[1] == 'record' then
        return read_record(schema, str)
    else
        error('Invalid schema.', 2)
    end
end

function public.write(schema, obj)
    if schema == 'string' then
        return obj or ''
    elseif schema == 'boolean' then
        return obj and '1' or '0'
    elseif schema == 'number' then
        return obj and tostring(obj) or ''
    elseif type(schema) == 'table' and schema[1] == 'list' then
        return write_list(schema, obj)
    elseif type(schema) == 'table' and schema[1] == 'record' then
        return write_record(schema, obj)
    else
        error('Invalid schema.', 2)
    end
end

function public.read_list(schema, str)
    if str == '' then return t end
    local separator = schema[2]
    local element_type = schema[3]
    local parts = split(str, separator)
    return map(parts, function(part)
        return read(element_type, part)
    end)
end

function public.write_list(schema, list)
    local separator = schema[2]
    local element_type = schema[3]
    local parts = map(list, function(element)
        return write(element_type, element)
    end)
    return join(parts, separator)
end

function public.read_record(schema, str)
    local separator = schema[2]
    local record = t
    local parts = split(str, separator)
    for i=3,getn(schema) do
        local key, type = next(schema[i])
        record[key] = read(type, parts[i - 2])
    end
    return record
end

function public.write_record(schema, record)
    local separator = schema[2]
    local parts = tt
    for i=3,getn(schema) do
        local key, type = next(schema[i])
        tinsert(parts, write(type, record[key]))
    end
    return join(parts, separator)
end