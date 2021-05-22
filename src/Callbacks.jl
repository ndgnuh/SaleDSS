module Callbacks

using ..SaleDSS: ID
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

callbacks[:afterPickDataSet] = function (app)
    function cb(nothing_::Nothing)
        return ""
    end
    function cb(dataBasename)
        sleep(1)
        dataFile = joinpath(ID.dataDirectory, string(dataBasename))
        if isfile(dataFile)
            data = CSV.read(dataFile, DataFrame)
            df2json(data)
        else
            ""
        end
    end
    return callback!(cb, app, Output(ID.data, "children"), Input(ID.dataPicker, "value"))
end

callbacks[:previewData] = function (app)
    function cb(dataBasename::Nothing, dataJSON::Nothing)
        return "Chose a dataset"
    end
    function cb(dataBasename::AbstractString, dataJSON::Nothing)
        return "Loading"
    end
    function cb(_, dataJSON)
        if isempty(dataJSON)
            "Chose dataset"
        else
            data = json2df(dataJSON)
            Views.rawDataFrame(data)
        end
    end
    return callback!(
        cb,
        app,
        Output(ID.dataPreview, "children"),
        Input(ID.dataPicker, "value"),
        Input(ID.data, "children"),
    )
end

callbacks[:fieldSelection] = function (app)
    callback!(app, Output(ID.fieldSelection, "children"), Input(ID.data, "children")) do dataStr
        if isempty(dataStr)
            "Choose dataset"
        else
            data = json2df(dataStr)
            Views.fieldSelection(data)
        end
    end
end

callbacks[:fieldSelectionSubmit] = function (app)
    callback!(
        app,
        Output(ID.dataNames, "children"),
        Input(ID.fieldSelection, "children"),
        State(ID.data, "children"),
    ) do children, data
        if !isempty(data)
            selections = filter(x -> x.type === "Select" && x.props.value !== "Skip", children)
            @show selections[1]
            columns = map(selections) do selection
                selection.props.id => selection.props.value
            end
            JSON3.write(columns)
        end
    end
end

callbacks[:calculateDistance] = function (app)
    callback!(
        app,
        Output(ID.clusterResult, "children"),
        Input(ID.dataNames, "children"),
        State(ID.data, "children"),
    ) do dataNamesStr, dataStr
        if isempty(dataNames) || isempty(data)
            return ""
        end
        dataNames = JSON3.read(dataNamesStr)
        data = json2df(dataStr)
        return "0"
    end
end

callbacks[:clusterFieldsToPlot] = function (app)
    function namesToOptions(names_)
        return map(name -> (value=name, label=name), names_)
    end
    function cb(data)
        if isempty(data)
            []
        else
            df = json2df(data)
            namesToOptions(names(df))
        end
    end
    callback!(
        cb, app, Output(ID.clusterSelectField1, "options"), Input(ID.data, "children")
    )
    return callback!(
        cb, app, Output(ID.clusterSelectField2, "options"), Input(ID.data, "children")
    )
end

function setupCallbacks!(app)
    for (_, setCallback!) in callbacks
        setCallback!(app)
    end
    return app
end

end

#function setup_callback!(app)
#    callback!(
#        app, Output("currentData", "children"), Input("data-select", "value")
#    ) do selectedFile
#        datadir = joinpath(@__DIR__, "..", "data")
#        datafile = joinpath(datadir, string(selectedFile))
#        if iszero(filesize(datafile))
#            ""
#        else
#            df2json(cleanData!(CSV.read(datafile, DataFrame)))
#        end
#    end
#    callback!(
#        app, Output("datasetDescription", "children"), Input("currentData", "children")
#    ) do currentData
#        if isempty(currentData)
#            Alerts.chooseDataset()
#        else
#            try
#                df = json2df(currentData)
#                viewDataFrame(describe(df))
#            catch e
#                Alerts.danger(string(e))
#            end
#        end
#    end
#
#    callback!(
#        app, Output("basicPlot", "children"), Input("currentData", "children")
#    ) do currentDataString
#        if isempty(currentDataString)
#            return Alerts.chooseDataset()
#        end
#        try
#            df = json2df(currentDataString)
#            plotFieldOptions = map(names(df)) do name
#                (label=name, value=name)
#            end
#            dbc_row() do
#                dbc_col() do
#                    dbc_label("Choose field(s) to plot")
#                end,
#                dbc_col() do
#                    dbc_select(; options=plotFieldOptions, id="fieldToPlot")
#                end
#            end
#        catch e
#            return string(e)
#        end
#    end
#
#    callback!(
#        app,
#        Output("basicPlotStep2", "children"),
#        Input("currentData", "children"),
#        Input("fieldToPlot", "value"),
#    ) do currentData, fieldToPlot
#        if isempty(currentData)
#            Alerts.chooseDataset()
#        elseif isempty(fieldToPlot)
#            @info "[Field to plot] Not found"
#            Alerts.warning("chose a field")
#        else
#            try
#                df = json2df(currentData)
#                data = df[!, fieldToPlot]
#                plotline(data; name=fieldToPlot)
#            catch e
#                errMsg = string(e)
#                Alerts.danger(Iterators.take(errMsg, 1000))
#            end
#        end
#    end
#end
