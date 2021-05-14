module Callbacks


using ..SaleDSS: ID

callbacks = Dict{Symbol, Function}()

callbacks[:afterPickDataSet] = function(app)
end

function setupCallbacks!(app)
	for (_, setCallback!) in callbacks
		setCallback!(app)
	end
	return app
end

end
