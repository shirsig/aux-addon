if module then return end
local type, setmetatable, setfenv, unpack, next, pcall, _G = type, setmetatable, setfenv, unpack, next, pcall, getfenv(0)
local start_declaration, declaration, env_mt, interface_mt

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

local _state, _public = {}, {[nop]=true}

do
	local function declare(self, public, type, name, value)
		if _G.type(value) ~= 'function' and (not type or declaration_error()) then value, type = const(value), INDEX end
		self[type][name] = self[type][name] and collision_error(name) or value
		_public[value] = public
	end

	declaration = nop
	do
		local function extract(v)
			local call, get, set
			call, get, set, v.call, v.get, v.set = v.call, v.get, v.set, nil, nil, nil
			if next(v) then error() end
			return call, get, set
		end
		local PUBLIC = {public=true, private=false}
		local PREFIX_TYPE = {method=CALL, getter=INDEX, setter=NEWINDEX}
		local SUFFIX_TYPE = {call=CALL, get=INDEX, set=NEWINDEX}
		local state, public, type, name
		local function intercept(self, event, key, value)
			if self ~= state then declaration_error() end
			if event == INDEX and (not name or declaration_error()) then
				if PUBLIC[key] then
					public = (public ~= nil and declaration_error()) or PUBLIC[key]
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
				declare(self, public, type, key, value)
				declaration = nop
				return true
			elseif event == CALL then
				if name then
					local success, call, get, set = pcall(extract, value)
					if not success then declaration_error() end
					if call then declare(self, public, type, name, call) end
					if get then declare(self, public, type, name, get) end
					if set then declare(self, public, type, name, set) end
				else
					self.access, self.type = public, type
				end
				declaration = nop
				return true
			end
		end
		function start_declaration(self, public, type)
			if declaration ~= nop then declaration_error() end
			declaration, state, public, type, name = intercept, self, public, type, nil
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
	local call = state[CALL][key]
	if call and _public[call] then
		return call
	else
		local index = state[INDEX][key]
		return (_public[index] and index or nop)()
	end
end
function interface_mt:__newindex(key, value) local state=_state[self]
	local f = state[NEWINDEX][key] or state[CALL][key] or nop
	if _public[f] then f(value) end
end
--function interface_mt:__call(key, ...) local state=_state[self]
--	-- TODO new instance
--end

noop_mt = {__index=function() return nop end}

function module(...)
	local env, interface = setmetatable({}, env_mt), setmetatable({}, interface_mt)
	local state; state = {
		[CALL]={error=error, nop=nop, id=id, const=const},
		[INDEX]={
			_G = const(_G),
			M = const(env),
			I = const(interface),
			private = function() start_declaration(state, false); return env end,
			public = function() start_declaration(state, true); return env end,
			accessor = function() start_declaration(state, nil, INDEX); return env end,
			mutator = function() start_declaration(state, nil, NEWINDEX); return env end,
		},
		[NEWINDEX]={},
		public=false,
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