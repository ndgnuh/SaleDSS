module Process

using DataFrames
using JSON3
using Statistics
using Dates
using StatsBase
using Clustering
using PAM
using CategoricalArrays

ACTS = [:Aggregate, :PCA, :CLUS]

CL_METHODS = [:PAM, :KMEDOID, :KMEAN, :DBSCAN]

count_unique(x) = length(unique(x))
AGG_TYPES = (
    MEAN=mean, #
    SUM=sum, #
    STD=std, #
    MAX=maximum, #
    MIN=minimum, #
    COUNT=count_unique, #
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

function gower(X::AbstractVector{T}) where {T<:Number}
    X = (X .- mean(X)) / std(X)
    r = abs(maximum(X) - minimum(X))
    dists = map(Iterators.product(X, X)) do (xi, xj)
        Float32(abs(xi - xj) / r)
    end
    return dists = dists / std(dists)
end
function gower(X::CategoricalVector)
    codes = levelcode.(X)
    if isordered(X)
        dists = map(Iterators.product(codes, codes)) do (xi, xj)
            abs(xi - xj)
        end
    else
        dists = map(Iterators.product(codes, codes)) do (xi, xj)
            xi == xj ? 1 : 0
        end
    end
    return dists / std(dists)
end
function gower(X::AbstractVector)
    return dists = map(Iterators.product(X, X)) do (xi, xj)
        (xi == xj ? 1 : 0)
    end
end
function gower(df::AbstractDataFrame)
    columns = names(df)
    dists = mean([gower(df[!, c]) for c in columns])
    return dists
end

#TODO: add more aggregation
function cluster(mth, args...)
    if mth === "KMEDOID"
        dists, k = args
        kmedoids(dists, k)
    elseif mth === "PAM"
        dists, k = args
        pam(dists, k)
    elseif mth === "KMEAN"
        X, k = args
        kmeans(X, k)
    end
end

function cluster_weight(df::AbstractDataFrame)
    @assert ("assignments" in names(df)) "DataFrame has no assignments column"
    gdf = groupby(df, :assignments)
    return aggregate = map(setdiff(names(df), ["assignments"])) do name
        Symbol(name) => mean
    end
end

function numeric_value(df::AbstractDataFrame)
    columns = names(df)
    columns = filter(columns) do c
        eltype(df[!, c]) <: Union{Number,CategoricalValue}
    end
    values = map(columns) do c
        cvals = df[!, c]
        if eltype(cvals) <: Number
            cvals
        elseif eltype(cvals) <: CategoricalValue
            levelcode.(cvals)
        else
            nothing
        end
    end
    values = filter(!isnothing, values)
    return reduce(hcat, values), columns
end

end
