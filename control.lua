select(2, ...) 'aux'

local T = require 'T'

local event_frame = CreateFrame'Frame'

local listeners, threads = {}, {}

local thread_id
function M.thread_id() return thread_id end

function handle.LOAD()
	event_frame:SetScript('OnUpdate', UPDATE)
	event_frame:SetScript('OnEvent', EVENT)
end

function EVENT(_, event, ...)
	for id, listener in pairs(listeners) do
		if listener.killed then
			listeners[id] = nil
		elseif event == listener.event then
			listener.cb(listener.kill, ...)
		end
	end
end

do
	function UPDATE()
		for _, listener in pairs(listeners) do
			local event, needed = listener.event, false
			for _, listener in pairs(listeners) do
				needed = needed or listener.event == event and not listener.killed
			end
			if not needed then
				event_frame:UnregisterEvent(event)
			end
		end

		for id, thread in pairs(threads) do
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
		'kill', function(...) if select('#', ...) == 0 or select(1, ...) then kill_listener(listener_id) end end
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
			return self.f(unpack(self))
		end,
	}

	 function M.thread(f, ...)
		local thread_id = unique_id()
		threads[thread_id] = T.map('k', setmetatable({f = f, ...}, mt))
		return thread_id
	end

	function M.wait(f, ...)
		threads[thread_id].k = setmetatable({f = f, ...}, mt)
	end
end

function M.when(c, k, ...)
	if c() then
		return k(...)
	else
		return wait(when, c, k, ...)
	end
end

do
    local threads, kill_signals = {}, {}
    CreateFrame'Frame':SetScript('OnUpdate', function()
        for thread_id, thread in pairs(threads) do
            local status = coroutine.status(thread)
            if status == 'dead' or kill_signals[thread_id] then
                kill_signals[thread_id] = nil
                threads[thread_id] = nil
            elseif status == 'suspended' then
                assert(coroutine.resume(thread))
                return -- TODO
            end
        end
    end)

    function M.coro_thread(f)
        local thread = coroutine.create(f)
        local thread_id = tostring(thread)
        threads[thread_id] = thread
        assert(coroutine.resume(thread))
        return thread_id
    end

    function M.coro_wait()
        coroutine.yield()
    end

    function M.coro_kill(thread_id)
        kill_signals[thread_id] = true
    end

    function M.coro_id()
        return tostring(coroutine.running())
    end
end
