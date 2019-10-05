select(2, ...) 'aux'

local event_frame = CreateFrame'Frame'

local listeners = {}

function event.AUX_LOADED()
	event_frame:SetScript('OnUpdate', function()
        for _, listener in pairs(listeners) do
            local event, needed = listener.event, false
            for _, listener in pairs(listeners) do
                needed = needed or listener.event == event and not listener.killed
            end
            if not needed then
                event_frame:UnregisterEvent(event)
            end
        end
    end)

	event_frame:SetScript('OnEvent', function(_, event, ...)
        for id, listener in pairs(listeners) do
            if listener.killed then
                listeners[id] = nil
            elseif event == listener.event then
                listener.cb(...)
            end
        end
    end)
end

function M.kill_listener(listener_id)
	local listener = listeners[listener_id]
	if listener then
		listener.killed = true
	end
end

do
    local id = 0
    function M.event_listener(event, cb)
        local listener_id = id
        id = id + 1
        listeners[listener_id] = {
            event = event,
            cb = cb,
        }
        event_frame:RegisterEvent(event)
        return listener_id
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
            end
        end
    end)

    function M.coro_thread(f)
        local thread = coroutine.create(f)
        local thread_id = tostring(thread)
        threads[thread_id] = thread
        assert(coroutine.resume(thread))
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
