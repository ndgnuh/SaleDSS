module Process

using DataFrames
using JSON3
using Statistics
using Dates
using StatsBase
using Clustering
using PAM

CL_METHODS = [:PAM, :KMEDOID, :KMEAN, :HIER_MIN, :HIER_MAX, :HIER_AVG, :DBSCAN]

AGG_TYPES = (
    MEAN=mean, #
    SUM=sum, #
    STD=std, #
    MAX=maximum, #
    MIN=minimum, #
    COUNT=length, #
    MODE=mode,
    SKIP=nothing,
)

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
    return Dict(
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
            col => scitype
        end,
    )
end

#TODO: add more aggregation
function defaultAggType(st)
    if st === TYPES.NUMERIC
        :MEAN
        #elseif st === TYPES.HIERARCHICAL || st === TYPES.CATEGORICAL
        #    :MODE
    else
        :SKIP
    end
end

function cluster(mth, dists, k)
    if mth === "KMEDOID"
        kmedoids(dists, k)
    elseif mth === "PAM"
        pam(dists, k)
    elseif mth === "KMEAN"
        kmeans(dists, k)
	elseif mth === "HIER_MIN"
		hclust(dists, :single)
	elseif mth === "HIER_MAX"
		hclust(dists, :complete)
	elseif mth === "HIER_AVG"
		hclust(dists, :average)
	elseif mth === "DBSCAN"
		dbscan(dists / std(dists), 0.05, 5)
    end
end

end
