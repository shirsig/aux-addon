local type, setmetatable, setfenv, unpack, next, mask, combine, pcall, _G = type, setmetatable, setfenv, unpack, next, bit.band, bit.bor, pcall, getfenv(0)
local error, import_error, declaration_error, collision_error, mutability_error
local pass, env_mt, interface_mt, declarator_mt, importer_mt

local NULL, PRIVATE, PUBLIC, MUTABLE, DYNAMIC, PROPERTY = 0, 1, 2, 4, 8, 16
local INDEX, NEWINDEX, CALL = 1, 2, 4
local _state, _env_state = {}, {}

function error(message, ...)
	return _G.error(format(message or '', unpack(arg))..'\n'..debugstack(), 0)
end
import_error = function() error 'Invalid imports.' end
declaration_error = function() error 'Invalid declaration.' end
collision_error = function(key) error('Field "%s" already exists.', key) end
mutability_error = function(key) error('Field "%s" is immutable.', key) end

pass = function() end

do
	local mt = {__metatable=false}
	do
		local MODIFIER = {private=PRIVATE, public=PUBLIC, mutable=MUTABLE, dynamic=DYNAMIC, property=PROPERTY}
		local COMPATIBLE = {private=MUTABLE+PROPERTY, public=DYNAMIC+PROPERTY, mutable=PRIVATE, dynamic=PUBLIC+PROPERTY, property=PUBLIC}
		function mt:__call(state, type, key, value)
			if type == INDEX then
				if state.property then declaration_error() end
				local modifiers, modifier, compatible = state.modifiers, MODIFIER[key], COMPATIBLE[key]
				if not modifier then modifier, compatible, state.property = PROPERTY, PUBLIC, key end
				if mask(compatible, modifiers) ~= modifiers then declaration_error() end
				state.properties = modifiers + modifier
				return true
			elseif type == NEWINDEX then
				local property, modifiers; property, modifiers, state.modifiers = state.property, state.modifiers, PRIVATE
				if property then key, value, state.property = property, {[key]=value}, nil end
				declare(state.module, modifiers, key, value)
			elseif type == CALL then
				local property, modifiers; property, modifiers, state.modifiers = state.property, state.modifiers, PRIVATE
				if property then state.property = nil; declare(state, modifiers, property, value) else state.modifiers = modifiers end
			end
		end
	end
	local declarator = setmetatable({}, declarator_mt)
end

do
	local function dynamize(f)
		return function(...) setfenv(f, getfenv(2)); return f(unpack(arg)) end
	end
	local function unpack_property_value(t)
		local get, set; get, set, t.get, t.set = t.get or pass, t.set or pass, nil, nil
		if next(t) or type(get) ~= 'function' or type(set) ~= 'function' then error() end
		return get, set
	end
	local function declare(state, modifiers, key, value)
		local metadata, dynamic, property = state.metadata, mask(DYNAMIC, modifiers) ~= 0, mask(PROPERTY, modifiers) ~= 0
		metadata[key] = metadata[key] and collision_error(key) or modifiers
		if property then
			local success, getter, setter = pcall(unpack_property_value, value)
			if success or declaration_error() then
				if dynamic then getter, setter = dynamize(getter), dynamize(setter) end
				state.getters[key], state.setters[key] = getter, setter
			end
		else
			if dynamic and (type(value) == 'function' or declaration_error()) then value = dynamize(value) end
			state.data[key] = value
		end
	end

	env_mt = {__metatable=false}
	function env_mt:__index(key, state) state=_state[self]
		if state.intercept(INDEX, key) then return self end
		if mask(PROPERTY, state.metadata[key] or 0) ~= 0 then
			return state.getters[key]()
		else
			local value = state.data[key]
			if value ~= nil then return value else return _G[key] end
		end
	end
	function env_mt:__newindex(key, value, state) state=_state[self]
		if state.intercept(NEWINDEX, key, value) then return end
		local modifiers = state.metadata[key]
		if modifiers then
			if mask(PROPERTY, modifiers) ~= 0 then
				state.setters[key](value)
			elseif mask(MUTABLE, modifiers) ~= 0 or mutability_error(key) then
				state.data[key] = value
			end
		else
			declare(state, state.modifiers, key, value)
		end
	end
	function env_mt:__call(key, ...)
		_state[self].intercept(CALL, key, arg); return self
	end
end

interface_mt = {__metatable=false}
function interface_mt:__index(key, state) state=_state[self]
	local masked = mask(PUBLIC+PROPERTY, state.metadata[key] or 0)
	if masked == PUBLIC+PROPERTY then
		return state.getters[key]()
	elseif masked == PUBLIC then
		return state.data[key]
	end
end
function interface_mt:__newindex(key, value, state) state=_state[self]
	local modifiers = state.metadata[key]
	if modifiers then
		if mask(PUBLIC+PROPERTY, modifiers) == PUBLIC+PROPERTY then
			return state.setters[key](value)
		elseif mask(PUBLIC, modifiers) ~= 0 then
			return state.data[key](value)
		end
	end
end

metadata_mt = {__index=function() return 0 end}
property_mt = {__index=function() return pass end}

local function create_module(...)
	local env_state, env, interface = setmetatable({}, env_mt), setmetatable({}, interface_mt)
	local state = {
		metadata = {_=PROPERTY, _G=PRIVATE, M=PRIVATE, error=PRIVATE, private=PROPERTY, public=PROPERTY, mutable=PROPERTY, dynamic=PROPERTY, property=PROPERTY},
		fields = {_G=_G, M=env, error=error},
		getters = setmetatable({
			private = function() state[declarator] = PRIVATE; return declarator end,
			public = function() state[declarator] = PUBLIC; return declarator end,
			mutable = function() state[declarator] = MUTABLE; return declarator end,
			dynamic = function() state[declarator] = DYNAMIC; return declarator end,
			property = function() state[declarator] = PROPERTY; return declarator end,
		}, property_mt),
		setters = setmetatable({}, property_mt),
	}
	for i=1,arg.n do
		local module = state[arg[i] or import_error()] or import_error()
		for k, v in module.metadata do
			if mask(PUBLIC, v) ~= 0 and (not state.metadata[k] or import_error()) then
				state.metadata[k], state.data[k], state.getters[k], state.setters[k] = v, module.data[k], module.getters[k], module.setters[k]
			end
		end
	end
	state[env], state[interface] = state, state
	return env, interface
--	-- TODO create_env (per module call)
end