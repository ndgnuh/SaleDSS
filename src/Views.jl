module Views

using ..SaleDSS: ID, STF
using ..Process: TYPES, AGG_TYPES
using ..Process

using Dates
using Dash
using DashBase
using DashBootstrapComponents
using DashCoreComponents
using DashHtmlComponents
using DashTable
using CSV
using DataFrames
using JSONTables
using PlotlyJS
using JLD2

include("plots.jl")

function genOptions(arr)
    return [(value=a, label=a) for a in arr]
end

function states()
    names = Dict(
        ID.SIG_CL_DONE => "",
        ID.SIG_DATA => "",
        ID.DATA => "",
        ID.DATA_NAMES => "",
        ID.AGG_COUNT => 0,
    )
    return [
        html_div(value; id=name, style=Dict("display" => "None")) for (name, value) in names
    ]
end

function loadingWidget()
    return dbc_spinner(; color="primary")
end

function rawDataFrame(df, nbrows=3)
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
rawDF = rawDataFrame

function dataPicker(id=ID.DATA_PICKER)
    datadir = joinpath(@__DIR__, "..", "data")
    files = filter(endswith("csv"), readdir(datadir))
    options = map(files) do file
        Dict("label" => file, "value" => file)
    end
    return html_div(
        [
            dbc_label("Select dataset")
            dcc_loading(dbc_select(; id=id, options=options))
        ]
    )
end

function dataview()
    return view = dbc_card() do
        dbc_cardheader("Data preview"),
        dbc_cardbody() do
            dcc_loading(html_div(; id=ID.DATA_PREVIEW))
        end
    end
end

function select(options::AbstractVector{T}, selected::Union{T,Nothing}; id) where {T}
    return dbc_select(; id=id, options=Dict(o => o for o in options), value=selected)
end
function select(options, selectedindex; id)
    return select(options, options[selectedindex]; id=id)
end

function aggIDSelection(columns)
    lc = lowercase.(columns)
    i = findfirst(@. occursin("customer", lc))
    options = map(columns) do c
        (value=c, label=c)
    end
    html_div() do
        dbc_label("ID Column: "),
        dbc_select(; #
            options=options,
            value=string(columns[something(i, 1)]),
            id=ID.AGG_ID_SELECTION,
        )
    end
end
function aggIDSelection()
    return dbc_select(; options=[], id=ID.AGG_ID_SELECTION)
end

function aggregationRows(colScitype)
    function row(col)
        dbc_row() do
            dbc_col(; width=4) do
                dbc_label(col)
            end,
            dbc_col(; width=4) do
                dbc_select(; #
                    options=genOptions(keys(TYPES)),
                    id="$(col)-scitype",
                    value=colScitype[col],
                )
            end,
            dbc_col(; width=4) do
                dbc_select(; #
                    options=genOptions(keys(AGG_TYPES)),
                    id="$(col)-aggtype",
                    value=Process.defaultAggType(colScitype[col]),
                )
            end
        end
    end
    rows = [row(name) for name in keys(colScitype)]
    return rows
end

function aggregationView()
    return html_div() do
        html_div(aggIDSelection(); id=ID.AGG), #
        html_br(),
        html_div(; id=ID.AGG_ROWS),
        html_br(),
        html_div(; id=ID.AGG_SUBMIT) do
            dbc_button("OK"; color="primary", id=ID.AGG_SUBMIT_BTN)
        end
    end
end

function aggregationResult()
    dbc_card() do
        dbc_cardheader("Aggregated data"),
        dbc_cardbody() do
            html_div(; id=ID.AGG_RESULT)
        end
    end
end

function cl_input()
    body = dbc_formgroup([#
        dbc_label("Number of cluster"),
        dbc_input(; type="number", value=3, id=ID.CL_NCL),
        dbc_label("Clustering method"),
        dbc_select(;#
            options=genOptions(Process.CL_METHODS),
            value="PAM",
            id=ID.CL_SEL_MTH,
        ),
        dbc_label("Plot X axis"),
        dbc_select(; id=ID.CL_PLOT_X),
        dbc_label("Plot Y axis"),
        dbc_select(; id=ID.CL_PLOT_Y),
        dbc_label("Run:"),
        html_div(
            dbc_buttongroup(
                [
                    dbc_button("Elbow"; id=ID.CL_ELBOW_BTN, color="primary")
                    dbc_button("Cluster"; id=ID.CL_RUN_BTN, color="primary")
                ],
            ),
        ),
    ])
    dbc_card() do
        dbc_cardheader("Input"), dbc_cardbody(body)
    end
end

function cl_output()
    dbc_card() do
        dbc_cardheader("Output"),
        dbc_cardbody([
            dbc_label("Result plot")
            dcc_loading(html_div(""; id=ID.CL_PLOT))
        ])
    end
end

# DATA INPUT

function dt_input()
    # card body
    body = [#
        dbc_label("Select dataset"),
        dcc_loading(; children=dbc_select(; id=ID.DT_SELECT)),
        dbc_cardlink(#
            html_a(
                "Clear cache";#
                href="javascript:void(0)",
                id=ID.CLEAR_CACHE,
            ),
        ),
    ]

    # The layout
    dbc_card() do
        [#
            dbc_cardheader(),
            dbc_cardbody(() -> body),
        ]
    end
end

function dt_output()
    dbc_card() do
        [#
            dbc_cardheader("Preview"),
            dbc_cardbody() do
                dcc_loading(
                    [
                        dcc_store(; id=ID.DT_STORE, storage_type="session")
                        html_div(; id=ID.DT_OUTPUT)
                    ],
                )
            end,
        ]
    end
end

# Aggregate

function ag_input()
    dbc_card() do
        dbc_cardheader("Input"),
        dbc_cardbody() do
            dbc_formgroup([#
                dbc_label("Main ID"),
                dcc_loading(dbc_select(; id=ID.AG_SEL_ID)),
                dbc_label("Aggregations"),
                dbc_button("Add"; id=ID.AG_ADD_BTN, color="primary"),
                dcc_loading(html_div(; id=ID.AG_AGS)),
            ])
        end
    end
end

function ag_output()
    dbc_card() do
        dbc_cardheader("Output"),
        dbc_cardbody() do
            dcc_loading(
                [
                    dcc_store(; id=ID.AG_DT_STORE, storage_type="session")
                    html_div(; id=ID.AG_OUTPUT)
                ],
            )
        end
    end
end

# End module
end
