function draft()
    return dcc_graph(;
        id="basic-interactions",
        figure=(
            data=[
                (
                    x=[1, 2, 3, 4],
                    y=[4, 1, 3, 5],
                    text=["a", "b", "c", "d"],
                    customdata=["c.a", "c.b", "c.c", "c.d"],
                    name="Trace 1",
                    mode="markers",
                    marker=(size=12,),
                ),
                (
                    x=[1, 2, 3, 4],
                    y=[9, 4, 1, 4],
                    text=["w", "x", "y", "z"],
                    customdata=["c.w", "c.x", "c.y", "c.z"],
                    name="Trace 2",
                    mode="markers",
                    marker=(size=12,),
                ),
            ],
            layout=(clickmode="event+select",),
        ),
    )
end
