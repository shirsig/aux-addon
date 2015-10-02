Aux.control = {}

local events = {}

local event_listeners = {}

local update_listeners = {}

function Aux.util.controller()
	local ready, continuation
	return {
		
	}
end

function Aux.util.event_listener(event, action)
	return {
		start = function()
			tinsert(events, f)
		end,
		stop = function()
			Aux.util.remove(events, f)
		end
	
	
	}
end







function Aux.control.onevent()

end


function Aux.control.onupdate()










local listen_for_event(listener)
	tinsert(event_listeners, listener)
	return function()
		Aux.util.remove(event_listeners, listener)
	end
end

function wait_for_event(event)
	return function

end