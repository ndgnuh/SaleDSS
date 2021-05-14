function cleanData!(df::AbstractDataFrame)
	newNames = map(names(df)) do name
		name = replace(name, r"[- ,.]" => "")
	end
	rename!(df, newNames)
	return df
end

function detectDateField(names_)
	filter(names_) do name
		name = lowercase(name)
		occursin("date", name)
	end
end

"""
	detectDateFormat(dateString)

Return auto detected dateformat.
"""
function detectDateFormat(dateString; delim = "")
	first = second = third = ""
	delim = if occursin("-", dateString)
		 "-"
	elseif occursin("/", dateString)
		 "/"
	else
		delim
	end
end

function cleanData(df::AbstractDataFrame)
	cleanData!(df |> copy)
end
