### A Pluto.jl notebook ###
# v0.14.5

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : missing
        el
    end
end

# ╔═╡ 0bd2ff80-8cc8-11eb-249c-05fd1d04ee1c
using DataFrames, CSV, PlutoUI, Statistics, Dates, StatsBase, StatsPlots, CategoricalArrays, TimeSeries

# ╔═╡ 358c4ff0-8d97-11eb-287c-e1468d30380b
using HypothesisTests

# ╔═╡ 2e204978-8d48-11eb-2ec2-5d7d91d33738
using TSAnalysis

# ╔═╡ c75c84a2-8df6-11eb-1b7f-4bab123f860f
using SparseArrays

# ╔═╡ d69bed7e-8df6-11eb-3ec3-212ca4fb3b91
using Distributions

# ╔═╡ 78b53eea-8dfe-11eb-3fe8-9b393e6bf964
using Random

# ╔═╡ caa36374-8e0c-11eb-2a87-6784b7700d1e
using BenchmarkTools

# ╔═╡ 24470d18-8cc8-11eb-0e01-afa021d534e2
datadir = joinpath(@__DIR__, "..", "data")

# ╔═╡ 903e2dce-8e0d-11eb-26e8-f15c4fbd1336
readdir(datadir)

# ╔═╡ d5f48e14-8e0d-11eb-0d6c-5d9c6c409481
run(`unzip $(joinpath(datadir, "superstore_sale.zip"))`)

# ╔═╡ 8b2bd284-8cc8-11eb-222a-65dbbf1555f5
#= md"""
`datafile`: $(@bind datafile PlutoUI.Select(readdir(datadir)))
""" =#
datafile = joinpath(datadir, "superstore_dataset2011-2015.csv")

# ╔═╡ 5c36f1f0-8cca-11eb-114e-15ba6d89f884
md"# Basic insight"

# ╔═╡ 5053b29e-8cc8-11eb-3e15-53e86ce54942
begin
    df = CSV.read(joinpath(datadir, datafile), DataFrame)
    describe(df)
end

# ╔═╡ 0936796c-8cca-11eb-2d1a-bf4aa18703b4
md"# Cleaning"

# ╔═╡ c25cd556-8d2d-11eb-03b7-997d9675eef9
Date("1/1/2011", "d/m/yyyy")

# ╔═╡ 0e2980e4-8d48-11eb-2e20-2d1703ba2006
df[:, "Order Date"]

# ╔═╡ 033398ce-8d47-11eb-0991-09d02ec9bf64
const categorical_columns = [:ShipMode, :Segment, :City, :State, :Region, :Category, :SubCategory]

# ╔═╡ 90714656-8d3c-11eb-3021-bb11933bfa4b
function clean(df)
	df = copy(df)
	# Rename so that no space occurs in the column name
	newnames = map(name -> Symbol(replace(name, r"[ -]" => "")), names(df))
	DataFrames.rename!(df, newnames)
	
	# Convert to DateTime
	function dateformater(s)
		if contains(s, "/")
			"m/d/yyyy"
		else
			"d-m-yyyy"
		end
	end
	df.OrderDate = map(datetimestr -> Date(datetimestr, dateformater(datetimestr)), df.OrderDate)
	df.ShipDate = map(datetimestr -> Date(datetimestr, dateformater(datetimestr)), df.ShipDate)
	
	# Drops useless columns
	select!(df, Not([:RowID, :OrderID, :CustomerName, :PostalCode, :ProductName, :ShipDate]))
	
	# Drop missig
	dropmissing!(df)
	
	# Convert columns to categorical arrays
	foreach(categorical_columns) do name
		df[!, name] = categorical(df[!, name])
	end
	
	# Sort by time
	sort!(df, :OrderDate)
	return df
end

# ╔═╡ ceda8362-8d3c-11eb-2f0a-9b5aa19093fd
df_clean = clean(df);

# ╔═╡ 52d51e60-8d3e-11eb-302c-0b8efaf77201
describe(df_clean)

# ╔═╡ 4c7c530c-8d3f-11eb-2597-15fe01f3cd62
function cat2int(df)
	df = copy(df)
	foreach(names(df)) do name
		if df[1, name] isa CategoricalValue
			df[!, name] = levelcode.(df[!, name])
		end
		if df[1, name] isa Dates.AbstractTime
			df[!, name * "Year"] = year.(df[!, name])
			df[!, name * "Month"] = month.(df[!, name])
			df[!, name * "Day"] = day.(df[!, name])
			df[!, name * "Quarter"] = quarterofyear.(df[!, name])
			select!(df, Not(name))
		end
	end
	df
end

# ╔═╡ 6abfedb4-8d40-11eb-17c3-c139d90ca0f0
df_clean_int = cat2int(df_clean)

# ╔═╡ 816abdc6-8ccf-11eb-0366-ff8ba71d8c9a
function cor_matrix(df::AbstractDataFrame)
    ic = eachcol(df)
    it = Iterators.product(ic, ic)
    return map(c1c2 -> cor(c1c2...), it)
end

# ╔═╡ c0ba004a-8ccf-11eb-2780-0da2557619ac
function dfheatmap(df::AbstractDataFrame)
    dfnames = filter(name -> eltype(df[!, name]) <: Number, names(df))
    cor_matrix = map(Iterators.product(dfnames, dfnames)) do cols
        col1, col2 = cols
        cor(df[!, col1], df[!, col2])
    end
    return heatmap(dfnames, dfnames, cor_matrix, xticks=:all, yticks=:all, xrotation=45)
end

# ╔═╡ 74a7ae3a-8d3f-11eb-213f-bda4fe9b2f70
dfheatmap(df_clean_int)

# ╔═╡ adbb82ee-8d46-11eb-2b3a-af214bf6d62b
@bind select_column PlutoUI.Select(categorical_columns .|> string)

# ╔═╡ 4f3c0198-8d33-11eb-04f2-939e9122e206
bar(countmap(string.(df_clean[!, select_column])),
	title=select_column, 
	label=false,
	xticks = :all,
	xrotation = -45)

# ╔═╡ 73d77300-8d99-11eb-37e1-3902a8f51a7d
df_clean_int

# ╔═╡ 8fe258d2-8d97-11eb-1fba-cb9cc41c920c
df_corrplot = @df df_clean_int corrplot(cols(3:6), grid=false, fill=cgrad());

# ╔═╡ 05ead5ea-8d98-11eb-3dc3-a5f70af3352f
plotname = tempname() * ".png"

# ╔═╡ 0062eaae-8d98-11eb-3f7c-db753bf19b6b
begin
	savefig(df_corrplot, plotname)
	PlutoUI.LocalResource(plotname)
end

# ╔═╡ 4eda9106-8d97-11eb-22c1-79ebe79e9419
ADFTest(df_clean.Sales, :constant, 5)

# ╔═╡ d91a20e8-8d47-11eb-1a98-13810556aeff
bar(autocor(df_clean.Sales), label="ACF(SALES)")

# ╔═╡ c2e650f8-8d47-11eb-1590-27739a81c84d
ts = TimeSeries.TimeArray(df_clean, timestamp=:OrderDate);

# ╔═╡ 26f3f28c-8dff-11eb-2b3c-ab9673d17e00
sparse([1,2,3], [1,2,3], [1, 1, 1])

# ╔═╡ 849bd920-8d48-11eb-329e-fb4837b2869d
begin
	function CramerV(X, Y, r = length(unique(X)), k = length(unique(Y)))
		N = countmap(zip(X, Y))
		n = length(X)
		cX = countmap(X)
		cY = countmap(Y)
		χ² = sum(let NiNj = cX[i] * cY[j] / n
				(get(N, (i,j), 0) - NiNj)^2 / NiNj
			end for i in keys(cX), j in keys(cY))
		sqrt(χ²/ n / min(k - 1, r - 1))
	end
		
	CramerV(X::CategoricalArray, Y) = CramerV(levelcode.(X), Y)
	CramerV(X, Y::CategoricalArray) = CramerV(X, levelcode.(Y))
	CramerV(X::CategoricalArray, Y::CategoricalArray) = CramerV(levelcode.(X), levelcode.(Y))
end

# ╔═╡ 45f18f5e-8dfd-11eb-2fe6-89cf2eb621f5
function dfheatmap2(df::AbstractDataFrame)
    dfnames = filter(name -> eltype(df[!, name]) <: Number, names(df))
    cor_matrix = map(Iterators.product(dfnames, dfnames)) do cols
        col1, col2 = cols
        CramerV(df[!, col1], df[!, col2])
    end
    return heatmap(dfnames, dfnames, cor_matrix, xticks=:all, yticks=:all, xrotation=45)
end

# ╔═╡ 3ae42218-8e12-11eb-27bb-a7af14e2f135
dfheatmap2(df_clean_int)

# ╔═╡ f6dd0c48-8dfc-11eb-19cf-5fc77173e174
R"require(lsr)"

# ╔═╡ 780fb35a-8e05-11eb-2351-ff0a3dc1e164
CramerV(df_clean_int.Segment, df_clean_int.Category)

# ╔═╡ 6fd3ea06-8df6-11eb-1652-d1417c5951c4
with_terminal() do
	Random.seed!(1)
	@show CramerV([2, 3, 2, 3, 3, 1, 3, 1], [2, 3, 1, 3, 2, 3, 3, 3]) 
	# 0.6021
	#@show CramerV([2, 3, 1, 1, 1, 3, 3, 1], [3, 1, 2, 3, 1, 2, 1, 3])
	# 0.493

	local x = rand(1:40, 100000)
	local y = rand(1:40, 100000)
	# @btime $cramerV($x, $y)
	# @btime $CramerV($x, $y) 
end

# ╔═╡ Cell order:
# ╠═0bd2ff80-8cc8-11eb-249c-05fd1d04ee1c
# ╠═24470d18-8cc8-11eb-0e01-afa021d534e2
# ╠═903e2dce-8e0d-11eb-26e8-f15c4fbd1336
# ╠═d5f48e14-8e0d-11eb-0d6c-5d9c6c409481
# ╠═8b2bd284-8cc8-11eb-222a-65dbbf1555f5
# ╟─5c36f1f0-8cca-11eb-114e-15ba6d89f884
# ╠═5053b29e-8cc8-11eb-3e15-53e86ce54942
# ╟─0936796c-8cca-11eb-2d1a-bf4aa18703b4
# ╠═c25cd556-8d2d-11eb-03b7-997d9675eef9
# ╠═0e2980e4-8d48-11eb-2e20-2d1703ba2006
# ╠═ceda8362-8d3c-11eb-2f0a-9b5aa19093fd
# ╠═033398ce-8d47-11eb-0991-09d02ec9bf64
# ╠═52d51e60-8d3e-11eb-302c-0b8efaf77201
# ╠═90714656-8d3c-11eb-3021-bb11933bfa4b
# ╠═4c7c530c-8d3f-11eb-2597-15fe01f3cd62
# ╠═6abfedb4-8d40-11eb-17c3-c139d90ca0f0
# ╠═74a7ae3a-8d3f-11eb-213f-bda4fe9b2f70
# ╠═3ae42218-8e12-11eb-27bb-a7af14e2f135
# ╠═816abdc6-8ccf-11eb-0366-ff8ba71d8c9a
# ╠═45f18f5e-8dfd-11eb-2fe6-89cf2eb621f5
# ╠═c0ba004a-8ccf-11eb-2780-0da2557619ac
# ╟─adbb82ee-8d46-11eb-2b3a-af214bf6d62b
# ╟─4f3c0198-8d33-11eb-04f2-939e9122e206
# ╠═358c4ff0-8d97-11eb-287c-e1468d30380b
# ╠═73d77300-8d99-11eb-37e1-3902a8f51a7d
# ╠═8fe258d2-8d97-11eb-1fba-cb9cc41c920c
# ╠═05ead5ea-8d98-11eb-3dc3-a5f70af3352f
# ╠═0062eaae-8d98-11eb-3f7c-db753bf19b6b
# ╠═4eda9106-8d97-11eb-22c1-79ebe79e9419
# ╠═d91a20e8-8d47-11eb-1a98-13810556aeff
# ╠═c2e650f8-8d47-11eb-1590-27739a81c84d
# ╠═2e204978-8d48-11eb-2ec2-5d7d91d33738
# ╠═c75c84a2-8df6-11eb-1b7f-4bab123f860f
# ╠═d69bed7e-8df6-11eb-3ec3-212ca4fb3b91
# ╠═26f3f28c-8dff-11eb-2b3c-ab9673d17e00
# ╠═849bd920-8d48-11eb-329e-fb4837b2869d
# ╠═78b53eea-8dfe-11eb-3fe8-9b393e6bf964
# ╠═f6dd0c48-8dfc-11eb-19cf-5fc77173e174
# ╠═780fb35a-8e05-11eb-2351-ff0a3dc1e164
# ╠═caa36374-8e0c-11eb-2a87-6784b7700d1e
# ╠═6fd3ea06-8df6-11eb-1652-d1417c5951c4
