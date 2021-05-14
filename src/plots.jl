function plotline(x, y; name="", id="")
    return dcc_graph(;
        id=id,
        figure=(
            data=[(x=x, y=y, mode="line", name=name, marker=(size=12,))],
            layout=(clickmode="event+select",),
        ),
    )
end

function plotline(y; kwargs...)
	plotline(eachindex(y), y; kwargs...)
end
