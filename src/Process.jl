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

function gower(X::AbstractVector{T}) where {T<:Number}
    X = (X .- mean(X)) / std(X)
    r = abs(maximum(X) - minimum(X))
    return map(Iterators.product(X, X)) do (xi, xj)
        Float32(abs(xi - xj) / r)
    end
end
function gower(X::AbstractVector)
    map(Iterators.product(X, X)) do (xi, xj)
        (xi == xj ? 1 : 0)
    end
end
function gower(df::AbstractDataFrame)
    columns = names(df)
    dists = mean([gower(df[!, c]) for c in columns])
    return dists
end

#TODO: add more aggregation
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
