if getmetatable(getfenv(0)) == false then return end
local tinsert, tremove, getn, setn, strfind, type, setmetatable, setfenv, _G = tinsert, tremove, getn, table.setn, strfind, type, setmetatable, setfenv, getfenv(0)

local PRIVATE, PUBLIC, FIELD, ACCESSOR, MUTATOR = 0, 1, 2, 4, 6
local TYPES = { FIELD, ACCESSOR, MUTATOR }
local READ, WRITE = '', '='
local OPERATION = { [FIELD]=READ, [ACCESSOR]=READ, [MUTATOR]=WRITE }
local META = { get=ACCESSOR, set=MUTATOR }

local function error(msg, ...) return _G.error(format(msg or '', unpack(arg)) .. '\n' .. debugstack(), 0) end

local nop, id = function() end, function(v) return v end

local interface_lt = function() return true end
local INTERFACE = setmetatable({}, { __lt=interface_lt })

local function proxy_mt(fields, mutators, lt)
	return { __metatable=false, __index=fields, __newindex=function(_, k, v) return mutators[k](v) end, __lt=lt }
end

local _module, _access, _name = {}, {}, {}

local definition_helper_mt = { __metatable=false }
function definition_helper_mt:__index(k)
	_name[self] = _name[self] and error('Invalid modifier "%s".', k) or k
	return self
end
function definition_helper_mt:__newindex(k, v) local module = _module[self]
	local name = META[k] and (_name[self] or error'Definition missing identifier.') or k
	if type(name) ~= 'string' or not strfind(name, '^[_%a][_%w]*') then error('Invalid identifier "%s".', name) end
	local type = META[k] or FIELD
	module.defined[name .. OPERATION[type]] = module.defined[name .. OPERATION[type]] and error('Duplicate identifier "%s".', name) or true
	module[type][name], module[_access[self]+type][name] = v, v
	_access[self], _name[self] = nil, nil
end

local function include(self, interface)
	local module = (interface < INTERFACE or error'Import error.') and _module[interface]
	for _, type in TYPES do
		for k, v in module[PUBLIC+type] do
			if not self.defined[k .. OPERATION[type]] then
				self.defined[k .. OPERATION[type]], self[type][k] = true, v
			end
		end
	end
end

local nop_default_mt = { __index=function() return nop end }

local env = setmetatable({}, {
	__metatable = false,
	__newindex = function(_, k)
		if _G[k] then _G.error(nil) end
		local module, environment, interface, definition_helper, modifiers, accessors, mutators, fields, public_accessors, public_mutators, public_fields
		environment, interface, definition_helper = {}, {}, setmetatable({}, definition_helper_mt)
		accessors = { private=function() _access[definition_helper] = PRIVATE; return definition_helper end, public=function() _access[definition_helper] = PUBLIC; return definition_helper end }
		mutators = setmetatable({ _=nop }, { __index=function(_, k) return function(v) _G[k] = v end end })
		fields = setmetatable(
			{ _M=environment, _G=_G, include=function(interface) include(module, interface) end, error=error, nop=nop, id=id },
			{ __index=function(_, k) local accessor = accessors[k]; if accessor then return accessor() else return _G[k] end end }
		)
		public_accessors = setmetatable({}, nop_default_mt)
		public_mutators = setmetatable({}, nop_default_mt)
		public_fields = setmetatable({}, { __index=function(_, k) return public_accessors[k]() end })
		setmetatable(environment, proxy_mt(fields, mutators))
		setmetatable(interface, proxy_mt(public_fields, public_mutators, interface_lt))
		module = {
			defined = { _M=true, _G=true, include=true, error=true, nop=true, id=true, public=true, private=true, ['_=']=true },
			[ACCESSOR] = accessors,
			[MUTATOR] = mutators,
			[FIELD] = fields,
			[PUBLIC+ACCESSOR] = public_accessors,
			[PUBLIC+MUTATOR] = public_mutators,
			[PUBLIC+FIELD] = public_fields,
		}
		_module[definition_helper], _module[interface] = module, module
		_G[k] = interface
		setfenv(2, environment)
	end,
})

setmetatable(_G, {
	__metatable = false,
	__index = function(_, k) if k == 'module' then setfenv(2, env) end end,
})