module Alerts
using DashBootstrapComponents
using DashHtmlComponents

function warning(args...; kwargs...)
	dbc_alert(args...; color = "warning", kwargs...)
end

function danger(args...; kwargs...)
	dbc_alert(args...; color = "danger", kwargs...)
end

function chooseDataset() 
	dbc_alert("Choose a dataset to continue"; color = "warning")
end

end
