module 'aux.util.persistence'

include 'T'
include 'aux'

_G.aux = {
	player = {},
	faction = {},
	realm = {},
	account = {},
}

do
	local cache = {}
	function LOAD()
		cache.account = aux.account
		do
			local key = format('%s|%s', GetCVar'realmName', UnitName'player')
			aux.player[key] = aux.player[key] or {}
			cache.player = aux.player[key]
		end
		do
			local key = GetCVar'realmName'
			aux.realm[key] = aux.realm[key] or {}
			cache.realm = aux.realm[key]
		end
	end
	function LOAD2()
		do
			local key = format('%s|%s', GetCVar'realmName', UnitFactionGroup'player')
			aux.faction[key] = aux.faction[key] or {}
			cache.faction = aux.faction[key]
		end
	end
	for scope in temp-S('player', 'faction', 'realm', 'account') do
		local scope = scope
		M[scope] = function(k)
			if not cache[scope] then error('Cache not ready', 2) end
			cache[scope][k] = cache[scope][k] or {}
			return cache[scope][k]
		end
	end
end

function M.read(schema, str)
    if schema == 'string' then
        return str
    elseif schema == 'boolean' then
        return str == '1'
    elseif schema == 'number' then
        return tonumber(str)
    elseif type(schema) == 'table' and schema[1] == 'list' then
        return temp-read_list(schema, str)
    elseif type(schema) == 'table' and schema[1] == 'tuple' then
        return temp-read_tuple(schema, str)
    else
        error('Invalid schema.', 2)
    end
end

function M.write(schema, obj)
    if schema == 'string' then
        return obj or ''
    elseif schema == 'boolean' then
        return obj and '1' or '0'
    elseif schema == 'number' then
        return obj and tostring(obj) or ''
    elseif type(schema) == 'table' and schema[1] == 'list' then
        return write_list(schema, obj)
    elseif type(schema) == 'table' and schema[1] == 'tuple' then
        return write_tuple(schema, obj)
    else
        error('Invalid schema.', 2)
    end
end

function read_list(schema, str)
    if str == '' then return T end
    local separator = schema[2]
    local element_type = schema[3]
    return map(split(str, separator), function(part)
        return read(element_type, part)
    end)
end

function write_list(schema, list)
    local separator = schema[2]
    local element_type = schema[3]
    local parts = map(temp-copy(list), function(element)
        return write(element_type, element)
    end)
    return join(parts, separator)
end

function read_tuple(schema, str)
    local separator = schema[2]
    local tuple = T
    local parts = temp-split(str, separator)
    for i = 3, getn(schema) do
        local key, type = next(schema[i])
        tuple[key] = read(type, parts[i - 2])
    end
    return tuple
end

function write_tuple(schema, tuple)
    local separator = schema[2]
    local parts = temp-T
    for i = 3 , getn(schema) do
        local key, type = next(schema[i])
        tinsert(parts, write(type, tuple[key]))
    end
    return join(parts, separator)
end