setglobal('aux', aux_module())

public.version = '4.0.0'

private.module_envs = {}
function public.module(path)
	local env
	if path == '' then
		env = getfenv()
	elseif m.module_envs[path] then
		env = m.module_envs[path]
	else
		local prefix
		for name in string.gfind(path, '[%a_][%w_]*') do
			local qualified_name = prefix and prefix..'.'..name or name
			env = m.module_envs[qualified_name]
			if not env then
				(prefix and m.module_envs[prefix].public or public)[name], env = (function() return aux_module(), getfenv() end)()
				env.private.LOAD = nil
				m.module_envs[qualified_name] = env
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
private.ADDON_LOADED = {}
event_frame:SetScript('OnEvent', function()
	if event == 'ADDON_LOADED' then
		if m.ADDON_LOADED[arg1] then
			m.ADDON_LOADED[arg1]()
		end
	else
		m[event]()
		if event == 'VARIABLES_LOADED' then
			for _, env in m.module_envs do
				if env.m.LOAD then
					env.m.LOAD()
				end
			end
			m.log('v'..m.version..' loaded.')
		end
	end
end)
