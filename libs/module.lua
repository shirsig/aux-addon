if module then return end
local typeof, setmetatable, setfenv, unpack, next, pcall, _G = type, setmetatable, setfenv, unpack, next, pcall, getfenv(0)

local PUBLIC, PRIVATE = 1, 2
local INDEX, NEWINDEX, CALL = 1, 2, 3

local function error(msg, ...) return _G.error(format(msg or '', unpack(arg))..'\n'..debugstack(), 0) end
local function import_error() error 'Invalid imports.' end
local function declaration_error() error 'Invalid declaration.' end
local function collision_error(key) error('"%s" already exists.', key) end

local function nop() end
local function id(v) return v end
local function const(v) return function() return v end end

local _state = {}

local env_mt, start_declaration
do
	local intercept, declare, extract
	local state, access, type, name
	local declaration = nop
	function start_declaration(self, access, type)
		if declaration ~= nop then declaration_error() end
		declaration, state, access, type, name = intercept, self, access, type, nil
	end
	do
		local ACCESS = {public=PUBLIC, private=PRIVATE}
		local TYPE = {call=CALL, get=INDEX, set=NEWINDEX}
		function intercept(self, event, key, value)
			if self ~= state then declaration_error() end
			if event == INDEX and (not name or declaration_error()) then
				if ACCESS[key] and (not access or declaration_error()) then
					access = ACCESS[key]
				else
					name = key
				end
				return true
			elseif event == NEWINDEX then
				if name then
					type = TYPE[key] or declaration_error()
				else
					name = key -- TODO tostring if value nil?
					if typeof(value) == 'function' then type = CALL else type, value = INDEX, const(value) end
				end
				declare(self, access, name, {[type]=value})
				declaration = nop
				return true
			elseif event == CALL then
				if name then
					local success, call, get, set = pcall(extract, value)
					if not success then declaration_error() end
					declare(self, access, name, {[CALL]=call, [INDEX]=get, [NEWINDEX]=set})
				else
					self.default_access = access
				end
				declaration = nop
				return true
			end
		end
	end
	env_mt = {__metatable=false}
	function env_mt:__index(key) local state=_state[self]
		if declaration(state, INDEX, key) then return self end
		local index = state[INDEX][key]
		if index then return index() else
			local call = state[CALL][key]
			if call then return call else return _G[key] end
		end
	end
	function env_mt:__newindex(key, value) local state=_state[self]
		if declaration(state, NEWINDEX, key, value) then return end
		local newindex = state[NEWINDEX][key]
		if newindex then newindex(value); return end
		start_declaration(state); declaration(state, NEWINDEX, key, value)
	end
	function env_mt:__call(key, value)
		declaration(_state[self], CALL, key, value)
	end
	function declare(self, access, name, t)
		self.access[name] = self.access[name] and collision_error(name) or access or self.default_access
		for type, value in t do
			self[type][name] = typeof(value) == 'function' and value or declaration_error()
		end
	end
	function extract(v)
		local call, get, set
		call, get, set, v.call, v.get, v.set = v.call, v.get, v.set, nil, nil, nil
		if next(v) or call ~= nil and get ~= nil then error() end
		return call, get, set
	end
end

local interface_mt = {__metatable=false}
function interface_mt:__index(key) local state=_state[self]
	if state.access[key] == PUBLIC then
		local index = state[INDEX][key]
		if index then return index() else return state[CALL][key] end
	end
end
function interface_mt:__newindex(key, value) local state=_state[self]
	if state.access[key] == PUBLIC then (state[NEWINDEX][key] or state[CALL][key])(value) end
end

--function interface_mt:__call(key, ...) local state=_state[self]
--	-- TODO new instance
--end

function module(...)
	local state, env, interface, access, call, index, newindex
	env, interface = setmetatable({}, env_mt), setmetatable({}, interface_mt)
	state = {default_access=PRIVATE}
	state.access = {error=PRIVATE, nop=PRIVATE, id=PRIVATE, const=PRIVATE, _G=PRIVATE, M=PRIVATE, I=PRIVATE, public=PRIVATE, private=PRIVATE}
	state[CALL] = {error=error, nop=nop, id=id, const=const}
	state[INDEX] = {
		_G = const(_G),
		M = const(env),
		I = const(interface),
		public = function() start_declaration(state, PUBLIC); return env end,
		private = function() start_declaration(state, PRIVATE); return env end,
	}
	state[NEWINDEX] = {}
	for i=1,arg.n do
		local module = _state[arg[i] or import_error()] or import_error()
		local import_call, import_index, import_newindex = module[CALL], module[INDEX], module[NEWINDEX]
		for k, v in module.access do
			if v == PUBLIC and (not access[k] or import_error()) then
				call[k], index[k], newindex[k] = import_call[k], import_index[k], import_newindex[k]
				access[k] = PRIVATE
			end
		end
	end
	_state[env], _state[interface] = state, state
	setfenv(2, env)
end