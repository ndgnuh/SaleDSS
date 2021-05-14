module SaleDSS

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

ID = (dataPicker = "dataPicker",
      data = "data",
      dataPreview = "dataPreview"
     )

include("alerts.jl")
using .Alerts
include("Views.jl")
using .Views
include("Callbacks.jl")
using .Callbacks

function df2json(df::AbstractDataFrame)
    return JSONTables.arraytable(df)
end

function json2df(jsonStr::AbstractString)
    return DataFrame(JSONTables.jsontable(jsonStr))
end

include("dataPicker.jl")
include("navigationBar.jl")
include("dataView.jl")
include("cleaning.jl")
include("plots.jl")
include("draft.jl")

function quickCard(title, body)
    dbc_card() do
        dbc_cardheader(title), dbc_cardbody(body)
    end
end

function setup_layout!(app)
    return app.layout = html_div() do
        dbc_container() do
            html_div(; id="currentData", style=Dict("display" => "None")),
            html_h1("Sale DSS"),
            html_div(; className="divider"),
            html_h2("Customer clustering"),
            dbc_row() do
                dbc_col(; width=5) do
                    dbc_card() do
                        dbc_cardheader("Input"),
                        dbc_cardbody() do
                            Views.dataPicker()
                        end
                    end,
                    # Describe
                    html_br(),
                    dbc_card() do
                        dbc_cardheader("Raw description"),
                        dbc_cardbody(Views.loadingWidget(); id="datasetDescription")
                    end
                end,
                dbc_col(; width=7) do
                    Views.dataPreview()
                end
            end
        end
    end
end

function main()
    app = dash(;
        external_stylesheets=[dbc_themes.DARKLY], suppress_callback_exceptions=true
    )
    setup_layout!(app)
    #setup_callback!(app)
    Callbacks.setupCallbacks!(app)
    host = get(ENV, "HOST", "0.0.0.0")
    port = get(ENV, "PORT", "8080")
    return run_server(app, "0.0.0.0", 8080; debug=true)
end

function main_with_try_catch()
    try
        main()
    catch e
        @error e
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main_with_try_catch()
end

end # module
