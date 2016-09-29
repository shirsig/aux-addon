if getmetatable(getfenv(0)) == false then return end
local tinsert, tremove, getn, setn, strfind, type, setmetatable, setfenv, _G = tinsert, tremove, getn, table.setn, strfind, type, setmetatable, setfenv, getfenv(0)

local PRIVATE, PUBLIC, FIELD, ACCESSOR, MUTATOR = 0, 1, 2, 4, 6
local TYPES = { FIELD, ACCESSOR, MUTATOR }
local READ, WRITE = '', '='
local OPERATION = { [FIELD]=READ, [ACCESSOR]=READ, [MUTATOR]=WRITE }
local ACCESS = { private=PRIVATE, public=PUBLIC }
local META = { get=ACCESSOR, set=MUTATOR }

local function error(msg, ...) return _G.error(format(msg or '', unpack(arg)) .. '\n' .. debugstack(), 0) end

local nop, id = function() end, function(v) return v end

local interface_lt = function() return true end
local INTERFACE = setmetatable({}, { __lt=interface_lt })

local function proxy_mt(fields, mutators, lt)
	return { __metatable=false, __index=fields, __newindex=function(_, k, v) return mutators[k](v) end, __lt=lt }
end

local _module, _modifiers = {}, {}

local definition_helper_mt = { __metatable=false }
function definition_helper_mt:__index(k)
	tinsert(_modifiers[self], k)
	return self
end
function definition_helper_mt:__newindex(k, v) local module, modifiers = _module[self], _modifiers[self]
	local access = ACCESS[tremove(modifiers, 1)] or error'Definition missing access modifier.'
	local name = META[k] and (tremove(modifiers) or error'Definition missing identifier.') or k
	if type(name) ~= 'string' or not strfind(name, '^[_%a][_%w]*') then error('"%s" is not a valid identifier.', name) end
	local type = META[k] or FIELD
	module.defined[name .. OPERATION[type]] = module.defined[name .. OPERATION[type]] and error('"%s" already exists.', name) or true
	for i = getn(modifiers), 1, -1 do v = module[FIELD][modifiers[i]](v) end
	module[type][name], module[access+type][name] = v, v
	setn(modifiers, 0)
end

local function import(self, interface)
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

local global_mt = { __metatable=false }
function global_mt:__index(key)
	if key ~= 'module' then return end
	local module, environment, interface, definition_helper, accessors, mutators, fields, public_accessors, public_mutators, public_fields
	environment, interface, definition_helper = {}, {}, setmetatable({}, definition_helper_mt)
	accessors = { private=function() return definition_helper.private end, public=function() return definition_helper.public end }
	mutators = setmetatable({ _=nop }, { __index=function(_, k) return function(v) _G[k] = v == interface and _G[k] ~= nil and _G.error(nil) or v end end })
	fields = setmetatable(
		{ _E=environment, _I=interface, _G=_G, import=function(interface) import(module, interface) end, error=error, nop=nop, id=id },
		{ __index=function(_, key) local accessor = accessors[key]; if accessor then return accessor() else return _G[key] end end }
	)
	public_accessors = setmetatable({}, nop_default_mt)
	public_mutators = setmetatable({}, nop_default_mt)
	public_fields = setmetatable({}, { __index=function(_, key) return public_accessors[key]() end })
	setmetatable(environment, proxy_mt(fields, mutators))
	setmetatable(interface, proxy_mt(public_fields, public_mutators, interface_lt))
	module = {
		defined = { _E=true, _I=true, _G=true, import=true, error=true, nop=true, id=true, public=true, private=true, ['_=']=true },
		[ACCESSOR] = accessors,
		[MUTATOR] = mutators,
		[FIELD] = fields,
		[PUBLIC+ACCESSOR] = public_accessors,
		[PUBLIC+MUTATOR] = public_mutators,
		[PUBLIC+FIELD] = public_fields,
		interface = interface,
	}
	_module[definition_helper], _module[interface] = module, module
	_modifiers[definition_helper] = {}
	setfenv(2, environment)
	return interface
end
setmetatable(_G, global_mt)