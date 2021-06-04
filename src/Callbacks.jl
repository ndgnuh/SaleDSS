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
using JSONTables

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
    ) do _
        datapath = normpath(joinpath(@__DIR__, "..", "data"))
        datafiles = readdir(datapath)
        datafiles = filter(endswith(".csv"), datafiles)
        datapath = joinpath.(datapath, datafiles)
        [(label=l, value=v) for (l, v) in zip(datafiles, datapath)], nothing
    end
end

# Data & flower selection

callbacks[:dt_input] = function (app, state)
    callback!(#
        app,
        Output(ID.DT_STORE, "data"),
        Input(ID.DT_SELECT, "value"),
    ) do path
        if isnothing(path)
            return ""
        else
            try
                df = CSV.read(path, DataFrame)
                objecttable(df)
            catch error
                @error "Unable to read file: $(error)"
                return nothing
            end
        end
    end
end

callbacks[:dt_input_preview] = function (app, state)
    callback!(app, Output(ID.DT_OUTPUT, "children"), Input(ID.DT_STORE, "data")) do datastr
        if isempty(something(datastr, ""))
            nothing
        else
            df = DataFrame(jsontable(datastr))
            Views.rawDF(df, 3)
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
        Input(ID.DT_STORE, "data"),
    ) do datajson
        if isempty(datajson)
            return [], nothing
        else
            data = DataFrame(jsontable(datajson))
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
    function add!(data, children, idx)
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

    function del!(_, children, idx)
        deleteat!(children, idx)
        return children
    end
    callback!(
        app,#
        Output(ID.AG_AGS, "children"),
        Input(ID.AG_ADD_BTN, "n_clicks_timestamp"),
        Input((type=ID.AG_SEL_DEL, index=ALL), "n_clicks_timestamp"),
        Input(ID.DT_STORE, "data"),
        Input(ID.DT_STORE, "modified_timestamp"),
        State(ID.AG_AGS, "children"),
    ) do add_ts, del_tss, datajson, datats, children
        if isempty(datajson)
            ""
        else
            data = DataFrame(jsontable(datajson))
            timestamps = something.([add_ts; del_tss...], 0)
            maxbtnts, maxidx = findmax(something.(timestamps, 0))
            if datats > maxbtnts
                children = []
            end
            idx = length(something(children, [])) + 1
            if something(maxidx, 1) > 1
                del!(data, children, maxidx - 1)
            else
                add!(data, children, idx)
            end
        end
    end
end

callbacks[:ag_scitype] = function (app, state)
    return callback!(
        app,
        Output((type=ID.AG_SEL_TYPE, index=MATCH), "options"),
        Output((type=ID.AG_SEL_TYPE, index=MATCH), "value"),
        Input(ID.DT_STORE, "data"),
        Input(ID.AG_AGS, "children"),
        Input((type=ID.AG_SEL_COL, index=MATCH), "value"),
    ) do datajson, _, col
        if !isempty(datajson) && !isnothing(col)
            data = DataFrame(jsontable(datajson))
            if !(col in names(data))
                return [], nothing
            end
            T = eltype(data[:, col])
            types = Process.type_to_scitype(T)
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
        Input(ID.DT_STORE, "data"),
        Input((type=ID.AG_SEL_TYPE, index=MATCH), "value"),
    ) do datajson, type
        if isnothing(type) || isempty(datajson)
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
        Output(ID.AG_DT_STORE, "data"),
        Input(ID.DT_STORE, "data"),
        Input(ID.AG_SEL_ID, "value"),
        Input((type=ID.AG_SEL_COL, index=ALL), "value"),
        Input((type=ID.AG_SEL_TYPE, index=ALL), "value"),
        Input((type=ID.AG_SEL_AG, index=ALL), "value"),
    ) do datajson, id, columns, scitypes, aggs
        if isnothing(id) ||
           isempty(datajson) ||
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
        df = DataFrame(jsontable(datajson))
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
        return objecttable(aggdf)
    end
end

callbacks[:ag_output_preview] = function (app, args...)
    callback!(
        app, Output(ID.AG_OUTPUT, "children"), Input(ID.AG_DT_STORE, "data")
    ) do agg_data_json
        if isempty(something(agg_data_json, ""))
            return ""
        else
            df = DataFrame(jsontable(agg_data_json))
            return Views.rawDF(df, 3)
        end
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
        Output(ID.CL_NCL, "max"),
        Input(ID.AG_OUTPUT, "children"),
        Input(ID.AG_DT_STORE, "data"),
    ) do c, agdatajson
        if isempty(c) || isempty(agdatajson)
            return [], [], nothing, nothing, 0
        end
        aggdata = DataFrame(jsontable(agdatajson))
        columns = names(aggdata)
        options = [(value=c, label=c) for c in columns]
        value = get(columns, 1, nothing)
        return options, options, value, value, size(aggdata, 1)
    end
end

callbacks[:cl_run] = function (app, state)
    callback!(#
        app,
        Output(ID.CL_PLOT, "children"),
        Input(ID.CL_RUN_BTN, "n_clicks_timestamp"),
        Input(ID.CL_ELBOW_BTN, "n_clicks_timestamp"),
        Input(ID.AG_DT_STORE, "data"),
        State(ID.AG_SEL_ID, "value"),
        State(ID.CL_NCL, "value"),
        State(ID.CL_SEL_MTH, "value"),
        State(ID.CL_PLOT_X, "value"),
        State(ID.CL_PLOT_Y, "value"),
    ) do single_ts, elbow_ts, datajson, id, ncl, mth, colx, coly
        if isnothing(colx) || isnothing(coly) || isempty(datajson) || isnothing(mth)
            return ""
        end
        data = DataFrame(jsontable(datajson))
        if ncl > size(data, 1)
            return "Number of cluster is too large"
        end
        if something(single_ts, 0) > something(elbow_ts, 9)
            result = Process.cluster(mth, data, ncl)
            Views.plot_result(result, data, colx, coly)
        else
            result = Process.elbow(mth, data)
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
