if module then return end
local type, tostring, setmetatable, setfenv, unpack, next, pcall, _G = type, tostring, setmetatable, setfenv, unpack, next, pcall, getfenv(0)

local PUBLIC, PRIVATE = 1, 2
local CALL, INDEX, NEWINDEX = 1, 2, 3

local function error(msg, ...) return _G.error(format(msg or '', unpack(arg))..'\n'..debugstack(), 0) end
local function import_error() error 'Import failed.' end
local function declaration_error() error 'Invalid declaration.' end
local function collision_error(key) error('"%s" already exists.', key) end

local function nop() end
local function const(v) return function() return v end end

local _state = {}

local declarator_mt = {__metatable=false}
do
	local ACCESS, EVENT = {public=PUBLIC, private=PRIVATE}, {call=CALL, get=INDEX, set=NEWINDEX}
	local function extract(v)
		local f, getter, setter
		f, getter, setter, v.call, v.get, v.set = v.call, v.get, v.set, nil, nil, nil
		if next(v) or f ~= nil and getter ~= nil then error() end
		return f, getter, setter
	end
	local function declare(state, access, name, handlers)
		state.access[name] = state.access[name] and collision_error(name) or access or PRIVATE
		for event, handler in handlers do
			if type(handler) ~= 'function' and (event == INDEX or declaration_error()) then
				handler = const(handler == nil and tostring(name) or handler)
			end
			state[event][name] = handler
		end
	end
	function declarator_mt:__index(key) local state=_state[self]
		if ACCESS[key] and not state.declaration_access then
			state.declaration_access = ACCESS[key]
		elseif not state.declaration_name or declaration_error() then
			state.declaration_name = type(key) == 'string' and key or declaration_error()
		end
		return self
	end
	function declarator_mt:__newindex(key, value) local state=_state[self]
		local name, event = state.declaration_name, nil
		if name then
			event = EVENT[key] or declaration_error()
		else
			name, event = key, type(value) == 'function' and CALL or INDEX
		end
		declare(state, state.declaration_access, name, {[event]=value})
		state.declaration_access, state.declaration_name = nil, nil
	end
	function declarator_mt:__call(value) local state=_state[self]
		if state.declaration_name then
			local success, f, getter, setter = pcall(extract, value)
			if not success then declaration_error() end
			declare(state, state.declaration_access, state.declaration_name, {[CALL]=f, [INDEX]=getter, [NEWINDEX]=setter})
		end
		state.declaration_access, state.declaration_name = nil, nil
	end
end

local env_mt = {__metatable=false}
function env_mt:__index(key) local state=_state[self]
	local getter = state[INDEX][key]
	if getter then return getter() end
	return state[CALL][key] or _G[key] or state.declarator[key]
end
function env_mt:__newindex(key, value) local state=_state[self]
	if state.access[key] then
		local setter = state[NEWINDEX][key] or collision_error(key)
		setter(value)
	else
		state.declarator[key] = value
	end
end

local interface_mt = {__metatable=false}
function interface_mt:__index(key) local state=_state[self]
	if state.access[key] == PUBLIC then
		local getter = state[INDEX][key]
		if getter then return getter() else return state[CALL][key] end
	end
end
function interface_mt:__newindex(key, value) local state=_state[self]
	if state.access[key] == PUBLIC then (state[NEWINDEX][key] or nop)(value) end
end

function module(...)
	local state, declarator, env, interface, access, functions, getters, setters
	declarator, env, interface = setmetatable({}, declarator_mt), setmetatable({}, env_mt), setmetatable({}, interface_mt)
	access = {_=PRIVATE, error=PRIVATE, nop=PRIVATE, _G=PRIVATE, M=PRIVATE, I=PRIVATE, public=PRIVATE, private=PRIVATE}
	functions = {error=error, nop=nop}
	getters = {_G=const(_G), M=const(env), I=const(interface), public=function() return declarator.public end, private=function() return declarator.private end}
	setters = {_=nop}
	for i=1,arg.n do
		local module = _state[arg[i] or import_error()] or import_error()
		local module_functions, module_getters, module_setters = module[CALL], module[INDEX], module[NEWINDEX]
		for k, v in module.access do
			if v == PUBLIC and (not access[k] or import_error()) then
				access[k], functions[k], getters[k], setters[k] = PRIVATE, module_functions[k], module_getters[k], module_setters[k]
			end
		end
	end
	state = {access=access, [CALL]=functions, [INDEX]=getters, [NEWINDEX]=setters, declarator=declarator}
	_state[declarator], _state[env], _state[interface] = state, state, state
	setfenv(2, env)
end