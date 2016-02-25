local private, public = {}, {}
Aux.control = public

local event_listeners = {}
local update_listeners = {}
private.threads = {}

function Aux.control.on_event()
	for listener, _ in pairs(event_listeners) do
		if event == listener.event and not listener.deleted then
			listener.action()
		end
	end
end

function Aux.control.on_update()
	event_listeners = Aux.util.set_filter(event_listeners, function(l) return not l.deleted end)
	update_listeners = Aux.util.set_filter(update_listeners, function(l) return not l.deleted end)
	
	for listener, _ in pairs(update_listeners) do
		if not listener.deleted then
			listener.action()
		end
	end

	for thread_id, k in pairs(private.threads) do
		private.threads[thread_id] = nil
		public.thread_id = thread_id
		k()
		public.thread_id = nil
	end
end



function Aux.control.event_listener(event, action)
	local self = {}
	
	local listener = { event=event, action=action }
	
	function self:set_action(action)
		listener.action = action
	end
	
	function self:start()
		Aux.util.set_add(event_listeners, listener)
		AuxControlFrame:RegisterEvent(event)
		return self
	end
	
	function self:stop()
		listener.deleted = true
		if not Aux.util.any(Aux.util.set_to_array(event_listeners), function(l) return l.event == event end) then
			AuxControlFrame:UnregisterEvent(event)
		end
		return self
	end
	
	return self
end

function Aux.control.update_listener(action)
	local self = {}
	
	local listener = { action=action }

	function self:set_action(action)
		listener.action = action
	end
	
	function self:start()
		Aux.util.set_add(update_listeners, listener)
		return self
	end
	
	function self:stop()
		listener.deleted = true
		return self
	end
	
	return self
end

	

function Aux.control.on_next_update(callback)
	local listener = Aux.control.update_listener()
	
	listener:set_action(function()
		listener:stop()
		return callback()
	end)
	
	listener:start()
end

function Aux.control.on_next_event(event, callback)
	local listener = Aux.control.event_listener(event)
	
	listener:set_action(function()
		listener:stop()
		return callback()
	end)
	
	listener:start()
end

function Aux.control.as_soon_as(p, callback)
	local listener = Aux.control.update_listener()	
	
	listener:set_action(function()
		if p() then
			listener:stop()
			return callback()
		end
	end)
	
	listener:start()
end



function Aux.control.controller()
	local self = {}
	
	local state
	
	local listener = Aux.control.update_listener()
	listener:set_action(function()
		if state and state.p() then
			local k = state.k
			state = nil
			return k()
		end
	end)
	listener:start()
	
	function self.wait(p, k)
		state = {
			k = k,
			p = p,
		}
	end
	
	function self:reset()
		state = nil
	end
	
	function self:cleanup()
		listener.stop()
	end
	
	return self
end

do
	local next_thread_id = 1
	function public.new(k)
		local thread_id = next_thread_id
		next_thread_id = next_thread_id + 1
		private.threads[thread_id] = k
		return thread_id
	end
end

function public.kill(thread_id)
	private.threads[thread_id] = nil
end

function public.wait(...)
	local k = tremove(arg, 1)
	private.threads[public.thread_id] = function() return k(unpack(arg)) end
end
