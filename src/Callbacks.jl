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
using Plots
using JLD2
using CategoricalArrays

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
        Output(ID.AG_SEL_ID, "options"),
        Output(ID.AG_SEL_ID, "value"),
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

callbacks[:ag_output] = function (app)
    callback!(
        app,
        Output(ID.AG_OUTPUT, "children"),
        Output(SIG.POST_AG, "children"),
        Input(SIG.POST_DATA_SEL, "children"),
        Input(ID.AG_SEL_ID, "value"),
        Input((type=ID.AG_SEL_COL, index=ALL), "value"),
        Input((type=ID.AG_SEL_TYPE, index=ALL), "value"),
        Input((type=ID.AG_SEL_AG, index=ALL), "value"),
    ) do _, id, columns, scitypes, aggs
        if !isfile(STF) ||
           isnothing(id) ||
           any(isnothing.(columns)) ||
           any(isnothing.(scitypes)) ||
           any(isnothing.(aggs))
            return "", ""
        end
        # perform cleaning & stuffs here
        aggregations = map(aggs) do agg
            getproperty(Process.AGG_TYPES, Symbol(agg))
        end
        aggregations = map(1:length(columns)) do i
            col = Symbol(columns[i])
            st = getproperty(Process.TYPES, Symbol(scitypes[i]))
            agg = getproperty(Process.AGG_TYPES, Symbol(aggs[i]))
            f = if st === Process.TYPES.CATEGORICAL
                x -> categorical(agg(x))
            elseif st === Process.TYPES.HIERARCHICAL
                x -> begin
                    y = categorical(agg(x))
                    ordered!(y)
                    return y
                end
            else
                agg
            end
            col => f
        end
        #aggregations = Dict(@. Symbol(columns) => aggregations)
        df = jldopen(f -> f["data"], STF)
        aggdf = combine(groupby(df, id), aggregations...)
        jldopen(STF, "a") do f
            delete!(f, "aggdata")
            f["aggdata"] = aggdf
        end
        return (Views.rawDF(aggdf, 5), "")
    end
end

# CLUSTERING

callbacks[:cl_init] = function (app)
    callback!(#
        app,
        Output(ID.CL_PLOT_X, "options"),
        Output(ID.CL_PLOT_Y, "options"),
        Input(SIG.POST_AG, "children"),
        Input(ID.AG_OUTPUT, "children")
    ) do sig, c
        if !isfile(STF) || isempty(c)
            return [], []
        end
        aggdata = jldopen(f -> get(f, "aggdata", nothing), STF)
        columns = names(aggdata)
        options = [(value=c, label=c) for c in columns]
        return options, options
    end
end

#callbacks[:cl_input] = function (app)
#    callback!(
#        app, #
#        Ouptut()
#        Input(ID.CL_PLOT_X, "options"),
#        Input(ID.CL_PLOT_Y, "options"),
#        Input(ID.SIG_DATA, "children"),
#        Input(ID.AG_SEL_ID, "value"),
#    ) do sig, _
#        if isfile(STF)
#            data = jldopen(f -> f["data"], STF)
#            columns = names(data)
#            options = Views.genOptions(columns)
#            options, options
#        else
#            nothing, nothing
#        end
#    end
#end

#callbacks[:cl_run] = function (app)
#    callback!(#
#        app,
#        Output(ID.SIG_CL_DONE, "children"),
#        Input(ID.CL_RUN_BTN, "n_clicks"),
#        State(ID.AG_SEL_ID, "value"),
#        State(ID.CL_NCL, "value"),
#        State(ID.CL_SEL_MTH, "value"),
#    ) do _, id, ncl, mth
#        if !isfile(STF)
#            return nothing
#        end
#        hasDist = jldopen(f -> "dists" ∈ keys(f), STF)
#        # caching distances
#        dists = if !hasDist
#            aggdata = jldopen(f -> f["aggdata"], STF)
#            dists = Process.gower(select(aggdata, Not(id)))
#            jldopen(STF, "a") do f
#                f["dists"] = dists
#            end
#            dists
#        else
#            jldopen(f -> f["dists"], STF)
#        end
#        result = Process.cluster(mth, dists, ncl)
#        jldopen("clres.jld2", "w") do f
#            f["result"] = result
#        end
#        return 1
#    end
#end

callbacks[:cl_done] = function (app)
    callback!(
        app,#
        Output(ID.CL_PLOT, "children"),
        Input(ID.SIG_CL_DONE, "children"),
        Input(ID.CL_PLOT_X, "value"),
        Input(ID.CL_PLOT_Y, "value"),
        State(ID.AG_SEL_ID, "value"),
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
