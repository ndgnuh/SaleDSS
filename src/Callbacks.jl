module Callbacks

using ..SaleDSS: ID, STF, SIG
using ..Views
using ..Process
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
using JSON3
using JLD2

function loadingID(id)
    return "$(id)-loading"
end

callbacks = Dict{Symbol,Function}()

# Initialize

callbacks[:init] = function (app)
    callback!(#
        app,
        Output(ID.DT_SELECT, "options"),
        Input(SIG.INIT, "children"),
    ) do _
        datapath = normpath(joinpath(@__DIR__, "..", "data"))
        datafiles = readdir(datapath)
        datafiles = filter(endswith(".csv"), datafiles)
        datapath = joinpath.(datapath, datafiles)
        [(label=l, value=v) for (l, v) in zip(datafiles, datapath)]
    end
end

# Data & flower selection

callbacks[:dt_input] = function (app)
    callback!(#
        app,
        Output(ID.DT_OUTPUT, "children"),
        Output(SIG.POST_DATA_SEL, "children"),
        Input(ID.DT_SELECT, "value"),
    ) do path
        if isnothing(path)
            return "", nothing
        else
            try
                df = CSV.read(path, DataFrame)
                jldopen(STF, "w") do f
                    f["data"] = df
                end
                Views.rawDF(df, 3), ""
            catch error
                "Unable to read file: $(error)", nothing
            end
        end
    end
end

#TODO
#callbacks[:dt_process] = function(app)
#end

# aggregation

callbacks[:ag_init] = function (app)
    callback!(#
        app,
        Output(ID.AG_SELECT_ID, "options"),
        Output(ID.AG_SELECT_ID, "value"),
        Input(SIG.POST_DATA_SEL, "children"),
    ) do sig
        if !isfile(STF)
            return [], nothing
        else
            data = jldopen(f -> f["data"], STF)
            columns = names(data)
            options = map(columns) do name
                (value=name, label=name)
            end
            value = findfirst(occursin("id"), lowercase.(columns))
            if isnothing(value)
                options, nothing
            else
                options, options[value].value
            end
        end
    end
end

callbacks[:ag_add] = function (app)
    function add!(children, idx)
        data = jldopen(f -> f["data"], STF)
        columns = names(data)
        sCol = dbc_select(;
            id=(type=ID.AG_SEL_COL, index=idx),
            options=[(label=c, value=c) for c in columns],
        )
        sType = dbc_select(;
            id=(type=ID.AG_SEL_TYPE, index=idx),
            options=[(label=t, value=t) for t in propertynames(Process.TYPES)],
        )
        sAgg = dbc_select(;
            id=(type=ID.AG_SEL_AG, index=idx),
            options=[(label=t, value=t) for t in propertynames(Process.AGG_TYPES)],
        )
        sDelete = dbc_button("delete"; color="danger", id=(type=ID.AG_SEL_DEL, index=idx))
        s = html_div([
            html_br(),
            dbc_row([#
                dbc_col(sCol),
                dbc_col(sType),
                dbc_col(sAgg),
                dbc_col(sDelete),
            ]),
        ])
        if isempty(children)
            return [s]
        else
            push!(children, s)
            children
        end
    end

    function del!(children, idx)
        deleteat!(children, idx)
        return children
    end
    callback!(
        app,#
        Output(ID.AG_AGS, "children"),
        Input(ID.AG_ADD_BTN, "n_clicks_timestamp"),
        Input((type=ID.AG_SEL_DEL, index=ALL), "n_clicks_timestamp"),
        Input(SIG.POST_DATA_SEL, "children"),
        State(ID.AG_AGS, "children"),
    ) do add_ts, del_tss, sig, children
        if !isfile(STF)
            return []
        end
        timestamps = something.([add_ts; del_tss...], 0)
        _, maxidx = findmax(something.(timestamps, 0))
        idx = length(something(children, [])) + 1
        if something(maxidx, 1) > 1
            del!(children, maxidx)
        else
            add!(children, idx)
        end
    end
end

callbacks[:pickdata] = function (app)
    callback!(app, Output(ID.SIG_DATA, "children"), Input(ID.DATA_PICKER, "value")) do bname
        if !isempty(something(bname, ""))
            dataFile = joinpath(ID.dataDirectory, string(bname))
            if isfile(dataFile)
                data = CSV.read(dataFile, DataFrame)
                JLD2.jldopen(STF, "w") do f
                    f["data"] = data
                    f["columns"] = names(data)
                end
            end
        end
        return ""
    end
end

callbacks[:previewData] = function (app)
    return callback!(
        app,#
        Output(ID.DATA_PREVIEW, "children"),
        Input(ID.SIG_DATA, "children"),
    ) do s
        if !isfile(STF)
            return ""
        end
        if !isnothing(s)
            data = JLD2.jldopen(STF, "r") do f
                f["data"]
            end
            Views.rawDataFrame(data)
        else
            ""
        end
    end
end

callbacks[:aggid] = function (app)
    callback!(app, Output(ID.AGG, "children"), Input(ID.SIG_DATA, "children")) do sig
        if isnothing(sig)
            return ""
        end
        if !isfile(STF)
            return ""
        end
        data, columns = jldopen(STF) do f
            f["data"], f["columns"]
        end
        Views.aggIDSelection(columns)
    end
end

callbacks[:aggrows] = function (app)
    callback!(
        app, #
        Output(ID.AGG_ROWS, "children"),
        Input(ID.SIG_DATA, "children"),
    ) do sig
        if !isfile(STF)
            return ""
        end
        columns = jldopen(f -> f["columns"], STF)
        data = jldopen(f -> f["data"], STF)
        colScitype = Process.typeByColumns(data)
        Views.aggregationRows(colScitype)
    end
end

callbacks[:aggselected] = function (app)
    callback!(#
        app,
        Output(ID.AGG_SUBMIT_BTN, "style"),
        Input(ID.AGG_ROWS, "children"),
    ) do rows
        if isempty(something(rows, ""))
            Dict("display" => "none")
        end
    end
end

callbacks[:aggsubmitted] = function (app)
    callback!(#
        app,
        Output(ID.AGG_RESULT, "children"),
        Input(ID.AGG_SUBMIT_BTN, "n_clicks"),
        Input(ID.AGG_ROWS, "children"),
        Input(ID.AGG_ID_SELECTION, "value"),
    ) do _, rows, id
        if !isempty(something(rows, []))
            aggSelects = map(rows) do r
                col = r.props.children[1].props.children.props.children
                sel = r.props.children[3].props.children.props.value
                selFunc = getproperty(Process.AGG_TYPES, Symbol(sel))
                Symbol(col) => selFunc
            end
            aggSelects = filter(aggSelects) do sel
                !isnothing(sel[2])
            end
            aggSelects = map(aggSelects) do sel
                sel[1] => sel[2] => sel[1]
            end
            data = jldopen(f -> f["data"], STF)
            aggData = combine(groupby(data, id), aggSelects...)
            jldopen(STF, "w") do f
                f["aggdata"] = aggData
                f["data"] = data
                f["columns"] = names(data)
            end
            [
                html_div("Records: " * string(size(aggData, 1))),#
                Views.rawDataFrame(aggData),
            ]
        end
    end
end

# CLUSTERING

callbacks[:cl_input] = function (app)
    callback!(
        app, #
        Output(ID.CL_PLOT_X, "options"),
        Output(ID.CL_PLOT_Y, "options"),
        Input(ID.SIG_DATA, "children"),
        Input(ID.AGG_ID_SELECTION, "value"),
    ) do sig, _
        if isfile(STF)
            columns = jldopen(f -> f["columns"], STF)
            options = Views.genOptions(columns)
            options, options
        else
            nothing, nothing
        end
    end
end

callbacks[:cl_run] = function (app)
    callback!(#
        app,
        Output(ID.SIG_CL_DONE, "children"),
        Input(ID.CL_RUN_BTN, "n_clicks"),
        State(ID.AGG_ID_SELECTION, "value"),
        State(ID.CL_NCL, "value"),
        State(ID.CL_SEL_MTH, "value"),
    ) do _, id, ncl, mth
        if !isfile(STF)
            return nothing
        end
        hasDist = jldopen(f -> "dists" ∈ keys(f), STF)
        # caching distances
        dists = if !hasDist
            aggdata = jldopen(f -> f["aggdata"], STF)
            dists = Process.gower(select(aggdata, Not(id)))
            jldopen(STF, "a") do f
                f["dists"] = dists
            end
            dists
        else
            jldopen(f -> f["dists"], STF)
        end
        result = Process.cluster(mth, dists, ncl)
        jldopen("clres.jld2", "w") do f
            f["result"] = result
        end
        return 1
    end
end

callbacks[:cl_done] = function (app)
    callback!(
        app,#
        Output(ID.CL_PLOT, "children"),
        Input(ID.SIG_CL_DONE, "children"),
        Input(ID.CL_PLOT_X, "value"),
        Input(ID.CL_PLOT_Y, "value"),
        State(ID.AGG_ID_SELECTION, "value"),
    ) do sig, xcol, ycol, id
        if !isfile("clres.jld2") || !isfile(STF) || isnothing(xcol) || isnothing(ycol)
            nothing
        else
            data, aggdata = jldopen(f -> (f["data"], f["aggdata"]), STF)
            result = jldopen(f -> f["result"], "clres.jld2")
            aggdata.as = result.assignments
            df = innerjoin(data, aggdata; on=id, makeunique=true)
            df = select(df, [xcol, ycol, "as"])
            rename!(df, [:x, :y, :as])
            Views.pl_scatter(df)
        end
    end
end

callbacks[:ex] = function (app)
    callback!(
        app,
        Output("test-add", "children"),
        Input("add", "n_clicks"),
        State("test-add", "children"),
    ) do _, children
        options = Views.genOptions(rand(-3:3, 5))
        s = dbc_select(; options=options, id=(type="Added_", index=ALL))
        @show children
        if isnothing(children)
            return [s]
        else
            push!(children, s)
            children
        end
    end

    callback!(
        app,
        Output("group-output", "children"),
        Input((type="Added_", index=ALL), "value"),
    ) do values
        string(values)
    end
end

function setupCallbacks!(app)
    for (_, setCallback!) in callbacks
        setCallback!(app)
    end
    return app
end

end
