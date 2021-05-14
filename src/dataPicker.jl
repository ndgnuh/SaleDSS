function dataPicker()
    html_div() do
        dcc_upload(; id="data-uploader") do
            "Pick a file"
        end
    end
end

function dataSelect(id="data-select")
    datadir = joinpath(@__DIR__, "..", "data")
	files = filter(endswith("csv"), readdir(datadir))
    options = map(files) do file
        Dict("label" => file, "value" => file)
    end
    return dbc_select(; id=id, options= options)
end
