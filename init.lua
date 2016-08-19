setglobal('aux', aux_module('core'))
import 'util'

public.version = '4.0.0'

module_envs = {}
function public.module(path)
	local env
	if path == 'core' then
		env = getfenv()
	elseif module_envs[path] then
		env = module_envs[path]
	else
		local prefix
		for name in string.gfind(path, '[%a_][%w_]*') do
			local qualified_name = prefix and prefix..'.'..name or name
			env = module_envs[qualified_name]
			if not env then
				(prefix and module_envs[prefix].public or public)[name], env = (function() return aux_module(qualified_name), getfenv() end)()
				env.import 'util'
				env.LOAD = nil
				module_envs[qualified_name] = env
			end
			prefix = qualified_name
		end
	end
	setfenv(2, env)
end

local event_frame = CreateFrame 'Frame'
for _, event in {'VARIABLES_LOADED', 'ADDON_LOADED', 'AUCTION_HOUSE_SHOW', 'AUCTION_HOUSE_CLOSED', 'AUCTION_BIDDER_LIST_UPDATE', 'AUCTION_OWNED_LIST_UPDATE'} do
	event_frame:RegisterEvent(event)
end
ADDON_LOADED = {}
event_frame:SetScript('OnEvent', function()
	if event == 'ADDON_LOADED' then
		if ADDON_LOADED[arg1] then
			ADDON_LOADED[arg1]()
		end
	else
		m[event]()
		if event == 'VARIABLES_LOADED' then
			for _, env in module_envs do
				if env.LOAD then
					env.LOAD()
				end
			end
			log('v'..version..' loaded.')
		end
	end
end)
