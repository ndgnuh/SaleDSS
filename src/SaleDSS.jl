"""
Data flow:

1. Select dataset, clean
2. Detect types and the ID field 
3. Aggregate by customer ID
4. Calculate distances
5. Clustering
6. Plotting
7. Explain <- were are here (maybe 5,6,7 too)
"""
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

"""
State file
"""
STF = "state.jld2"

ID = (
    SIG_DATA="signal-data",
    DATA_PICKER="dataPicker",
    DATA="data",
    DATA_LOADING="data-loading",
    DATA_NAMES="data-names",
    DATA_NAMES_TYPES="data-names-by-type",
    DATA_PREVIEW="data-preview",
    dataDirectory=joinpath(@__DIR__, "..", "data"),
    # AGGREGATION
    AGG_MAIN_ID="agg-main-id",
    AGG_ROWS="agg-rows",
    AGG_ID_SELECTION="agg-id-select",
    AGG_COUNT="aggregation-count",
    AGG_SUBMIT="aggregation-submit",
    AGG_SUBMIT_BTN="aggregation-submit-btn",
    AGG_RESULT="aggregation-result",
    AGG="aggregation",
    # CLUSTERING
	SIG_CL_DONE="cl-done",
    CL_NCL="cl-num-cluster",
    CL_PLOT_X="cl-plot-x",
    CL_PLOT_Y="cl-plot-y",
    CL_SEL_MTH="cl-select-method",
    CL_RUN_BTN="cl-run",
    CL_PLOT="cl-plot",
)

include("Process.jl")
using .Process
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
            Views.states()...,
            html_h1("Sale DSS"),
            html_div(; className="divider"),
            html_h4("Choose dataset"),
            dbc_row() do
                dbc_col(; width=5) do
                    dbc_card() do
                        dbc_cardheader("Input"),
                        dbc_cardbody() do
                            Views.dataPicker()
                        end
                    end
                end,
                dbc_col(; width=7) do
                    Views.dataview()
                end
            end,
            html_br(),
            html_h4("Data aggregate"),
            dbc_card() do
                dbc_cardheader("Selection"),
                dbc_cardbody() do
                    Views.aggregationView()
                end
            end,
            html_br(),
            Views.aggregationResult(),

            # CLEAN & CLUSTERING
            html_br(),
            html_h4("Clustering"),
            Views.cl_UI()
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
        if isfile(STF)
            rm(STF)
        end
        main()
    catch e
        @error e
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main_with_try_catch()
end

end # module
