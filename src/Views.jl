module Views

using ..SaleDSS: ID

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
using Plots

function loading()
    return dbc_spinner(; color="primary")
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

function dataPicker(id=ID.dataPicker)
    datadir = joinpath(@__DIR__, "..", "data")
    files = filter(endswith("csv"), readdir(datadir))
    options = map(files) do file
        Dict("label" => file, "value" => file)
    end
    return (dbc_label("Select dataset"), dbc_select(; id=id, options=options))
end

function dataPreview(dataID=ID.data, previewID=ID.dataPreview)
    return view = dbc_card() do
        dbc_cardheader("Data preview"),
        dbc_cardbody() do
            html_div(; id="$previewID") do
                loadingWidget()
            end
        end
    end
end

function fieldSelection(data)
    columns = names(data)
    options = [
        (label="Skip", value="Skip"),
        (label="Numeric", value="Numeric"),
        (label="DateTime", value="DateTime"),
        (label="Categorical", value="Categorical"),
        (label="Hierarchical", value="Hierarchical"),
    ]
    function valueByType(col)
        T = eltype(data[!, col])
        if occursin("id", lowercase(col)) || occursin("name", lowercase(col))
            "Skip"
        elseif T <: Integer && length(unique(data[!, col])) < 10
            "Hierarchical"
        elseif T <: Number
            "Numeric"
        elseif T <: Dates.AbstractDateTime
            "DateTime"
        elseif T <: AbstractString
            "Categorical"
        else
            "Skip"
        end
    end
    return reduce(
        vcat,
        [
            [
                dbc_label(column),
                dbc_select(; value=valueByType(column), id=column, options=options),
            ] for column in columns
        ],
    )
end

function clusterView()
    clusterNumber = dbc_input(; type="number", value=3, id=ID.clusterSelectNumber)
    clusterPlotField1 = dbc_select(; id=ID.clusterSelectField1)
    clusterPlotField2 = dbc_select(; id=ID.clusterSelectField2)
    clusteringMethod = dbc_select(;
        options=[(value="PAM", label="PAM"), (value="K-Mean", label="K-Mean")], value="PAM"
    )

    submitButton = html_div() do
        html_br(), dbc_button("Cluster"; color="primary", id=ID.clusterSubmit)
    end

    dbc_card() do
        dbc_cardheader("Clustering"),
        dbc_cardbody() do
            dbc_label("Number of cluster(s)"),
            clusterNumber,
            dbc_label("Plot x-axis"),
            clusterPlotField1,
            dbc_label("Plot y-axis"),
            clusterPlotField2,
            dbc_label("Choose clustering method"),
            clusteringMethod,
            submitButton
        end
    end
end

function clusterResultView()
    dbc_card() do
        dbc_cardheader("Clustering Result"), dbc_cardbody(; id=ID.clusterResult)
    end
end

# End module
end
