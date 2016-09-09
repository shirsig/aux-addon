if getmetatable(getfenv(0)) == false then return end
local setmetatable, setfenv, getglobal, _G = setmetatable, setfenv, getglobal, getfenv(0)

local PRIVATE, FIELD, PUBLIC, ACCESSOR, MUTATOR = 0, 0, 1, 2, 4
local PUBLIC_FIELD, PUBLIC_ACCESSOR, PUBLIC_MUTATOR = PUBLIC+FIELD, PUBLIC+ACCESSOR, PUBLIC+MUTATOR
local READ, WRITE = 0, 1
local OPERATION = { [FIELD]=READ, [ACCESSOR]=READ, [MUTATOR]=WRITE }

local function error(msg, ...) return _G.error(format(msg or '', unpack(arg)) .. '\n' .. debugstack(), 0) end
local function import_error() error('Import error.') end
local function definition_error() error('Invalid definition.') end
local function collision_error(key) error('"%s" already exists.', key) end

local nop, id = function() end, function(v) return v end

local interface_eq = function() return true end
local INTERFACE = setmetatable({}, { __eq=interface_eq })

local function proxy_mt(values, mutators, eq)
	return {
		__metatable = false,
		__index = values,
		__newindex = function(_, k, v) return mutators[k](v) end,
		__eq = eq,
	}
end

local definition_helper_mt = { __metatable=false }
function definition_helper_mt:__index(k)
	tinsert(self.definition_modifiers, k)
	return self
end
do
	local TYPE = { get=ACCESSOR, set=MUTATOR }
	function definition_helper_mt:__newindex(k, v) self=__[self]
		if type(k) ~= 'string' or not strfind(k, '^[_%a][_%w]*') then definition_error() end
		if v ~= self.interface then
			self.defined[OPERATION[type]..k] = self.defined[OPERATION[type]..k] and collision_error(k) or true
			self[type], self[self.definition_access+type] = v, v
		elseif _G[k] ~= nil or error(nil) then
			_G[k] = v
		end
		self.definition_access, self.definition_modifiers = nil, nil
	end
end

local import
do
	local TYPES = {FIELD, ACCESSOR, MUTATOR}
	function import(self, interface)
		local module = (interface == INTERFACE or import_error()) and __[interface]
		for _, type in TYPES do
			for k, v in module[PUBLIC+type] do
				if not self.defined[OPERATION[type]..k] then
					self.defined[OPERATION[type]..k], self[type][k] = true, v
				end
			end
		end
	end
end

local global_default_mt, nop_default_mt = { __index=getglobal }, { __index=nop }

local global_mt = { __metatable=false }
function global_mt:__index(key)
	if key ~= 'module' then return end
	local definition_helper = setmetatable({}, definition_helper_mt)
	local environment, interface = {}, {}
	local accessors = setmetatable(
		{
			private = function() self.definition_access = PRIVATE; return definition_helper end,
			public = function() self.definition_access = PUBLIC; return definition_helper end,
		},
		global_default_mt
	)
	local public_accessors = {}
	local mutators = setmetatable({}, nop_default_mt)
	local public_mutators = setmetatable({}, nop_default_mt)
	local fields = setmetatable(
		{
			_G = _G,
			_I = interface,
			_E = environment,
			import = function(interface) import(self, interface) end,
			error = error,
			nop = nop,
			id = id,
		},
		{ __index=function(_, key) return accessors[key]() end }
	)
	local public_fields = setmetatable(
		{},
		{ __index=function(_, key) return public_accessors[key]() end }
	)
	setmetatable(environment, proxy_mt(fields, mutators))
	setmetatable(interface, proxy_mt(public_fields, public_mutators, interface_eq))
	self = {
		defined = {
			[FIELD..'_G'] = true,
			[FIELD..'_I'] = true,
			[FIELD..'_E'] = true,
			[FIELD..'import'] = true,
			[FIELD..'_'] = true,
			[FIELD..'error'] =true,
			[FIELD..'nop'] = true,
			[FIELD..'id'] = true,
			[ACCESSOR..'public'] = true,
			[ACCESSOR..'private'] = true,
		},
		[FIELD] = fields,
		[PUBLIC_FIELD] = public_fields,
		[ACCESSOR] = accessors,
		[PUBLIC_ACCESSOR] = public_accessors,
		[MUTATOR] = mutators,
		[PUBLIC_MUTATOR] = public_mutators,
		interface = interface,
	}
	setfenv(2, environment)
	return interface
end
setmetatable(_G, global_mt)