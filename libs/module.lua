if module then return end
local strfind, type, setmetatable, setfenv, _G = strfind, type, setmetatable, setfenv, getfenv(0)
local error, nop, define, include, create_module, nop_default_mt, public_modifier_mt, proxy_mt
local loaded, defined, interfaces, environments = {}, {}, {}, {}

function nop() end
function error(msg, ...) return _G.error(format(msg or '', unpack(arg)) .. '\n' .. debugstack(), 0) end

function define(self, k, v, private)
	if type(k) ~= 'string' or not strfind(k, '^[_%a][_%w]*') then error('Invalid identifier "%s".', k) end
	local _, _, prefix, suffix = strfind(k, '^(.?.?.?.?)([_%a].*)')
	local module = loaded[self]
	local signature = (private and '-' or '+') .. k
	module.defined[signature] = module.defined[signature] and error('Duplicate identifier "%s".', signature) or true
	if private or not module.defined['-' .. k] then
		module.fields[k] = v
		if prefix == 'get_' then module.accessors[suffix] = v elseif prefix == 'set_' then module.mutators[suffix] = v end
	end
	if not private then
		module.public_fields[k] = v
		if prefix == 'get_' then module.public_accessors[suffix] = v elseif prefix == 'set_' then module.public_mutators[suffix] = v end
	end
end

function include(self, name)
	local module = name and loaded[name] or error('No module "%s".', name)
	for k, v in module.public_fields do define(self, k, v, true) end
end

public_modifier_mt = {__metatable=false, __newindex=define}

nop_default_mt = {__index=function() return nop end}

function proxy_mt(fields, mutators)
	return {__metatable=false, __index=fields, __newindex=function(_, k, v) return mutators[k](v) end}
end

function create_module(name)
	if type(name) ~= 'string' then error('Invalid module name "%s".', name) end
	local P, environment, interface, public_modifier, accessors, mutators, fields, public_accessors, public_mutators, public_fields
	environment, interface, public_modifier = {}, {}, setmetatable({}, public_modifier_mt)
	accessors = {M=function() return public_modifier end}
	mutators = setmetatable({_=nop}, {__index=function(_, k) return function(v) define(name, k, v, true) end end})
	fields = setmetatable(
		{_M=environment, _G=_G, include=function(interface) include(name, interface) end, nop=nop},
		{__index=function(_, k) local accessor = accessors[k]; if accessor then return accessor() else return _G[k] end end}
	)
	public_accessors = setmetatable({}, nop_default_mt)
	public_mutators = setmetatable({}, nop_default_mt)
	public_fields = setmetatable({}, {__index=function(_, k) return public_accessors[k]() end})
	setmetatable(environment, proxy_mt(fields, mutators))
	setmetatable(interface, proxy_mt(public_fields, public_mutators))
	P = {
		defined = {['-_M']=true, ['-_G']=true, ['-include']=true, ['-nop']=true, ['-M']=true, ['-set__']=true, ['-require']=true},
		fields = fields, accessors = accessors, mutators = mutators,
		public_fields = public_fields, public_accessors = public_accessors, public_mutators = public_mutators,
	}
	environments[name], interfaces[name] = environment, interface
	loaded[name], loaded[public_modifier] = P, P
end

function module(name) if not loaded[name] then create_module(name) end defined[name] = true; setfenv(2, environments[name]) end
function require(name) if not loaded[name] then create_module(name) end return interfaces[name] end
function _G.defined(name) return defined[name] end