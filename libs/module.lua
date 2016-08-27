if module then return end
local typeof, tostring, setmetatable, setfenv, unpack, next, pcall, _G = type, tostring, setmetatable, setfenv, unpack, next, pcall, getfenv(0)

local PUBLIC, PRIVATE = 1, 2
local FUNCTION, GETTER, SETTER = 1, 2, 3

local function error(msg, ...) return _G.error(format(msg or '', unpack(arg))..'\n'..debugstack(), 0) end
local function import_error() error 'Invalid imports.' end
local function declaration_error() error 'Invalid declaration.' end
local function collision_error(key) error('"%s" already exists.', key) end

local function nop() end
local function const(v) return function() return v end end

local _state = {}

local declarator_mt = {__metatable=false}
do
	local ACCESS, TYPE = {public=PUBLIC, private=PRIVATE}, {call=FUNCTION, get=GETTER, set=SETTER}
	local function extract(v)
		local f, getter, setter
		f, getter, setter, v.call, v.get, v.set = v.call, v.get, v.set, nil, nil, nil
		if next(v) or f ~= nil and getter ~= nil then error() end
		return f, getter, setter
	end
	local function declare(state, access, name, data)
		state.access[name] = state.access[name] and collision_error(name) or access or state.default_access or declaration_error()
		for type, value in data do
			if typeof(value) ~= 'function' and (type == GETTER or declaration_error()) then
				value = const(value == nil and tostring(value) or value)
			end
			state[type][name] = value
		end
	end
	function declarator_mt:__index(key) local state=_state[self]
		if ACCESS[key] and not state.declaration_access then
			state.declaration_access = ACCESS[key]
		elseif not state.declaration_name or declaration_error() then
			state.declaration_name = typeof(key) == 'string' and key or declaration_error()
		end
		return self
	end
	function declarator_mt:__newindex(key, value) local state=_state[self]
		local name, type = state.declaration_name, nil
		if name then
			type = TYPE[key] or declaration_error()
		else
			name, type = key, typeof(value) == 'function' and FUNCTION or GETTER
		end
		declare(state, state.declaration_access, name, {[type]=value})
		state.declaration_access, state.declaration_name = nil, nil
	end
	function declarator_mt:__call(value) local state=_state[self]
		if state.declaration_name then
			local success, f, getter, setter = pcall(extract, value)
			if not success then declaration_error() end
			declare(state, state.declaration_access, state.declaration_name, {[FUNCTION]=f, [GETTER]=getter, [SETTER]=setter})
		elseif state.declaration_access or declaration_error() then
			state.default_access = state.declaration_access
		end
		state.declaration_access, state.declaration_name = nil, nil
	end
end

local env_mt = {__metatable=false}
function env_mt:__index(key) local state=_state[self]
	local getter = state[GETTER][key]
	if getter then return getter() end
	return state[FUNCTION][key] or _G[key] or state.declarator[key]
end
function env_mt:__newindex(key, value) local state=_state[self]
	if state.access[key] then
		local setter = state[SETTER][key]
		if setter then setter(value) end
	else
		state.declarator[key] = value
	end
end

local interface_mt = {__metatable=false}
function interface_mt:__index(key) local state=_state[self]
	if state.access[key] == PUBLIC then
		local getter = state[GETTER][key]
		if getter then return getter() else return state[FUNCTION][key] end
	end
end
function interface_mt:__newindex(key, value) local state=_state[self]
	if state.access[key] == PUBLIC then (state[SETTER][key] or nop)(value) end
end

function module(...)
	local state, declarator, env, interface, access, functions, getters, setters
	declarator, env, interface = setmetatable({}, declarator_mt), setmetatable({}, env_mt), setmetatable({}, interface_mt)
	access = {error=PRIVATE, nop=PRIVATE, _G=PRIVATE, M=PRIVATE, I=PRIVATE, public=PRIVATE, private=PRIVATE}
	functions = {error=error, nop=nop}
	getters = {_G=const(_G), M=const(env), I=const(interface), public=function() state.declaration_access = PUBLIC; return declarator end, private=function() state.declaration_access = PRIVATE; return declarator end}
	setters = {}
	for i=1,arg.n do
		local module = _state[arg[i] or import_error()] or import_error()
		local module_functions, module_getters, module_setters = module[FUNCTION], module[GETTER], module[SETTER]
		for k, v in module.access do
			if v == PUBLIC and (not access[k] or import_error()) then
				access[k], functions[k], getters[k], setters[k] = PRIVATE, module_functions[k], module_getters[k], module_setters[k]
			end
		end
	end
	state = {access=access, [FUNCTION]=functions, [GETTER]=getters, [SETTER]=setters, declarator=declarator, default_access=PRIVATE}
	_state[declarator], _state[env], _state[interface] = state, state, state
	setfenv(2, env)
end