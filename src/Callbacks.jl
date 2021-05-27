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
using Clustering
using PAM

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
            sleep(5)
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
            value = findfirst(
                x -> occursin("id", x) && occursin("customer", x), lowercase.(columns)
            )
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
            del!(children, maxidx - 1)
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
            agg = getproperty(Process.AGG_TYPES, Symbol(aggs[i]))
            col => agg
        end

        # aggregate
        df = jldopen(f -> f["data"], STF)
        aggdf = combine(groupby(df, id), aggregations...)

        # Convert column to correct type
        map(2:size(aggdf, 2)) do i
            st = getproperty(Process.TYPES, Symbol(scitypes[i - 1]))
            if st === Process.TYPES.HIERARCHICAL
                X = categorical(aggdf[:, i])
                ordered!(X, true)
                aggdf[:, i] = X
            else
                aggdf[:, i] = categorical(aggdf[:, i])
            end
        end
        jldopen(STF, "a") do f
            delete!(f, "aggdata")
            delete!(f, "dists")
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
        Output(ID.CL_PLOT_X, "value"),
        Output(ID.CL_PLOT_Y, "value"),
        Input(SIG.POST_AG, "children"),
        Input(ID.AG_OUTPUT, "children"),
    ) do sig, c
        if !isfile(STF) || isempty(c)
            return [], [], nothing, nothing
        end
        aggdata = jldopen(f -> get(f, "aggdata", nothing), STF)
        columns = names(aggdata)
        options = [(value=c, label=c) for c in columns]
        value = get(columns, 1, nothing)
        return options, options, value, value
    end
end

callbacks[:cl_run] = function (app)
    function elbow(mth, dists)
        results = map(1:9) do k
            try
                Process.cluster(mth, dists, k)
            catch e
                @warn e
                nothing
            end
        end
        return filter(!isnothing, results)
    end

    function single(mth, dists, k)
        return Process.cluster(mth, dists, k)
    end

    callback!(#
        app,
        Output(ID.CL_PLOT, "children"),
        Input(ID.CL_RUN_BTN, "n_clicks_timestamp"),
        Input(ID.CL_ELBOW_BTN, "n_clicks_timestamp"),
        State(ID.AG_SEL_ID, "value"),
        State(ID.CL_NCL, "value"),
        State(ID.CL_SEL_MTH, "value"),
        State(ID.CL_PLOT_X, "value"),
        State(ID.CL_PLOT_Y, "value"),
    ) do single_ts, elbow_ts, id, ncl, mth, colx, coly
        if !isfile(STF) || isnothing(colx) || isnothing(coly)
            return ""
        end
        f = jldopen(STF, "a")
        data = f["aggdata"]
        columns = names(data)
        # validate cache
        if !(colx in columns && coly in columns)
            delete!(f, "dists")
        end
        # cache distance
        if !haskey(f, "dists")
            f["dists"] = Process.gower(select(data, Not(id)))
        end
        dists = f["dists"]
        close(f)
        if something(single_ts, 0) > something(elbow_ts, 9)
            result = if mth == "KMEAN"
                values, columns = Process.numeric_value(data)
                oldcolumns = names(data)
                columns = [columns; setdiff(oldcolumns, columns)]
                @show columns
                result = kmeans(transpose(values), ncl)
                Views.plot_result(result, select(data, columns), colx, coly)
            elseif mth == "KMEDOID"
                result = kmedoids(dists, ncl)
                Views.plot_result(result, data, colx, coly)
            elseif mth == "PAM"
                result = pam(dists, ncl)
                Views.plot_result(result, data, colx, coly)
            else
                return "??"
            end
            #Views.single_plot(result, data[!, colx], data[!, coly])
        else
            result = elbow(mth, dists)
            Views.elbow_plot(result)
        end
    end
end

#callbacks[:cl_done] = function (app)
#    callback!(
#        app,#
#        Output(ID.CL_PLOT, "children"),
#        Input(ID.SIG_CL_DONE, "children"),
#        Input(ID.CL_PLOT_X, "value"),
#        Input(ID.CL_PLOT_Y, "value"),
#        State(ID.AG_SEL_ID, "value"),
#    ) do sig, xcol, ycol, id
#        if !isfile("clres.jld2") || !isfile(STF) || isnothing(xcol) || isnothing(ycol)
#            nothing
#        else
#            data, aggdata = jldopen(f -> (f["data"], f["aggdata"]), STF)
#            result = jldopen(f -> f["result"], "clres.jld2")
#            aggdata.as = result.assignments
#            df = innerjoin(data, aggdata; on=id, makeunique=true)
#            df = select(df, [xcol, ycol, "as"])
#            rename!(df, [:x, :y, :as])
#            Views.pl_scatter(df)
#        end
#    end
#end

function setupCallbacks!(app)
    for (_, setCallback!) in callbacks
        setCallback!(app)
    end
    return app
end

end
