aux.module 'control'

event_frame = CreateFrame('Frame')
listeners = {}
threads = {}
public.thread_id = nil

function m.LOAD()
	m.event_frame:SetScript('OnUpdate', m.UPDATE)
	m.event_frame:SetScript('OnEvent', m.EVENT)
end

function EVENT()
	for _, listener in m.listeners do
		if event == listener.event and not listener.killed then
			listener.cb(listener.kill)
		end
	end
end

function UPDATE()
	for _, listener in m.listeners do
		if not aux.util.any(m.listeners, function(l) return not l.killed and l.event == listener.event end) then
			m.event_frame:UnregisterEvent(listener.event)
		end
	end

	m.listeners = aux.util.filter(m.listeners, function(l) return not l.killed end)
	m.threads = aux.util.filter(m.threads, function(th) return not th.killed end)

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

do
	local id = 0
	function m.id()
		id = id + 1
		return id
	end
end

function public.kill_listener(listener_id)
	for _, listener in {m.listeners[listener_id]} do
		listener.killed = true
	end
end

function public.kill_thread(thread_id)
	for _, thread in {m.threads[thread_id]} do
		thread.killed = true
	end
end

function public.event_listener(event, cb)
	local listener_id = m.id()
	m.listeners[listener_id] = {event=event, cb=cb, kill=function(...) if arg.n == 0 or arg[1] then m.kill_listener(listener_id) end end}
	m.event_frame:RegisterEvent(event)
	return listener_id
end

function public.on_next_event(event, callback)
	m.event_listener(event, function(kill)
		callback()
		kill()
	end)
end

function public.thread(k, ...)
	local thread_id = m.id()
	m.threads[thread_id] = {k = aux.C(k, unpack(arg))}
	return thread_id
end

function public.wait(k, ...)
	if type(k) == 'number' then
		m.when(function() k = k - 1 return k <= 1 end, unpack(arg))
	else
		m.threads[m.thread_id].k = aux.C(k, unpack(arg))
	end
end

function public.when(p, k, ...)
	if p() then
		return k(unpack(arg))
	else
		return m.wait(m.when, p, aux.C(k, unpack(arg)))
	end
end
