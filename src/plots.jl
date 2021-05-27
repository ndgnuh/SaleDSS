using Clustering
using PlotlyJS
using JSON3

function single_plot(result, X, Y)
    assignments = result.assignments
    clusterid = sort(unique(assignments))
    data = map(clusterid) do id
        (mode="markers", x=X[@. assignments == id], y=Y[@. assignments == id], marker_size=12)
    end
    return dcc_graph(; figure=(data=data,))
end

function elbow_plot(results)
    X = map(nclusters, results)
    Y = map(r -> r.totalcost, results)
    t = scatter(; x=X, y=Y, mode="lines+markers", marker_size=10)
    return dcc_graph(; #
        figure=(
            data=[(x=X, y=Y, mode="lines+markers", marker_size=10)], #
            layout=(clickmode="event+select",),
        ),
    )
end

PamResult = NamedTuple{(:medoids, :assignments)}
function plot_result(r::Union{KmeansResult,KmedoidsResult,PamResult}, X, i, j; kwargs...)
    i0 = findfirst(i .== names(X))
    j0 = findfirst(j .== names(X))
    centers = if r isa KmeansResult
        nrow = size(r.centers, 1)
        try
            (r.centers[i0, :], r.centers[j0, :])
        catch e
            @warn e
            ([], [])
        end
    elseif r isa KmedoidsResult || r isa PamResult
        data = X[r.medoids, :]
        (data[:, i0], data[:, j0])
    end
    clusters = unique(r.assignments)
    ctrace = scatter(;#
        x=centers[1],
        y=centers[2],
        mode="markers",
        name="Centers",
        marker_size=20,
    )
    traces = [
        begin
            scatter(;#
                mode="markers",
                x=X[r.assignments .== c, i],
                y=X[r.assignments .== c, j],
            )
        end for c in clusters
    ]
    p = plot([traces; ctrace])
    return graph(p; kwargs...)
end

function graph(p; kwargs...)
    jp = json(p)
    figure = JSON3.read(jp, NamedTuple{(:data, :frames, :layout)})
    return dcc_graph(; figure=figure, kwargs...)
end
