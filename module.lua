local type, setmetatable, setfenv, unpack, next, mask, combine, pcall, _G = type, setmetatable, setfenv, unpack, next, bit.band, bit.bor, pcall, getfenv(0)
local error, import_error, declaration_error, collision_error, mutability_error
local pass, env_mt, interface_mt, declarator_mt, importer_mt

module 'util' (
	a,
	b,
	c
)

import: util (a, b, c)

from 'util' import ()
import 'util' as 'kek'

local PRIVATE, PUBLIC, MUTABLE, DYNAMIC, PROPERTY = 1, 2, 4, 8, 16
local _state, _modules = {}, {}

function error(message, ...)
	return _G.error(format(message or '', unpack(arg))..'\n'..debugstack(), 0)
end
import_error = function() error 'Invalid import statement.' end
declaration_error = function() error 'Invalid declaration.' end
collision_error = function(key) error('Field "%s" already exists.', key) end
mutability_error = function(key) error('Field "%s" is immutable.', key) end

pass = function() end

generic_function_mt = {__metatable=false}
function generic_function_mt:__call()

end

do
	importer_mt = {__metatable=false}
	local function import(state, module, alias)
		if alias == '' then
			for key, modifiers in module.metadata do
				if not state.metadata[key] and mask(PUBLIC, modifiers) ~= 0 then
					state.metadata[key], state.data[key], state.getters[key], state.setters[key] = modifiers, module.data[key], module.getters[key], module.setters[key]
				end
			end
		elseif not state.metadata[alias] then
			state.metadata[alias], state.data[alias] = PRIVATE, module.interface
		end
	end
	function importer_mt:__index(key, state) state=_state[self]
		state[self] = key; return self
	end
	function importer_mt:__call(arg1, arg2, state) state=_state[self]
		local name, alias, module; name = arg2 or arg1 or import_error()
		alias, state[self] = state[self] or name, nil
		return pcall(import, state, _modules[name], alias) and self or import_error()
	end
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

	declarator_mt = {__metatable=false}
	do
		local MODIFIER = {private=PRIVATE, public=PUBLIC, mutable=MUTABLE, dynamic=DYNAMIC, property=PROPERTY}
		local COMPATIBLE = {private=MUTABLE+PROPERTY, public=DYNAMIC+PROPERTY, mutable=PRIVATE, dynamic=PUBLIC+PROPERTY, property=PUBLIC}
		function declarator_mt:__index(key, state) state=_state[self]
			if state.property then declaration_error() end
			local modifiers, modifier, compatible = state[self], MODIFIER[key], COMPATIBLE[key]
			if not modifier then modifier, compatible, state.property = PROPERTY, PUBLIC, key end
			if mask(compatible, modifiers) ~= modifiers then declaration_error() end
			state[self] = modifiers + modifier
			return self
		end
	end
	do
		function declarator_mt:__newindex(key, value, state) state=_state[self]
			local property, modifiers; property, modifiers, state[self] = state.property, state[self], PRIVATE
			if property then key, value, state.property = property, {[key]=value}, nil end
			declare(state, modifiers, key, value)
		end
		function declarator_mt:__call(value, state) state=_state[self]
			local property, modifiers; property, modifiers, state[self] = state.property, state[self], PRIVATE
			if property then state.property = nil; declare(state, modifiers, property, value) else state.modifiers = modifiers end
		end
	end

	env_mt = {__metatable=false}
	function env_mt:__index(key, state) state=_state[self]
		if state.intercept_index(key) then return end
		if mask(PROPERTY, state.metadata[key] or 0) ~= 0 then
			return state.getters[key]()
		else
			local value = state.data[key]
			if value ~= nil then return value else return _G[key] end
		end
	end
	function env_mt:__newindex(key, value, state) state=_state[self]
		if state.intercept_newindex(key, value) then return end
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
		_state[self].intercept_call(key, arg)
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

function module(name)
	if not _modules[name] then
		local env, interface, declarator, importer = setmetatable({}, env_mt), setmetatable({}, interface_mt), setmetatable({}, declarator_mt), setmetatable({}, importer_mt)
		local state = {
			env = env,
			interface = interface,
			modifiers = PRIVATE,
			metadata = {_=PROPERTY, _G=PRIVATE, M=PRIVATE, error=PRIVATE, import=PRIVATE, private=PROPERTY, public=PROPERTY, mutable=PROPERTY, dynamic=PROPERTY, property=PROPERTY},
			data = {_G=_G, M=env, error=error, import=importer},
			getters = {
				_ = pass,
				private = function() state[declarator] = PRIVATE; return declarator end,
				public = function() state[declarator] = PUBLIC; return declarator end,
				mutable = function() state[declarator] = MUTABLE; return declarator end,
				dynamic = function() state[declarator] = DYNAMIC; return declarator end,
				property = function() state[declarator] = PROPERTY; return declarator end,
			},
			setters = {_=pass, private=pass, public=pass, mutable=pass, dynamic=pass, property=pass},
		}
		_modules[name], _state[env], _state[interface], _state[declarator], _state[importer] = state, state, state, state, state
		importer [''] 'core' -- TODO
	end
	-- TODO create_env (per module call)
	setfenv(2, _modules[name].env)
end