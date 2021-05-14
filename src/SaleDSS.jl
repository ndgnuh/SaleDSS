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

include("alerts.jl")
using .Alerts

function df2json(df::AbstractDataFrame)
    return JSONTables.arraytable(df)
end

function json2df(jsonStr::AbstractString)
    return DataFrame(JSONTables.jsontable(jsonStr))
end

function loadingWidget()
    return dbc_spinner(; color="primary")
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
            html_div(; id="currentData", style=Dict("display" => "None")),
            html_h1("Sale DSS"),
            html_div(; className="divider"),
            html_h2("Customer clustering"),
            dbc_row() do
                dbc_col(; width=5) do
                    dbc_card() do
                        dbc_cardheader() do
                            dbc_row(; justify="between") do
                                dbc_col("Input"),
                                dbc_col() do
                                    html_a() do
                                        dbc_label("toggle card")
                                    end
                                end
                            end
                        end,
                        dbc_cardbody() do
                            dbc_label("Select dataset"),
                            dataSelect("data-select"),
                            dbc_label("Number of rows"),
                            dbc_input(; id="preview-nb-rows", type="number", value=3),
                            dbc_label("Show cleaned data "),
                            dbc_checkbox(; id="showCleanedData", checked=true)
                        end
                    end,
                    # Describe
                    html_br(),
                    dbc_card() do
                        dbc_cardheader("Raw description"),
                        dbc_cardbody(loadingWidget(); id="datasetDescription")
                    end
                end,
                dbc_col(; width=7) do
                    dbc_card() do
                        dbc_cardheader("Data preview"),
                        dbc_cardbody() do
                            html_div(; id="data-table") do
                                loadingWidget()
                            end
                        end
                    end,
                    #html_br(),
                    #dbc_card() do
                    #    dbc_cardheader("Basic visualization"),
                    #    dbc_cardbody() do
                    #        html_div(loadingWidget(); id="basicPlot"),
                    #        html_div(loadingWidget(); id="basicPlotStep2")
                    #    end
                    #end,
                    #dbc_card() do
                    #    dbc_cardheader("Draft section"),
                    #    dbc_cardbody() do
                    #        try
                    #            draft()
                    #        catch e
                    #            dcc_markdown(string(e))
                    #        end
                    #    end
                    #end
                end
            end
        end
    end
end

function setup_callback!(app)
    callback!(
        app, Output("currentData", "children"), Input("data-select", "value")
    ) do selectedFile
        datadir = joinpath(@__DIR__, "..", "data")
        datafile = joinpath(datadir, string(selectedFile))
        if iszero(filesize(datafile))
            ""
        else
            df2json(cleanData!(CSV.read(datafile, DataFrame)))
        end
    end
    callback!(
        app, Output("datasetDescription", "children"), Input("currentData", "children")
    ) do currentData
        if isempty(currentData)
            Alerts.chooseDataset()
        else
            try
                df = json2df(currentData)
                viewDataFrame(describe(df))
            catch e
                Alerts.danger(string(e))
            end
        end
    end

    callback!(
        app, Output("basicPlot", "children"), Input("currentData", "children")
    ) do currentDataString
        if isempty(currentDataString)
            return Alerts.chooseDataset()
        end
        try
            df = json2df(currentDataString)
            plotFieldOptions = map(names(df)) do name
                (label=name, value=name)
            end
            dbc_row() do
                dbc_col() do
                    dbc_label("Choose field(s) to plot")
                end,
                dbc_col() do
                    dbc_select(; options=plotFieldOptions, id="fieldToPlot")
                end
            end
        catch e
            return string(e)
        end
    end

    callback!(
        app,
        Output("basicPlotStep2", "children"),
        Input("currentData", "children"),
        Input("fieldToPlot", "value"),
    ) do currentData, fieldToPlot
        if isempty(currentData)
            Alerts.chooseDataset()
        elseif isempty(fieldToPlot)
            @info "[Field to plot] Not found"
            Alerts.warning("chose a field")
        else
            try
                df = json2df(currentData)
                data = df[!, fieldToPlot]
                plotline(data; name=fieldToPlot)
            catch e
                errMsg = string(e)
                Alerts.danger(Iterators.take(errMsg, 1000))
            end
        end
    end

    callback!(
        app,
        Output("data-table", "children"),
        Input("data-select", "value"),
        Input("preview-nb-rows", "value"),
        Input("showCleanedData", "checked"),
    ) do selected_data, preview_nb_rows, showCleanedData
        datadir = joinpath(@__DIR__, "..", "data")
        datafile = joinpath(datadir, string(selected_data))
        if iszero(filesize(datafile))
            html_p("Invalid data file")
        else
            df = CSV.read(datafile, DataFrame)
            if showCleanedData
                viewDataFrame(df, preview_nb_rows)
            else
                viewDataFrame(cleanData(df), preview_nb_rows)
            end
        end
    end
end

function main()
    app = dash(;
        external_stylesheets=[dbc_themes.DARKLY], suppress_callback_exceptions=true
    )
    setup_layout!(app)
    setup_callback!(app)
    host = get(ENV, "HOST", "0.0.0.0")
    port = get(ENV, "PORT", "8080")
    return run_server(app, "0.0.0.0", 8080; debug=true)
end

function main_with_try_catch()
    try
        main()
    catch e
        @error e
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main_with_try_catch()
end

end # module
