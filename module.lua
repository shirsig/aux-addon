local state = {}

local public_interface_mt = {
	__newindex = function()
		error('Unsupported operation.', 2)
	end,
	__index = function(self, key)
		if state[self].public[key] then
			return state[self].data[key]
		else
			error('Read of undeclared "'..key..'".', 2)
		end
	end,
}
local private_interface_mt = {
	__newindex = function(self, key, value)
		if not state[self].declared[key] then
			error('Write of undeclared "'..key..'".', 2)
		end
		state[self].data[key] = value
	end,
	__index = function(self, key)
		if not state[self].declared[key] then
			error('Read of undeclared "'..key..'".', 2)
		end
		return state[self].data[key]
	end,
}
local public_declarator_mt = {
	__newindex = function(self, key, value)
		if state[self].declared[key] then
			error('Multiple declarations of "'..key..'".', 2)
		end
		state[self].data[key] = value
		state[self].public[key] = true
		state[self].declared[key] = true
	end,
	__index = function()
		error('Unsupported operation.', 2)
	end,
}
local private_declarator_mt = {
	__newindex = function(self, key, value)
		if state[self].declared[key] then
			error('Multiple declarations of "'..key..'".', 2)
		end
		state[self].data[key] = value
		state[self].declared[key] = true
	end,
	__index = function()
		error('Unsupported operation.', 2)
	end,
}

function aux_module()
	local new_state = {data={}, public={}, declared={}}
    local module = {setmetatable({}, public_interface_mt), setmetatable({}, private_interface_mt), setmetatable({}, public_declarator_mt), setmetatable({}, private_declarator_mt)}
	for _, component in module do
		state[component] = new_state
	end
    return module
end