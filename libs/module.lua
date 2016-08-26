if module then return end
local type, setmetatable, setfenv, unpack, next, pcall, _G = type, setmetatable, setfenv, unpack, next, pcall, getfenv(0)
local start_declaration, declaration, env_mt, interface_mt, noop_mt

local INDEX, NEWINDEX, CALL = 1, 2, 3

local function error(msg, ...) return _G.error(format(msg or '', unpack(arg))..'\n'..debugstack(), 0) end
local function import_error() error 'Invalid imports.' end
local function declaration_error() error 'Invalid declaration.' end
local function collision_error(key) error('"%s" already exists.', key) end

local function nop() end
local function id(_) return _ end
local function const(_) return function() return _ end end
--local function vararg_id(...) return unpack(arg) end
--local function vararg_const(...) return function() return unpack(arg) end end

local _state, _public, _type = {}, {}, {}

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
		if intersection(ACCESSOR, modifiers) == 0 then
			self.methods[key] = value
		else
			local success, f, mutator = pcall(extract, value)
			if success or declaration_error() then
				self.methods[key], self.mutators[key] = type(f) == 'function' and f or const(f), mutator or nop
			end
		end
	end

	declaration = nop
	do
		local PUBLIC = {public=true, private=false}
		local PREFIX_TYPE = {method=CALL, accessor=INDEX, mutator=NEWINDEX}
		local SUFFIX_TYPE = {call=CALL, get=INDEX, set=NEWINDEX}
		local state, access, type, name
		local function intercept(self, event, key, value)
			if self ~= state then declaration_error() end
			if event == INDEX and (not name or declaration_error()) then
				if ACCESS[key] then
					access = (access and declaration_error()) or ACCESS[key]
				elseif PREFIX_TYPE[key] then
					type = (type and declaration_error()) or PREFIX_TYPE[key]
				elseif not type or declaration_error() then
					name = key
				end
				return true
			elseif event == NEWINDEX then
				if name then
					type = SUFFIX_TYPE[key] or declaration_error()
					key = name
				end
				declare(self, access, type, key, value)
				declaration = nop
				return true
			elseif event == CALL then
				if name then declare(self, access, type, name, value) else self.access, self.type = access, type end
				declaration = nop
				return true
			end
		end
		function start_declaration(self, modifier)
			if declaration ~= nop then declaration_error() end
			declaration, state, modifiers, property = intercept, self, modifier, nil
		end
	end

	env_mt = {__metatable=false}
	function env_mt:__index(key) local state=_state[self]
		if declaration(state, INDEX, key) then return self end
		if intersection(PROPERTY, state.metadata[key] or 0) ~= 0 then
			return state.getters[key]()
		else
			local value = state.methods[key]
			if value ~= nil then return value else return _G[key] end
		end
	end
	function env_mt:__newindex(key, value) local state=_state[self]
		if declaration(state, NEWINDEX, key, value) then return end
		local modifiers = state.metadata[key]
		if modifiers then
			if intersection(PROPERTY, modifiers) ~= 0 then
				state.mutators[key](value)
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
function interface_mt:__index(key) local state=_state[self]
	local masked = intersection(PUBLIC+PROPERTY, state.metadata[key] or 0)
	if masked == PUBLIC+PROPERTY then
		return state.getters[key]()
	elseif masked == PUBLIC then
		return state.methods[key]
	end
end
function interface_mt:__newindex(key, value) local state=_state[self]
	if intersection(PUBLIC+PROPERTY, state.metadata[key] or 0) == PUBLIC+PROPERTY then
		return state.mutators[key](value)
	elseif masked == PUBLIC and type(state.methods[key]) == 'function' then
		return state.methods[key](value)
	end
end
function interface_mt:__call(key, ...) local state=_state[self]
	-- TODO new instance
end

noop_mt = {__index=function() return nop end}

function module(...)
	local state, env, interface
	env, interface = setmetatable({}, env_mt), setmetatable({}, interface_mt)
	state = {
		metadata = {_=ACCESSOR, error=PRIVATE, nop=PRIVATE, _G=PRIVATE, M=PRIVATE, I=PRIVATE, private=ACCESSOR, public=ACCESSOR, accessor=ACCESSOR},
		methods = setmetatable({
			_G = function() return _G end,
			M = function() return env end,
			I = function() return interface end,
			private = function() start_declaration(state, PRIVATE); return env end,
			public = function() start_declaration(state, PUBLIC); return env end,
			accessor = function() start_declaration(state, ACCESSOR); return env end,
			mutator = function() start_declaration(state, MUTATOR); return env end,
			error = error,
			nop = nop,
			id = id,
			const = const,
		}, noop_mt),
		mutators = setmetatable({}, noop_mt),
		modifiers = PRIVATE,
	}
	for i=1,arg.n do
		local module = state[arg[i] or import_error()] or import_error()
		for k, v in module.metadata do
			if intersection(PUBLIC, v) ~= 0 and (not state.metadata[k] or import_error()) then
				state.metadata[k], state.methods[k], state.mutators[k] = v, module.methods[k], module.mutators[k]
			end
		end
	end
	_state[env], _state[interface] = state, state
	setfenv(2, env)
end