module Views

using .Helpers
using Dash
using DashBase
using DashBootstrapComponents
using DashCoreComponents
using DashHtmlComponents
using DashTable
using CSV
using DataFrames
using JSONTables
using Plots

function loadingWidget()
    return dbc_spinner(; color="primary")
end

function rawDataFrame(df, nbrows=10)
    names_ = names(df)
    thead = html_tr([html_th(col) for col in names_])
    tbody = map(1:min(nbrows, size(df, 1))) do row
        html_tr([html_td(string(df[row, col])) for col in names_])
    end
    return dbc_table(
        [html_thead(thead), html_tbody(tbody)];
        bordered=true,
        hover=true,
        striped=true,
        responsive=true,
    )
end

function dataPreview(app, dataID, previewID="data-preview")
	view = dbc_card() do
		dbc_cardheader("Data preview"),
		dbc_cardbody() do
			html_div(; id="$previewID") do
				loadingWidget()
			end
		end
	end
    callback!(
        app,
        Output(previewID, "children"),
        Input(dataID, "children"),
    ) do selected_data, preview_nb_rows, showCleanedData
        datadir = joinpath(@__DIR__, "..", "data")
        datafile = joinpath(datadir, string(selected_data))
        if iszero(filesize(datafile))
            html_p("Invalid data file")
        else
            df = CSV.read(datafile, DataFrame)
            rawDataFrame(df)
        end
    end
	return view
end

end
