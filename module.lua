local PUBLIC, PRIVATE = 1, 2
local state = {}
local function_mt = {
	__call = function(self, ...)
		local f = state[self]
		local temp = getfenv(f).__
		getfenv(f).__ = {}
		f(unpack(arg))
		getfenv(f).__ = temp
	end,
}
local interface_mt = {
	__index = function(self, key)
		if not state[self].access[state[self].type][key] then
			error('Read of undeclared "'..key..'".', 2)
		end
		return state[self].data[key]
	end,
	__newindex = function(self, key, value)
		if state[self].type == PUBLIC then
			error('Unsupported operation.', 2)
		elseif not state[self].access[PRIVATE][key] then
			error('Write of undeclared "'..key..'".', 2)
		end
		state[self].data[key] = value
	end,
}
local declarator_mt = {
	__index = function()
		error('Unsupported operation.', 2)
	end,
	__newindex = function(self, key, value)
		if state[self].access[PRIVATE][key] then
			error('Multiple declarations of "'..key..'".', 2)
		end
		state[self].data[key] = value
		state[self].access[PRIVATE][key] = true
		state[self].access[state[self].type][key] = true
	end,
}
function aux_module()
	local data, access = {}, {{}, {__=true}}
	local public_state, private_state = {type=PUBLIC, data=data, access=access}, {type=PRIVATE, data=data, access=access}
    local interface, private_interface = setmetatable({}, interface_mt), setmetatable({}, interface_mt)
	local public_declarator, private_declarator = setmetatable({}, declarator_mt), setmetatable({}, declarator_mt)
	state[interface], state[private_interface] = public_state, private_state
	state[public_declarator], state[private_declarator] = public_state, private_state

	local env = setmetatable({m=private_interface, public=public_declarator, private=private_declarator}, {__index=getfenv(0)})
--	public_state.env = env
--	private_state.env = env

	setfenv(2, env)
	return interface
end