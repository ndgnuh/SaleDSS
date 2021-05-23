module Callbacks

using ..SaleDSS: ID, STF
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

function getTriggerID(ctx)
    map(ctx.triggered) do trig
        first(split(trig.prop_id, "."))
    end
end

function df2json(df::AbstractDataFrame)
    return JSONTables.arraytable(df)
end

function json2df(jsonStr::AbstractString)
    return DataFrame(JSONTables.jsontable(jsonStr))
end

callbacks = Dict{Symbol,Function}()

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

function setupCallbacks!(app)
    for (_, setCallback!) in callbacks
        setCallback!(app)
    end
    return app
end

end
