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

CL_METHODS = [:PAM, :KMEDOID, :KMEAN]

function deviation(X::AbstractVector{T}) where {T<:Union{Missing,Number}}
    Xnomissing = filter(!ismissing, X)
    X = replace(X, missing => mean(Xnomissing))
    result = std(X)
    return isnan(result) ? zero(T) : result
end
function deviation(X::CategoricalArray)
    X = levelcode.(X)
    return deviation(X)
end
function deviation(X::AbstractVector{T}) where {T<:Union{Missing,AbstractString}}
    X0 = filter(!ismissing, X)
    X = replace(X, missing => mode(X0))
    return deviation(categorical(X))
end

function count_unique(x)
    return length(unique(x))
end

AGG_TYPES = (
    MEAN=mean, #
    SUM=sum, #
    STD=deviation, #
    MAX=maximum, #
    MIN=minimum, #
    COUNT=count_unique, #
    MODE=mode,
)

TYPES = (NUMERIC=:Numeric, CATEGORICAL=:Categorical, HIERARCHICAL=:Hierarchical)

function type_to_scitype(::Type{T}) where {T<:Number}
    return [:NUMERIC, :CATEGORICAL, :HIERARCHICAL]
end
function type_to_scitype(::Type{T}) where {T}
    return [:CATEGORICAL, :HIERARCHICAL]
end

function scitype_agg(scitype)
    if scitype === "NUMERIC"
        [:MEAN, :SUM, :STD, :MAX, :MIN, :COUNT, :MODE]
    elseif scitype === "CATEGORICAL"
        [:MODE, :STD, :COUNT]
    else
        [:MODE, :STD, :MAX, :MIN, :COUNT]
    end
end

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
        elseif eltype(cvals) <: AbstractString
            levelcode.(categorical(cvals))
        end
    end
    values = filter(!isnothing, values)
    return reduce(hcat, values), columns
end

function cluster(::Val{:KMEAN}, data, k)
    @show "kmean"
    values, _ = numeric_value(data)
    return kmeans(transpose(values), k)
end

function cluster(::Val{:KMEDOID}, data, k)
    @show "kmedoid"
    dists = gower(data)
    return kmedoids(dists, k)
end

function cluster(::Val{:PAM}, data, k)
    @show "pam"
    dists = gower(data)
    return pam(dists, k)
end

function cluster(method::AbstractString, args...; kwargs...)
    return cluster(Val(Symbol(method)), args...; kwargs...)
end

function elbow(method::AbstractString, args...; kwargs...)
    return elbow(Val(Symbol(method)), args...; kwargs...)
end

function elbow(::Val{:KMEAN}, data)
    values, _ = numeric_value(data)
    n = min(15, size(data, 1))
    results = map(1:n) do i
        try
            kmeans(transpose(values), i)
        catch e
            @warn e
            return nothing
        end
    end
    return filter(!isnothing, results)
end

function elbow(::Val{:KMEDOID}, data)
    dists = gower(data)
    n = min(15, size(data, 1))
    results = map(2:n) do k
        try
            kmedoids(dists, k)
        catch e
            @warn e
            return nothing
        end
    end
    return filter(!isnothing, results)
end

function elbow(::Val{:PAM}, data)
    return elbow(Val(:KMEDOID), data)
end

end
