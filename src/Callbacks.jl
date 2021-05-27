module Callbacks

using ..SaleDSS: ID, SIG
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

callbacks[:init] = function (app, state)
    callback!(#
        app,
        Output(ID.DT_SELECT, "options"),
        Output(ID.DT_SELECT, "value"),
        Input(ID.CLEAR_CACHE, "n_clicks"),
    ) do n
        for k in keys(state)
            delete!(state, k)
        end
        datapath = normpath(joinpath(@__DIR__, "..", "data"))
        datafiles = readdir(datapath)
        datafiles = filter(endswith(".csv"), datafiles)
        datapath = joinpath.(datapath, datafiles)
        state[:list_data_file] = Dict(datafiles .=> datapath)
        delete!(state, :data)
        [(label=l, value=v) for (l, v) in zip(datafiles, datapath)], nothing
    end
end

# Data & flower selection

callbacks[:dt_input] = function (app, state)
    callback!(#
        app,
        Output(ID.DT_OUTPUT, "children"),
        Input(ID.DT_SELECT, "value"),
    ) do path
        if isnothing(path)
            return ""
        else
            try
                df = CSV.read(path, DataFrame)
                state[:data] = df
                state[:dataset] = path
                delete!(state, :aggdata)
                delete!(state, :dists)
                Views.rawDF(df, 3), ""
            catch error
                "Unable to read file: $(error)"
            end
        end
    end
end

#TODO
#callbacks[:dt_process] = function(app)
#end

# aggregation

callbacks[:ag_init] = function (app, state)
    callback!(#
        app,
        Output(ID.AG_SEL_ID, "options"),
        Output(ID.AG_SEL_ID, "value"),
        Input(ID.DT_OUTPUT, "children"),
    ) do sig
        if !haskey(state, :data)
            return [], nothing
        else
            data = state[:data]
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

callbacks[:ag_add] = function (app, state)
    function add!(children, idx)
        data = state[:data]
        columns = names(data)
        sCol = dbc_select(;
            id=(type=ID.AG_SEL_COL, index=idx),
            options=[(label=c, value=c) for c in columns],
        )
        sType = dbc_select(; id=(type=ID.AG_SEL_TYPE, index=idx), options=[])
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
        Input(ID.DT_OUTPUT, "children"),
        State(ID.AG_AGS, "children"),
    ) do add_ts, del_tss, sig, children
        if !haskey(state, :data)
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

callbacks[:ag_scitype] = function (app, state)
    return callback!(
        app,
        Output((type=ID.AG_SEL_TYPE, index=MATCH), "options"),
        Output((type=ID.AG_SEL_TYPE, index=MATCH), "value"),
        Input(ID.DT_OUTPUT, "children"),
        Input(ID.AG_AGS, "children"),
        Input((type=ID.AG_SEL_COL, index=MATCH), "value"),
    ) do _, _, col
        if haskey(state, :data) && !isnothing(col)
            data = state[:data]
            T = eltype(data[:, col])
            types = Process.type_to_scitype(T)
            @show types
            [(value=t, label=t) for t in types], first(types)
        else
            [], nothing
        end
    end
end

callbacks[:ag_scitype2agg] = function (app, state)
    return callback!(#
        app,
        Output((type=ID.AG_SEL_AG, index=MATCH), "options"),
        Output((type=ID.AG_SEL_AG, index=MATCH), "value"),
        Input(ID.DT_OUTPUT, "children"),
        Input((type=ID.AG_SEL_TYPE, index=MATCH), "value"),
    ) do _, type
        if isnothing(type)
            [], nothing
        else
            aggs = Process.scitype_agg(type)
            [(label=a, value=a) for a in aggs], first(aggs)
        end
    end
end

callbacks[:ag_output] = function (app, state)
    callback!(
        app,
        Output(ID.AG_OUTPUT, "children"),
        Input(ID.DT_OUTPUT, "children"),
        Input(ID.AG_SEL_ID, "value"),
        Input((type=ID.AG_SEL_COL, index=ALL), "value"),
        Input((type=ID.AG_SEL_TYPE, index=ALL), "value"),
        Input((type=ID.AG_SEL_AG, index=ALL), "value"),
    ) do _, id, columns, scitypes, aggs
        if isnothing(id) ||
           !haskey(state, :data) ||
           any(isnothing.(columns)) ||
           any(isnothing.(scitypes)) ||
           any(isnothing.(aggs)) ||
           !(length(columns) == length(scitypes) == length(aggs))
            return ""
        end
        # perform cleaning & stuffs here
        aggregations = map(1:length(columns)) do i
            col = Symbol(columns[i])
            agg = getproperty(Process.AGG_TYPES, Symbol(aggs[i]))
            col => agg
        end
        aggregations = unique(aggregations)

        # aggregate
        df = state[:data]
        aggdf = combine(groupby(df, id), aggregations...)

        # Convert column to correct type
        for i in 2:size(aggdf, 2)
            st = getproperty(Process.TYPES, Symbol(scitypes[i - 1]))
            if st === Process.TYPES.HIERARCHICAL
                X = categorical((aggdf[:, i]))
                ordered!(X, true)
                aggdf[:, i] = X
            elseif st === Process.TYPES.CATEGORICAL
                aggdf[:, i] = categorical((aggdf[:, i]))
            end
        end
        state[:aggdata] = aggdf
        delete!(state, :dists)
        return Views.rawDF(aggdf, 5)
    end
end

# CLUSTERING

callbacks[:cl_init] = function (app, state)
    callback!(#
        app,
        Output(ID.CL_PLOT_X, "options"),
        Output(ID.CL_PLOT_Y, "options"),
        Output(ID.CL_PLOT_X, "value"),
        Output(ID.CL_PLOT_Y, "value"),
        Input(ID.AG_OUTPUT, "children"),
    ) do c
        if isempty(c) || !haskey(state, :aggdata)
            return [], [], nothing, nothing
        end
        aggdata = state[:aggdata]
        columns = names(aggdata)
        options = [(value=c, label=c) for c in columns]
        value = get(columns, 1, nothing)
        return options, options, value, value
    end
end

callbacks[:cl_run] = function (app, state)
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
        if isnothing(colx) || isnothing(coly) || !haskey(state, :aggdata)
            return ""
        end
        data = state[:aggdata]
        columns = names(data)
        # validate cache
        if !(colx in columns && coly in columns)
            delete!(state, :dists)
        end
        # cache distance
        if !haskey(state, :dists)
            state[:dists] = Process.gower(select(data, Not(id)))
        end
        dists = state[:dists]
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

function setupCallbacks!(app, state)
    for (_, setCallback!) in callbacks
        setCallback!(app, state)
    end
    return app
end

end
