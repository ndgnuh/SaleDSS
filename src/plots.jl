using Clustering
using PlotlyJS

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
