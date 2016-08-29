if module then return end
local type, tostring, setmetatable, setfenv, unpack, next, pcall, _G = type, tostring, setmetatable, setfenv, unpack, next, pcall, getfenv(0)

local PUBLIC, PRIVATE = 1, 2
local CALL, INDEX, NEWINDEX = 1, 2, 3

local function error(msg, ...) return _G.error(format(msg or '', unpack(arg))..'\n'..debugstack(), 0) end
local function import_error() error('Import error.') end
local function declaration_error() error('Declaration error.') end
local function collision_error(key) error('"%s" already exists.', key) end

local function nop() end
local function const(v) return function() return v end end

local state = {}

local declarator_mt = {__metatable=false}
do
	local ACCESS, EVENT = {public=PUBLIC, private=PRIVATE}, {call=CALL, get=INDEX, set=NEWINDEX}
	local function extract_handlers(v)
		local f, getter, setter
		f, getter, setter, v.call, v.get, v.set = v.call, v.get, v.set, nil, nil, nil
		if next(v) or f ~= nil and getter ~= nil then error() end
		return f, getter, setter
	end
	local function declare(self, access, name, handlers)
		self.access[name] = self.access[name] and collision_error(name) or access or self.default_access
		for event, handler in handlers do
			if type(handler) ~= 'function' and (event == INDEX or declaration_error()) then
				handler = const(handler == nil and tostring(name) or handler)
			end
			self[event][name] = handler
		end
	end
	function declarator_mt:__index(key) self=state[self]
		if ACCESS[key] and (not (self.declaration_access or self.declaration_name) or declaration_error()) then
			self.declaration_access = ACCESS[key]
		elseif not self.declaration_name or declaration_error() then
			self.declaration_name = type(key) == 'string' and key or declaration_error()
		end
		return self.declarator
	end
	function declarator_mt:__newindex(key, value) self=state[self]
		local name, event = self.declaration_name, nil
		if name then
			event = EVENT[key] or error(name)
		else
			name, event = key, type(value) == 'function' and CALL or INDEX
		end
		declare(self, self.declaration_access, name, {[event]=value})
		self.declaration_access, self.declaration_name = nil, nil
	end
	function declarator_mt:__call(value) self=state[self]
		if self.declaration_name then
			local success, f, getter, setter = pcall(extract_handlers, value)
			if not success then declaration_error() end
			declare(self, self.declaration_access, self.declaration_name, {[CALL]=f, [INDEX]=getter, [NEWINDEX]=setter})
		elseif self.declaration_access or declaration_error() then
			self.default_access = self.declaration_access
		end
		self.declaration_access, self.declaration_name = nil, nil
	end
end

local environment_mt = {__metatable=false}
function environment_mt:__index(key) self=state[self]
	local getter = self[INDEX][key]
	if getter then return getter() end
	return self[CALL][key] or _G[key] or self.declarator[key]
end
function environment_mt:__newindex(key, value) self=state[self]
	if self.access[key] then
		local setter = self[NEWINDEX][key] or collision_error(key)
		setter(value)
	else
		self.declarator[key] = value
	end
end

local interface_mt = {__metatable=false}
function interface_mt:__index(key) self=state[self]
	if self.access[key] == PUBLIC then
		local getter = self[INDEX][key]
		if getter then return getter() else return self[CALL][key] end
	end
end
function interface_mt:__newindex(key, value) self=state[self]
	if self.access[key] == PUBLIC then (self[NEWINDEX][key] or nop)(value) end
end

local function import(self, ...)
	for i = 1, arg.n do
		local module = state[arg[i] or import_error()]
		for k, v in module.access do
			if v == PUBLIC and not self.access[k] then
				self.access[k], self[CALL][k], self[INDEX][k], self[NEWINDEX][k] = PRIVATE, module[CALL][k], module[INDEX][k], module[NEWINDEX][k]
			end
		end
	end
end

function module(...)
	local declarator, environment, interface = setmetatable({}, declarator_mt), setmetatable({}, environment_mt), setmetatable({}, interface_mt)
	local self; self = {
		access = {_=PRIVATE, error=PRIVATE, nop=PRIVATE, _G=PRIVATE, M=PRIVATE, I=PRIVATE, public=PRIVATE, private=PRIVATE},
		[CALL] = {import=function(...) import(self, unpack(arg)) end, error=error, nop=nop},
		[INDEX] = {_G=const(_G), M=const(environment), I=const(interface), public=function() return declarator.public end, private=function() return declarator.private end},
		[NEWINDEX] = {_=nop},
		declarator = declarator,
		default_access = PRIVATE,
	}
	state[declarator], state[environment], state[interface] = self, self, self
	setfenv(2, environment)
end