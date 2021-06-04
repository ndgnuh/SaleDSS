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

state = Dict()

ID = (#
    CLEAR_CACHE="clear-cache",
    DT_STORE="data-store",
    DT_SELECT="dt:select",
    DT_PROCESSES="dt:processes",
    DT_OUTPUT="dt:data",
    DT_PROCESSES_OUTPUT="dt:processes-output",
    # OLDCODE
    SIG_DATA="signal-data",
    DATA_PICKER="dataPicker",
    DATA="data",
    DATA_LOADING="data-loading",
    DATA_NAMES="data-names",
    DATA_NAMES_TYPES="data-names-by-type",
    DATA_PREVIEW="data-preview",
    dataDirectory=joinpath(@__DIR__, "..", "data"),
    # AGGREGATION
    AG_UI="ag-ui",
    AG_DT_STORE="aggdata-store",
    AG_AGS="ag-aggregations",
    AG_ADD_BTN="ag-add-btn",
    AG_SEL_ID="ag-select-id",
    AG_SEL_COL="ag-select-column",
    AG_SEL_TYPE="ag-select-type",
    AG_SEL_AG="ag-select-aggregation",
    AG_SEL_DEL="ag-select-delete",
    AG_OUTPUT="ag-output",
    # old AG
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
    CL_ELBOW_BTN="cl-run-elbow",
    CL_PLOT="cl-plot",
)

SIG = (#
    INIT="init",
    POST_DATA_SEL="post:data-sel",
    POST_CL="post:cl",
    POST_AG="post-ag",
)

include("Process.jl")
using .Process
include("alerts.jl")
using .Alerts
include("Views.jl")
using .Views
include("Callbacks.jl")
using .Callbacks

include("dataPicker.jl")
include("navigationBar.jl")
include("dataView.jl")
include("cleaning.jl")
include("plots.jl")
include("draft.jl")

function setup_layout!(app)
    return app.layout = dbc_container(
        [
            #html_div() do
            #    dbc_button("add"; id="add"),#
            #    html_div(; id="test-add"),
            #    html_div(; id="group-output")
            #end,
            html_div(Views.states())
            html_h1("K-Cluster Tool")
            html_div(; className="divider")
            html_div(
                [
                    html_h4("Choose dataset")
                    dbc_row() do
                        [#
                            dbc_col(Views.dt_input(); width=3)
                            dbc_col(Views.dt_output(); width=9)
                        ]
                    end
                ],
            )
            html_br()
            html_div(
                [
                    html_h4("Data aggregate")
                    html_div(
                        [#
                            Views.ag_input()
                            html_br()
                            Views.ag_output()
                        ];
                        id=ID.AG_UI,
                    )
                ],
            )

            # CLEAN & CLUSTERING
            html_br()
            html_h4("Clustering")
            html_div([#
                Views.cl_input()
                html_br()
                Views.cl_output()
            ])
        ],
        ;
        id="init",
    )
end

function main()
    app = dash(; external_stylesheets=[dbc_themes.DARKLY])
    setup_layout!(app)
    Callbacks.setupCallbacks!(app, state)
    host = get(ENV, "HOST", "0.0.0.0")
    port = get(ENV, "PORT", "8080")
    debug = if get(ENV, "DEBUG", "false") == "true"
        true
    else
        false
    end
    return run_server(app, "0.0.0.0", 8080; debug=debug)
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
