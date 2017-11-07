module 'aux'

local T = require 'T'

local event_frame = CreateFrame'Frame'

local listeners, threads = T.acquire(), T.acquire()

local thread_id
function M.thread_id() return thread_id end

function handle.LOAD()
	event_frame:SetScript('OnUpdate', UPDATE)
	event_frame:SetScript('OnEvent', EVENT)
end

function EVENT()
	for id, listener in listeners do
		if listener.killed then
			listeners[id] = nil
		elseif event == listener.event then
			listener.cb(listener.kill)
		end
	end
end

do
	function UPDATE()
		for _, listener in listeners do
			local event, needed = listener.event, false
			for _, listener in listeners do
				needed = needed or listener.event == event and not listener.killed
			end
			if not needed then
				event_frame:UnregisterEvent(event)
			end
		end

		for id, thread in threads do
			if thread.killed or not thread.k then
				threads[id] = nil
			else
				local k = thread.k
				thread.k = nil
				thread_id = id
				k()
				thread_id = nil
			end
		end
	end
end

do
	local id = 0
	function unique_id()
		id = id + 1
		return id
	end
end

function M.kill_listener(listener_id)
	local listener = listeners[listener_id]
	if listener then
		listener.killed = true
	end
end

function M.kill_thread(thread_id)
	local thread = threads[thread_id]
	if thread then
		thread.killed = true
	end
end

function M.event_listener(event, cb)
	local listener_id = unique_id()
	listeners[listener_id] = T.map(
		'event', event,
		'cb', cb,
		'kill', T.vararg-function(arg) if getn(arg) == 0 or arg[1] then kill_listener(listener_id) end end
	)
	event_frame:RegisterEvent(event)
	return listener_id
end

function M.on_next_event(event, callback)
	event_listener(event, function(kill) callback(); kill() end)
end

do
	local mt = {
		__call = function(self)
			T.temp(self)
			return self.f(unpack(self))
		end,
	}

	M.thread = T.vararg-function(arg)
		T.static(arg)
		arg.f = tremove(arg, 1)
		local thread_id = unique_id()
		threads[thread_id] = T.map('k', setmetatable(arg, mt))
		return thread_id
	end

	M.wait = T.vararg-function(arg)
		T.static(arg)
		arg.f = tremove(arg, 1)
		threads[thread_id].k = setmetatable(arg, mt)
	end
end

M.when = T.vararg-function(arg)
	local c = tremove(arg, 1)
	local k = tremove(arg, 1)
	if c() then
		return k(unpack(arg))
	else
		return wait(when, c, k, unpack(arg))
	end
end
