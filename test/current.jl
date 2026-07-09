using CairoMakie
using GraphMakie
using Graphs

g = Graphs.Grid((1, 2))

let
    f = Figure(size=(500, 500))
    # f = Figure(size=(1500, 1500))
    ax = Axis(f[1, 1])
    graphplot!(ax, g; arrow_show=true, node_size=200, arrow_shift=0.5, arrow_size=30, node_outset=0.000001, node_color=(:red, 0.4))
    f
end