local m, public, private = Aux.module'control'

private.event_frame = CreateFrame('Frame')
private.event_listeners = {}
private.threads = {}
public.thread_id = nil

function public.LOAD()
	m.event_frame:SetScript('OnUpdate', m.on_update)
	m.event_frame:SetScript('OnEvent', m.on_event)
end

function public.on_event()
	for listener, _ in m.event_listeners do
		if event == listener.event and not listener.deleted then
			listener.action()
		end
	end
end

function public.on_update()
	m.event_listeners = Aux.util.set_filter(m.event_listeners, function(l) return not l.deleted end)
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
		Aux.util.set_add(m.event_listeners, listener)
		m.event_frame:RegisterEvent(event)
		return self
	end
	
	function self:stop()
		listener.deleted = true
		if not Aux.util.any(Aux.util.set_to_array(m.event_listeners), function(l) return l.event == event end) then
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
	return m.new_thread(function()
		return m.wait_until(p, callback)
	end)
end

do
	local next_thread_id = 1
	function public.new_thread(k)
		local thread_id = next_thread_id
		next_thread_id = next_thread_id + 1
		m.threads[thread_id] = { k = k }
		return thread_id
	end
end

function public.kill_thread(thread_id)
	if m.threads[thread_id] then
		m.threads[thread_id].killed = true
	end
end

function public.wait(...)
	if type(arg[1]) == 'number' then
		local count = tremove(arg, 1)
		m.wait_until(function() count = count - 1 return count <= 0 end, unpack(arg))
	else
		local k = tremove(arg, 1)
		m.threads[m.thread_id].k = function() return k(unpack(arg)) end
	end
end

function public.wait_until(p, ...)
	local k = tremove(arg, 1)
	if p() then
		return k(unpack(arg))
	else
		return m.wait(m.wait_until, p, function() return k(unpack(arg)) end)
	end
end
