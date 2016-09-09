if module then return end
local setfenv, setmetatable, unpack, _G = setfenv, setmetatable, unpack, getfenv(0)

local PRIVATE, FIELD, PUBLIC, ACCESSOR, MUTATOR = 0, 0, 1, 2, 4
local PUBLIC_FIELD, PUBLIC_ACCESSOR, PUBLIC_MUTATOR = PUBLIC+FIELD, PUBLIC+ACCESSOR, PUBLIC+MUTATOR

local function error(msg, ...) return _G.error(format(msg or '', unpack(arg)) .. '\n' .. debugstack(), 0) end
local function import_error() error('Import error.') end
local function declaration_error() error('Declaration error.') end
local function collision_error(key) error('"%s" already exists.', key) end

local nop, id = function() end, function(v) return v end

local interface_eq = function() return true end
local interface_mt, environment_mt, declarator_mt = { __metatable=false, __eq=interface_eq }, { __metatable=false }, { __metatable=false }
local INTERFACE = setmetatable({}, { __eq=interface_eq })

local __ = {}

function interface_mt:__index(k) self=__[self]
	return self[PUBLIC_FIELD][k]
end
function interface_mt:__newindex(k, v) self=__[self]
	self[PUBLIC_MUTATOR][k](v)
end

function environment_mt:__index(k) self=__[self]
	return self[FIELD][k]
end
function environment_mt:__newindex(k, v) self=__[self]
	local mutator = self[MUTATOR][k]
	if mutator then
		mutator(v)
	elseif not self.defined[k] or collision_error(k) then
		self.declarator[k] = v
	end
end

do
	local ACCESS, META = { public=PUBLIC, private=PRIVATE }, { get=ACCESSOR, set=MUTATOR }
	function declarator_mt:__index(k) self=__[self]
		if not self.declaration_access then
			self.declaration_access = ACCESS[k] or declaration_error()
		elseif not self.declaration_meta or declaration_error() then
			self.declaration_meta = META[k]
			self.declaration_modifiers[k] = true
		end
		return self.declarator
	end
	function declarator_mt:__newindex(k, v) self=__[self]
		local access, meta = self.declaration_access, self.declaration_meta or FIELD
		if v ~= self.interface then
			self.defined[k] = true
			self[meta], self[access+meta] = v, v -- TODO performance assignment vs conditional
		elseif _G[k] ~= nil or error(nil) then
			_G[k] = v
		end
		self.declaration_access, self.declaration_meta = nil, nil
	end
	function declarator_mt:__call()
		self.default_access = (not self.declaration_meta or declaration_error()) and self.declaration_access
	end
end

local function import(self, interface)
	local module = (interface == INTERFACE or import_error()) and __[interface]
	for k, v in module[PUBLIC_FIELD] do
		if not self.defined[k] then
			self.defined[k], self[FIELD][k] = true, v
		end
	end
	for k, v in module[PUBLIC_ACCESSOR] do
		if not self.defined[k] then
			self.defined[k], self[ACCESSOR][k] = true, v
		end
	end
	for k, v in module[PUBLIC_MUTATOR] do
		if not self.defined[k] then
			self.defined[k], self[MUTATOR][k] = true, v
		end
	end
end

local nop_mt = { __index=nop }
local mt = { __metatable=false }
function mt:__index(key)
	if key ~= 'module' then return end
	local interface, environment, declarator = setmetatable({}, interface_mt), setmetatable({}, environment_mt), setmetatable({}, declarator_mt)
	local accessors, public_accessors = setmetatable({}, { __index=_G }), {}
	self = {
		defined = { _G=true, _I=true, _E=true, public=true, private=true, import=true, _=true, error=true, nop=true, id=true },
		[FIELD] = setmetatable(
			{ _G=_G, _I=interface, _E=environment, import=function(interface) import(self, interface) end, error=error, nop=nop, id=id },
			{__index=function(_, key) return accessors[key]() end }
		),
		[ACCESSOR] = setmetatable({ public=function() return declarator.public end, private=function() return declarator.private end }, nop_mt),
		[MUTATOR] = setmetatable({}, nop_mt),
		[PUBLIC_FIELD] = setmetatable({}, {__index=function(_, key) return public_accessors[key]() end}),
		[PUBLIC_ACCESSOR] = setmetatable({}, nop_mt),
		[PUBLIC_MUTATOR] = setmetatable({}, nop_mt),
		interface = interface,
		declarator = declarator,
	}
	__[interface], __[environment], __[declarator] = self, self, self
	setfenv(2, environment)
	return interface
end
setmetatable(_G, mt)