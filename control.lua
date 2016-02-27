local private, public = {}, {}
Aux.control = public

private.event_listeners = {}
private.threads = {}

function public.on_event()
	for listener, _ in pairs(private.event_listeners) do
		if event == listener.event and not listener.deleted then
			listener.action()
		end
	end
end

function public.on_update()
	private.event_listeners = Aux.util.set_filter(private.event_listeners, function(l) return not l.deleted end)
	local threads = {}
	for thread_id, thread in pairs(private.threads) do
		if not thread.killed then
			threads[thread_id] = thread
		end
	end
	private.threads = threads

	for thread_id, thread in pairs(private.threads) do
		if not thread.killed then
			local k = thread.k
			thread.k = nil
			public.thread_id = thread_id
			k()
			public.thread_id = nil
			if not thread.k then
				thread.killed = true
			end
		end
	end
end

function public.event_listener(event, action)
	local self = {}
	
	local listener = { event=event, action=action }
	
	function self:set_action(action)
		listener.action = action
	end
	
	function self:start()
		Aux.util.set_add(private.event_listeners, listener)
		AuxControlFrame:RegisterEvent(event)
		return self
	end
	
	function self:stop()
		listener.deleted = true
		if not Aux.util.any(Aux.util.set_to_array(private.event_listeners), function(l) return l.event == event end) then
			AuxControlFrame:UnregisterEvent(event)
		end
		return self
	end
	
	return self
end

function public.on_next_event(event, callback)
	local listener = public.event_listener(event)
	
	listener:set_action(function()
		listener:stop()
		return callback()
	end)
	
	listener:start()
end

function public.on_next_update(callback)
	return public.new_thread(callback)
end

function public.as_soon_as(p, callback)
	return public.new_thread(function()
		return public.wait_until(p, callback)
	end)
end

do
	local next_thread_id = 1
	function public.new_thread(k)
		local thread_id = next_thread_id
		next_thread_id = next_thread_id + 1
		private.threads[thread_id] = { k = k }
		return thread_id
	end
end

function public.kill_thread(thread_id)
	private.threads[thread_id].killed = true
end

function public.wait(...)
	local k = tremove(arg, 1)
	private.threads[public.thread_id].k = function() return k(unpack(arg)) end
end

function public.wait_until(p, ...)
	local k = tremove(arg, 1)
	if p() then
		return k(unpack(arg))
	else
		return public.wait(public.wait_until, p, function() return k(unpack(arg)) end)
	end
end
