if module then return end
local type, setmetatable, setfenv, unpack, next, intersection, union, pcall, _G = type, setmetatable, setfenv, unpack, next, bit.band, bit.bor, pcall, getfenv(0)
local error, import_error, declaration_error, collision_error, mutability_error
local noop, start_declaration, advance_declaration, env_mt, interface_mt, property_mt

local PRIVATE, PUBLIC, MUTABLE, PROPERTY = 0, 1, 2, 4
local INDEX, NEWINDEX, CALL = 1, 2, 3
local _state = {}

function error(message, ...)
	return _G.error(format(message or '', unpack(arg))..'\n'..debugstack(), 0)
end
import_error = function() error 'Invalid imports.' end
declaration_error = function() error 'Invalid declaration.' end
collision_error = function(key) error('Field "%s" already exists.', key) end
mutability_error = function(key) error('Field "%s" is immutable.', key) end

noop = function() end

do
	local function unpack_property_value(t)
		local get, set; get, set, t.get, t.set = t.get, t.set, nil, nil
		if next(t) or get ~= nil and type(get) ~= 'function' or set ~= nil and type(set) ~= 'function' then error() end
		return get, set
	end
	local function declare(state, modifiers, key, value)
		if intersection(MUTABLE, modifiers) * intersection(PUBLIC+PROPERTY, modifiers) ~= 0 then declaration_error() end
		local metadata = state.metadata
		metadata[key] = metadata[key] and collision_error(key) or modifiers
		if intersection(PROPERTY, modifiers) == 0 then
			state.fields[key] = value
		else
			local success, getter, setter = pcall(unpack_property_value, value)
			if success or declaration_error() then
				state.getters[key], state.setters[key] = getter, setter
			end
		end
	end

	advance_declaration = noop
	do
		local MODIFIER = {private=PRIVATE, public=PUBLIC, mutable=MUTABLE, property=PROPERTY}
		local state, modifiers, property
		local function intercept(_, key, value)
			if type == INDEX and (not property or declaration_error()) then
				local modifier = MODIFIER[key]
				if not modifier then modifier, property = PROPERTY, key end
				modifiers = union(modifiers, modifier)
				return true
			elseif type == NEWINDEX then
				if property then key, value = property, {[key]=value} end
				declare(state, union(modifiers, state.modifiers), key, value)
				advance_declaration = noop
				return true
			elseif type == CALL then
				if property then declare(state, union(modifiers, state.modifiers), property, value) else state.modifiers = modifiers end
				advance_declaration = noop
				return true
			end
		end
		function start_declaration(state, modifier)
			if advance_declaration ~= noop then declaration_error() end
			advance_declaration, state, modifiers, property = intercept, state, modifier, nil
		end
	end

	env_mt = {__metatable=false}
	function env_mt:__index(key, state) state=_state[self]
		if advance_declaration(INDEX, key) then return self end
		if intersection(PROPERTY, state.metadata[key] or 0) ~= 0 then
			return state.getters[key]()
		else
			local value = state.fields[key]
			if value ~= nil then return value else return _G[key] end
		end
	end
	function env_mt:__newindex(key, value, state) state=_state[self]
		if advance_declaration(NEWINDEX, key, value) then return end
		local modifiers = state.metadata[key]
		if modifiers then
			if intersection(PROPERTY, modifiers) ~= 0 then
				state.setters[key](value)
			elseif intersection(MUTABLE, modifiers) ~= 0 or mutability_error(key) then
				state.fields[key] = value
			end
		else
			declare(state, state.modifiers, key, value)
		end
	end
	function env_mt:__call(key, ...)
		advance_declaration(CALL, key, arg)
	end
end

interface_mt = {__metatable=false}
function interface_mt:__index(key, state) state=_state[self]
	local masked = intersection(PUBLIC+PROPERTY, state.metadata[key] or 0)
	if masked == PUBLIC+PROPERTY then
		return state.getters[key]()
	elseif masked == PUBLIC then
		return state.fields[key]
	end
end
function interface_mt:__newindex(key, value, state) state=_state[self]
	if intersection(PUBLIC+PROPERTY, state.metadata[key] or 0) == PUBLIC+PROPERTY then
		return state.setters[key](value)
--	elseif masked == PUBLIC and type(state.fields[key]) == 'function' then
--		return state.fields[key](value)
	end
end

property_mt = {__index=function() return noop end}

function module(...)
	local state, env, interface
	env, interface = setmetatable({}, env_mt), setmetatable({}, interface_mt)
	state = {
		metadata = {_=PROPERTY, error=PRIVATE, noop=PRIVATE, _G=PRIVATE, M=PRIVATE, I=PRIVATE, private=PROPERTY, public=PROPERTY, mutable=PROPERTY, property=PROPERTY},
		fields = {_G=_G, M=env, I=interface, error=error},
		getters = setmetatable({
			private = function() start_declaration(state, PRIVATE); return env end,
			public = function() start_declaration(state, PUBLIC); return env end,
			mutable = function() start_declaration(state, MUTABLE); return env end,
			property = function() start_declaration(state, PROPERTY); return env end,
		}, property_mt),
		setters = setmetatable({}, property_mt),
		modifiers = PRIVATE,
	}
	for i=1,arg.n do
		local module = state[arg[i] or import_error()] or import_error()
		for k, v in module.metadata do
			if intersection(PUBLIC, v) ~= 0 and (not state.metadata[k] or import_error()) then
				state.metadata[k], state.fields[k], state.getters[k], state.setters[k] = v, module.fields[k], module.getters[k], module.setters[k]
			end
		end
	end
	_state[env], _state[interface] = state, state
	setfenv(2, env)
end