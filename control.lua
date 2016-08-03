local m, public, private = Aux.module'control'

private.event_frame = CreateFrame('Frame')
private.event_listeners = {}
private.threads = {}
public.thread_id = nil

function public.LOAD()
	m.event_frame:SetScript('OnUpdate', m.on_update)
	m.event_frame:SetScript('OnEvent', m.on_event)
end

do
	local active_listener

	function public.kill(...)
		Aux.log(arg.n) --TODO
		active_listener.killed = arg.n == 0 or arg[1]
	end

	function private.on_event()
		for thread_id, listener in m.event_listeners do
			if event == listener.event and not listener.killed then
				m.thread_id = thread_id
				active_listener = listener
				listener.cb()
				active_listener = nil
				m.thread_id = nil
			end
		end
	end
end

function private.on_update()
	for _, listener in m.event_listeners do
		if not Aux.util.any(m.event_listeners, function(l) return not l.killed and l.event == listener.event end) then
			m.event_frame:UnregisterEvent(listener.event)
		end
	end

	m.event_listeners = Aux.util.filter(m.event_listeners, function(l) return not l.killed end)
	m.threads = Aux.util.filter(m.threads, function(th) return not th.killed end)

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

function public.event_listener(event, cb)
	local thread_id = Aux.unique()
	m.event_listeners[thread_id] = { event=event, cb=cb }
	m.event_frame:RegisterEvent(event)
	return thread_id
end

function public.on_next_event(event, callback)
	m.event_listener(event, function()
		callback()
		m.kill()
	end)
end

function public.as_soon_as(p, ...)
	return m.thread(m.when, p, unpack(arg))
end

function public.thread(k, ...)
	local thread_id = Aux.unique()
	m.threads[thread_id] = { k = Aux.f(k, unpack(arg)) }
	return thread_id
end

function public.kill_thread(thread_id)
	Aux.log('kek')
	if m.threads[thread_id] then
		m.threads[thread_id].killed = true
	end
end

function public.await(k)
	local ret
	m.when(function() return ret end, function() return k(unpack(ret)) end)
	return setmetatable({}, {
		__call = function(_, ...)
			ret = arg
		end,
		__unm = function()
			return ret ~= nil
		end
	})
end

function public.sleep(seconds, ...)
	local t0 = GetTime()
	return m.when(function() return GetTime() - t0 >= seconds end, unpack(arg))
end

function public.wait(k, ...)
	if type(k) == 'number' then
		m.when(function() k = k - 1 return k <= 1 end, unpack(arg))
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
