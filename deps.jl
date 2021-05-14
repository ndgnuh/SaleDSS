using Pkg
Pkg.activate(@__DIR__)
Pkg.add(PackageSpec(url="https://github.com/plotly/DashBase.jl.git"))
Pkg.add(PackageSpec(url="https://github.com/plotly/dash-html-components.git", rev="master"))
Pkg.add(PackageSpec(url="https://github.com/plotly/dash-core-components.git", rev="master"))
Pkg.add(PackageSpec(url="https://github.com/plotly/dash-table.git", rev="master"))
Pkg.add(PackageSpec(url="https://github.com/plotly/Dash.jl.git", rev="dev"))
