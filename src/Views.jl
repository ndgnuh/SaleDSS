module Views

using ..SaleDSS: ID

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

function dataPicker(id=ID.dataPicker)
    datadir = joinpath(@__DIR__, "..", "data")
    files = filter(endswith("csv"), readdir(datadir))
    options = map(files) do file
        Dict("label" => file, "value" => file)
    end
    return (dbc_label("Select dataset"), dbc_select(; id=id, options=options))
end

function dataPreview(dataID=ID.data, previewID=ID.dataPreview)
    view = dbc_card() do
        dbc_cardheader("Data preview"),
        dbc_cardbody() do
            html_div(; id="$previewID") do
                loadingWidget()
            end
        end
    end
end

end
