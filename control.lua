aux 'core'

event_frame = CreateFrame('Frame')

local listeners, threads = t, t

local thread_id
function public.thread_id.get() return thread_id end

function LOAD()
	event_frame:SetScript('OnUpdate', UPDATE)
	event_frame:SetScript('OnEvent', EVENT)
end

function EVENT()
	for _, listener in listeners do
		if event == listener.event and not listener.killed then
			listener.cb(listener.kill)
		end
	end
end

function UPDATE()
	for _, listener in listeners do
		if not any(listeners, function(l) return not l.killed and l.event == listener.event end) then
			event_frame:UnregisterEvent(listener.event)
		end
	end

	filter(listeners, function(l) return not l.killed end)
	filter(threads, function(th) return not th.killed end)

	for id, thread in threads do
		if not thread.killed then
			local k = thread.k
			thread.k = nil
			thread_id = id
			k()
			thread_id = nil
			if not thread.k then
				thread.killed = true
			end
		end
	end
end

do
	local id = 0
	function private.id.get() id = id + 1; return id end
end

function public.kill_listener(listener_id)
	for listener in present(listeners[listener_id]) do
		listener.killed = true
	end
end

function public.kill_thread(thread_id)
	for thread in present(threads[thread_id]) do
		thread.killed = true
	end
end

function public.event_listener(event, cb)
	local listener_id = id
	listeners[listener_id] = {event=event, cb=cb, kill=function(...) temp=arg if arg.n == 0 or arg[1] then kill_listener(listener_id) end end}
	event_frame:RegisterEvent(event)
	return listener_id
end

function public.on_next_event(event, callback)
	event_listener(event, function(kill)
		callback()
		kill()
	end)
end

function public.thread(k, ...) temp=arg
	local thread_id = id
	threads[thread_id] = {k = L(k, unpack(arg))}
	return thread_id
end

function public.wait(k, ...) temp=arg
	if type(k) == 'number' then
		when(function() k = k - 1 return k <= 1 end, unpack(arg))
	else
		threads[thread_id].k = L(k, unpack(arg))
	end
end

function public.when(p, k, ...) temp=arg
	if p() then
		return k(unpack(arg))
	else
		return wait(when, p, k, unpack(arg))
	end
end
