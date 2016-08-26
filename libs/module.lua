if module then return end
local type, setmetatable, setfenv, unpack, next, intersection, union, pcall, _G = type, setmetatable, setfenv, unpack, next, bit.band, bit.bor, pcall, getfenv(0)
local error, import_error, declaration_error, collision_error, mutability_error
local noop, id, const, start_declaration, declaration, env_mt, interface_mt, noop_mt

local PRIVATE, PUBLIC, PROPERTY = 0, 1, 2
local INDEX, NEWINDEX, CALL = 1, 2, 3
local _state = {}

function error(message, ...)
	return _G.error(format(message or '', unpack(arg))..'\n'..debugstack(), 0)
end
import_error = function() error 'Invalid imports.' end
declaration_error = function() error 'Invalid declaration.' end
collision_error = function(key) error('Field "%s" already exists.', key) end

function noop() end
function id(_) return _ end
--function vararg_id(...) return unpack(arg) end
function const(_) return function() return _ end end
--function vararg_const(...) return function() return unpack(arg) end end

do
	local function extract(v)
		local f, call, get, set
		call, get, set, v.call, v.get, v.set = v.call, v.get, v.set, nil, nil, nil
		if next(v) or call ~= nil and get ~= nil or set ~= nil and type(set) ~= 'function' then error() end
		if call ~= nil then f = call else f = get end
		return f, set
	end
	local function declare(self, modifiers, key, value)
		local metadata = self.metadata
		metadata[key] = metadata[key] and collision_error(key) or modifiers
		if intersection(PROPERTY, modifiers) == 0 then
			self.methods[key] = value
		else
			local success, f, mutator = pcall(extract, value)
			if success or declaration_error() then
				self.methods[key], self.mutators[key] = type(f) == 'function' and f or const(f), mutator or noop
			end
		end
	end

	declaration = noop
	do
		local MODIFIER = {private=PRIVATE, public=PUBLIC, property=PROPERTY}
		local state, modifiers, property
		local function intercept(self, type, key, value)
			if self ~= state then declaration_error() end
			if type == INDEX and (not property or declaration_error()) then
				local modifier = MODIFIER[key]
				if not modifier then modifier, property = PROPERTY, key end
				modifiers = union(modifiers, modifier)
				return true
			elseif type == NEWINDEX then
				if property then key, value = property, {[key]=value} end
				declare(self, union(modifiers, self.modifiers), key, value)
				declaration = noop
				return true
			elseif type == CALL then
				if property then declare(self, union(modifiers, self.modifiers), property, value) else self.modifiers = modifiers end
				declaration = noop
				return true
			end
		end
		function start_declaration(self, modifier)
			if declaration ~= noop then declaration_error() end
			declaration, state, modifiers, property = intercept, self, modifier, nil
		end
	end

	env_mt = {__metatable=false}
	function env_mt:__index(key, state) state=_state[self]
		if declaration(state, INDEX, key) then return self end
		if intersection(PROPERTY, state.metadata[key] or 0) ~= 0 then
			return state.getters[key]()
		else
			local value = state.methods[key]
			if value ~= nil then return value else return _G[key] end
		end
	end
	function env_mt:__newindex(key, value, state) state=_state[self]
		if declaration(state, NEWINDEX, key, value) then return end
		local modifiers = state.metadata[key]
		if modifiers then
			if intersection(PROPERTY, modifiers) ~= 0 then
				state.setters[key](value)
			end
		else
			declare(state, state.modifiers, key, value)
		end
	end
	function env_mt:__call(key, ...)
		declaration(_state[self], CALL, key, arg)
	end
end

interface_mt = {__metatable=false}
function interface_mt:__index(key, state) state=_state[self]
	local masked = intersection(PUBLIC+PROPERTY, state.metadata[key] or 0)
	if masked == PUBLIC+PROPERTY then
		return state.getters[key]()
	elseif masked == PUBLIC then
		return state.methods[key]
	end
end
function interface_mt:__newindex(key, value, state) state=_state[self]
	if intersection(PUBLIC+PROPERTY, state.metadata[key] or 0) == PUBLIC+PROPERTY then
		return state.setters[key](value)
--	elseif masked == PUBLIC and type(state.methods[key]) == 'function' then
--		return state.methods[key](value)
	end
end

noop_mt = {__index=function() return noop end}

function module(...)
	local state, env, interface
	env, interface = setmetatable({}, env_mt), setmetatable({}, interface_mt)
	state = {
		metadata = {_=PROPERTY, error=PRIVATE, noop=PRIVATE, _G=PRIVATE, M=PRIVATE, I=PRIVATE, private=PROPERTY, public=PROPERTY, property=PROPERTY},
		methods = setmetatable({
			_G = function() return _G end,
			M = function() return env end,
			I = function() return interface end,
			private = function() start_declaration(state, PRIVATE); return env end,
			public = function() start_declaration(state, PUBLIC); return env end,
			property = function() start_declaration(state, PROPERTY); return env end,
			error = error,
			noop = noop,
			id = id,
			const = const,
		}, noop_mt),
		setters = setmetatable({}, noop_mt),
		modifiers = PRIVATE,
	}
	for i=1,arg.n do
		local module = state[arg[i] or import_error()] or import_error()
		for k, v in module.metadata do
			if intersection(PUBLIC, v) ~= 0 and (not state.metadata[k] or import_error()) then
				state.metadata[k], state.methods[k], state.getters[k], state.setters[k] = v, module.methods[k], module.getters[k], module.setters[k]
			end
		end
	end
	_state[env], _state[interface] = state, state
	setfenv(2, env)
end