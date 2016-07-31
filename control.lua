local m, public, private = Aux.module'control'

private.event_frame = CreateFrame('Frame')
private.event_listeners = {}
private.threads = {}
public.thread_id = nil

function public.LOAD()
	m.event_frame:SetScript('OnUpdate', m.on_update)
	m.event_frame:SetScript('OnEvent', m.on_event)
end

function private.on_event()
	for _, listener in m.event_listeners do
		if event == listener.event and not listener.deleted then
			listener.action()
		end
	end
end

function private.on_update()
	m.event_listeners = Aux.util.filter(m.event_listeners, function(l) return not l.deleted end)
	local threads = {}
	for thread_id, thread in m.threads do
		if not thread.killed then
			threads[thread_id] = thread
		end
	end
	m.threads = threads

	for thread_id, thread in m.threads do
		if not thread.killed then
			local k = thread.k
			thread.k = nil
			m.thread_id = thread_id
			k()
			m.thread_id = nil
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
		tinsert(m.event_listeners, listener)
		m.event_frame:RegisterEvent(event)
		return self
	end
	
	function self:stop()
		listener.deleted = true
		if not Aux.util.any(m.event_listeners, function(l) return l.event == event end) then
			m.event_frame:UnregisterEvent(event)
		end
		return self
	end
	
	return self
end

function public.on_next_event(event, callback)
	local listener = m.event_listener(event)
	
	listener:set_action(function()
		listener:stop()
		return callback()
	end)
	
	listener:start()
end

function public.on_next_update(callback)
	return m.new_thread(callback)
end

function public.as_soon_as(p, callback)
	return m.new_thread(m.when, p, callback)
end

function public.new_thread(k, ...)
	local thread_id = Aux.unique()
	m.threads[thread_id] = { k = Aux.f(k, unpack(arg)) }
	return thread_id
end

function public.kill_thread(thread_id)
	if m.threads[thread_id] then
		m.threads[thread_id].killed = true
	end
end

function public.wait_for(k)
	local ret
	m.when(function() return ret end, function() return k(unpack(ret)) end)
	return function(...)
		ret = arg
	end
end

function public.sleep(dt, ...)
	local t0 = GetTime()
	return m.when(function() return GetTime() - t0 >= dt end, unpack(arg))
end

function public.wait(k, ...)
	if type(k) == 'number' then
		m.when(function() k = k - 1 return k <= 0 end, unpack(arg))
	else
		m.threads[m.thread_id].k = Aux.f(k, unpack(arg))
	end
end

function public.when(p, k, ...)
	if p() then
		return k(unpack(arg))
	else
		return m.wait(m.when, p, Aux.f(k, unpack(arg)))
	end
end
