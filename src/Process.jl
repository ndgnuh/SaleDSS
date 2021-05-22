module Process

using DataFrames
using JSON3
using Statistics
using Dates

TYPES = (
    NUMERIC=:Numeric,
    CATEGORICAL=:Categorical,
    HIERARCHICAL=:Hierarchical,
    DATETIME=:DateTime,
    ID=:ID,
    SKIP=:SKIP,
)

"""
	calculateDistance(df, columns, distanceType)

Calculate the `distanceType` distance of `df` using data from `columns`.
The `columns` is the form of `name => sciType`, where sciType is one of:
- Numeric
- Categorical
- Hierarchical
"""
function calculateDistance(df, columns, distanceType)
    selectedColumns = filter(x -> columns[x] == "Numeric", collect(keys(columns)))
    df = select(df, selectedColumns)
    return gower(df)
end

function gower(df)
    names_ = names(df)
    n, m = size(df)
    ranges = Dict(
        name => abs(maximum(df[!, name]) - minimum(df[!, name])) for name in names_
    )
    cases = Iterators.product(1:n, 1:n)
    return map(cases) do I
        i, j = I
        mean(begin
            x = df[i, name]
            y = df[j, name]
            Float32(abs(x - y) / ranges[name])
        end for name in names_)
    end
end

"""
	typeByColumns(df::DataFrame)

Detect the "science" type of each col in dataframe, see `TYPES`.
"""
function typeByColumns(df)
    columns = names(df)
    map(columns) do col
        lcol = lowercase(col)
        T = eltype(df[!, col])
        scitype = if occursin("id", lcol)
            if occursin("customer", lcol)
                TYPES.ID
            else
                TYPES.SKIP
            end
        elseif occursin("name", lcol)
            TYPES.SKIP
        elseif T <: Integer && length(unique(df[!, col])) < 10
            TYPES.HIERARCHICAL
        elseif T <: Number
            TYPES.NUMERIC
        elseif T <: Dates.AbstractDateTime
            TYPES.DATETIME
        elseif T <: AbstractString
            TYPES.CATEGORICAL
        else
            TYPES.SKIP
        end
    end
end

end
