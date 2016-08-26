if module then return end
local typeof, tostring, setmetatable, setfenv, unpack, next, pcall, _G = type, tostring, setmetatable, setfenv, unpack, next, pcall, getfenv(0)

local PUBLIC, PRIVATE = 1, 2
local GETTER, SETTER, FUNCTION = 1, 2, 3

local function error(msg, ...) return _G.error(format(msg or '', unpack(arg))..'\n'..debugstack(), 0) end
local function import_error() error 'Invalid imports.' end
local function declaration_error() error 'Invalid declaration.' end
local function collision_error(key) error('"%s" already exists.', key) end

local function nop() end
local function id(v) return v end
local function const(v) return function() return v end end

local _state = {}

local env_mt
do
	local ACCESS, TYPE = {public=PUBLIC, private=PRIVATE}, {call=FUNCTION, get=GETTER, set=SETTER}
	local declaration_index, declaration_newindex, declaration_call
	local _0, _1, _2 = 0, 1, 2
	local STATE, module, access, name
	do
		local extract, declare, reset
		function extract(v)
			local call, get, set
			call, get, set, v.call, v.get, v.set = v.call, v.get, v.set, nil, nil, nil
			if next(v) or call ~= nil and get ~= nil then error() end
			return call, get, set
		end
		function declare(self, access, name, data)
			self.access[name] = self.access[name] and collision_error(name) or access or self.default_access
			for type, value in data do
				self[type][name] = typeof(value) == 'function' and value or declaration_error()
			end
		end
		function reset()
			STATE, module, access, name = _0, nil, nil, nil
		end
		function declaration_index(self, key)
			if STATE == _0 then
				if not ACCESS[key] then return false end
				STATE, module, access = _1, self, ACCESS[key]
				STATE = _1; return true
			elseif STATE == _1 or declaration_error() then
				STATE, name = _2, key; return true
			end
		end
		function declaration_newindex(self, key, value)
			if STATE == _0 then
				if not self.access[key] then return false end
				STATE = _1; return true
			elseif STATE == _1 then
				local type
				if typeof(value) == 'function' then
					type = FUNCTION
				else
					type, value = GETTER, const(value == nil and tostring(value) or value)
				end
				declare(self, access, key, {[type]=value})
				reset(); return true
			elseif STATE == _2 or declaration_error() then
				declare(self, access, key, {[TYPE[key] or declaration_error()]=value})
				reset(); return true
			end
		end
		function declaration_call(self)
			if STATE == _1 then
				self.default_access = access
				reset(); return true
			elseif STATE == _2 or declaration_error() then
				local success, call, get, set = pcall(extract, value)
				if not success then declaration_error() end
				declare(self, access, name, {[FUNCTION]=call, [GETTER]=get, [SETTER]=set})
				reset(); return true
			end
		end
	end

	env_mt = {__metatable=false}
	function env_mt:__index(key) local state=_state[self]
		if declaration_index(state, key) then return self end
		local get = state[GETTER][key]
		if get then return get() end
		local f = state[FUNCTION][key]
		if f then return f else return _G[key] end
	end
	function env_mt:__newindex(key, value) local state=_state[self]
		if declaration_newindex(state, key, value) then return end
		local f = state[SETTER][key]
		if f then f(value); return end
	end
	function env_mt:__call(value)
		declaration_call(_state[self], value)
	end
end

local interface_mt = {__metatable=false}
function interface_mt:__index(key) local state=_state[self]
	if state.access[key] == PUBLIC then
		local index = state[GETTER][key]
		if index then return index() else return state[FUNCTION][key] end
	end
end
function interface_mt:__newindex(key, value) local state=_state[self]
	if state.access[key] == PUBLIC then (state[SETTER][key] or state[FUNCTION][key])(value) end
end

function module(...)
	local env, interface = setmetatable({}, env_mt), setmetatable({}, interface_mt)
	local access = {error=PRIVATE, nop=PRIVATE, id=PRIVATE, const=PRIVATE, _G=PRIVATE, M=PRIVATE, I=PRIVATE, public=PRIVATE, private=PRIVATE}
	local functions, getters, setters = {error=error, nop=nop, id=id, const=const}, {_G=const(_G), M=const(env), I=const(interface)}, {}
	for i=1,arg.n do
		local module = _state[arg[i] or import_error()] or import_error()
		local import_functions, import_getters, import_setters = module[FUNCTION], module[GETTER], module[SETTER]
		for k, v in module.access do
			if v == PUBLIC and (not access[k] or import_error()) then
				functions[k], getters[k], setters[k] = import_functions[k], import_getters[k], import_setters[k]
				access[k] = PRIVATE
			end
		end
	end
	local state = {access=access, [FUNCTION]=functions, [GETTER]=getters, [SETTER]=setters, default_access=PRIVATE}
	_state[env], _state[interface] = state, state
	setfenv(2, env)
end