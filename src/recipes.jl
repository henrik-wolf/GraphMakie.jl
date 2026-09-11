using LinearAlgebra: normalize, ⋅, norm
using NetworkLayout: AbstractLayout, dim
export GraphPlot, graphplot, graphplot!, Arrow

const Arrow = Makie.Polygon(Point2f.([(-0.5,-0.5),(0.5,0),(-0.5,0.5),(-0.25,0)]))

function format_attributes(d, names)
    io = IOBuffer()
    for name in names
        default = d[name].default_expr
        print(io, "- **`", name, "`** = ", " `", default, "`  — ")
        println(io, something(d[name].docstring, "*No docs available.*"))
    end
    return String(take!(io))
end

function graphplot_docstring(PlotType)
    d = Makie.documented_attributes(PlotType).d
    return """
            graphplot(graph::AbstractGraph; kwargs...)
            graphplot!(ax, graph::AbstractGraph; kwargs...)

        Creates a plot of the network `graph`. Consists of multiple steps:
        - Layout the nodes: see `layout` attribute. The node position is accessible from outside
            the plot object `p` as an observable using `p[:node_pos]`.
        - plot edges as `edgeplot`-plot
        - if `arrow_show` plot arrowheads as `scatter`-plot
        - plot nodes as `scatter`-plot
        - if `nlabels!=nothing` plot node labels as `text`-plot
        - if `elabels!=nothing` plot edge labels as `text`-plot

        The main attributes for the subplots are exposed as attributes for `graphplot`.
        Additional attributes for the `scatter`, `edgeplot` and `text` plots can be provided
        as a named tuples to `node_attr`, `edge_attr`, `nlabels_attr` and `elabels_attr`.

        Most of the arguments can be either given as a vector of length of the
        edges/nodes or as a single value. One might run into errors when changing the
        underlying graph and therefore changing the number of Edges/Nodes.

        ## Plot type
        The plot type alias for the `graphplot` function is `GraphPlot`.

        ## Attributes
        ### Main attributes
        $(format_attributes(d,
            [:layout, :node_color, :node_size, :node_marker, :node_strokewidth, :node_outset, :node_attr,
            :edge_color, :edge_width, :edge_linestyle, :edge_outset, :edge_attr, :arrow_show, :arrow_marker,
            :arrow_size, :arrow_shift, :arrow_attr]
        ))

        ### Node labels
        The position of each label is determined by the node position plus an offset in data space.
        $(format_attributes(d,
            [:nlabels, :nlabels_align, :nlabels_distance, :nlabels_color, :nlabels_offset, :nlabels_fontsize,
            :nlabels_attr]
        ))

        ### Inner node labels
        Put labels inside the marker. If labels are provided, change default attributes to
        `node_marker=Circle`, `node_strokewidth=1` and `node_color=:gray80`.
        The `node_size` will match size of the `ilabels`.
        $(format_attributes(d,
            [:ilabels, :ilabels_color, :ilabels_fontsize, :ilabels_attr]
        ))

        ### Edge labels
        The base position of each label is determined by `src + shift*(dst-src)`. The
        additional `distance` parameter is given in pixels and shifts the text away from
        the edge.
        $(format_attributes(d,
            [:elabels, :elabels_align, :elabels_side, :elabels_distance, :elabels_shift, :elabels_rotation,
            :elabels_offset, :elabels_color, :elabels_fontsize, :elabels_attr]
        ))
            
        Self edges / loops:
        $(format_attributes(d,
            [:selfedge_size, :selfedge_direction, :selfedge_width]
        ))
        - Note: If valid waypoints are provided for selfloops, the selfedge attributes above will be ignored.

        High level interface for curvy edges:
        $(format_attributes(d,
            [:force_straight_edges, :curve_distance, :curve_distance_usage]
        ))

        Tangents interface for curvy edges:
        $(format_attributes(d,
            [:tangents, :tfactor]
        ))
        - Note: Tangents are ignored on selfloops if no waypoints are provided.

        Waypoints along edges:
        $(format_attributes(d,
            [:waypoints, :waypoint_radius]
        ))
        """
end

@recipe GraphPlot (graph,) begin
    "Function `AbstractGraph->Vector{Point}` or `Vector{Point}` that determines the base layout. Can also be any network layout from [NetworkLayout.jl](https://github.com/JuliaGraphs/NetworkLayout.jl), like `Spring`, `Stress`, `Spectral`, etc., defaults to `Spring()`"
    layout=automatic
    # node attributes (Scatter)
    "Defaults to `@inherit markercolor` in absence of `ilabels`."
    node_color=automatic
    "Defaults to `@inherit markersize` in absence of `ilabels`. Otherwise choses node size based on `ilabels` size."
    node_size=automatic
    "Defaults to `@inherit marker` in absence of `ilabels`."
    node_marker=automatic
    "Defaults to `@inherit markerstrokewidth` in absence of `ilabels`."
    node_strokewidth=automatic
    "Creates a small gap between edges and nodes. `nothing` skips the calcuation while `0.0` adjusts the endpoints to the edges of the marker, which can be useful with transparent nodes."
    node_outset=nothing
    "List of kw arguments which gets passed to the `scatter` command."
    node_attr=(;)
    # edge attributes (LineSegements)
    "Color for edges."
    edge_color = @inherit linecolor
    "Edge width. On backends that support variable linewidths, you can use a tuple `(start, stop)` per edge for tapered edges."
    edge_width = @inherit linewidth
    "Linestyle of edges. Can also be vector or dict for per-edge styling. When using different linestyles for different edges, GraphMakie creates separate line plots for each edge rather than combining them into one plot, which may reduce performance for graphs with many edges. For optimal performance with large graphs, use homogeneous linestyles."
    edge_linestyle=:solid
    "Creates a small gap between nodes and the endpoints of the edges. Control the start and end gap separately with tuple `(startgap, endgap)`. This parameter is additive to `node_outset`."
    edge_outset=(nothing, nothing)
    "List of kw arguments which gets passed to the underlying `lines` command used for plotting edges."
    edge_attr=(;)
    # arrow attributes (Scatter)
    "`Bool`, indicate edge directions with arrowheads? Defaults to `Graphs.is_directed(graph)`."
    arrow_show=automatic
    "Marker used as arrowhead."
    arrow_marker=('➤')
    "Size of arrowheads."
    arrow_size = @inherit markersize
    "Shift arrow position from source (0) to dest (1) node. If `arrow_shift=:end`, the arrowhead will be placed on the surface of the destination node (assuming the destination node is circular)."  # TODO: remove the circular stipulation once we can do non-circular markers
    arrow_shift=0.5
    "Orientation of edge for arrow head. Either `:forward` or `:reverse`, defines at which end of the Edge `:end` is."
    arrow_orientation=:forward
    "List of kw arguments which gets passed to the `scatter` command."
    arrow_attr=(;)
    # node label attributes (Text)
    "`Vector{String}` with label for each node."
    nlabels=nothing
    "Anchor of text field."
    nlabels_align=(:left, :bottom)
    "Pixel distance from node in direction of align."
    nlabels_distance=0.0
    "Text color of node labels."
    nlabels_color=@inherit textcolor
    "`Point` or `Vector{Point}` (in data space)."
    nlabels_offset=nothing
    "Fontsize of node labels."
    nlabels_fontsize=@inherit fontsize
    "List of kw arguments which gets passed to the `text` command."
    nlabels_attr=(;)
    # inner node labels
    "`Vector` with label for each node."
    ilabels=nothing
    "Text color of inner node labels."
    ilabels_color=@inherit textcolor
    "Fontsize of inner node labels."
    ilabels_fontsize=@inherit fontsize
    "List of kw arguments which gets passed to the `text` command."
    ilabels_attr=(;)
    # edge label attributes (Text)
    "`Vector{String}` with label for each edge."
    elabels=nothing
    "Anchor of text field."
    elabels_align=(:center, :center)
    "Side of the edge to put the edge label text."
    elabels_side=:left
    "Pixel distance of anchor to edge. The direction is decided based on `elabels_side`."
    elabels_distance=automatic
    "Position between src and dst of edge."
    elabels_shift=0.5
    "Angle of text per label. If `nothing` this will be determined by the edge angle. If `automatic` it will also point upwards making it easy to read."
    elabels_rotation=automatic
    "Additional offset in data space."
    elabels_offset=nothing
    "Text color of edge labels."
    elabels_color=@inherit textcolor
    "Fontsize of edge labels."
    elabels_fontsize=@inherit fontsize
    "List of kw arguments which gets passed to the `text` command."
    elabels_attr=(;)
    # self edge attributes
    "Size of selfloop (dict/vector possible)."
    selfedge_size=automatic
    "Direction of center of the selfloop as `Point2` (dict/vector possible)."
    selfedge_direction=automatic
    "Opening of selfloop in rad (dict/vector possible)."
    selfedge_width=automatic
    "If `true`, ignore all curvy edge attributes and draw all edges as straight lines."
    force_straight_edges=false
    "Specify a distance of the (now curved) line to the straight line *in data space*. Can be single value, array or dict. User provided `tangents` or `waypoints` will overrule this property."
    curve_distance=0.1
    "If `Makie.automatic()`, only plot double edges in a curvy way. Other options are `true` and `false`."
    curve_distance_usage=automatic
    "Specify a pair of tangent vectors per edge (for src and dst). If `nothing` (or edge idx not in dict) draw a straight line."
    tangents=nothing
    "Factor is used to calculate the bezier waypoints from the (normalized) tangents. Higher factor means bigger radius. Can be tuple per edge to specify different factor for src and dst."
    tfactor=0.6
    "Specify waypoints for edges. This parameter should be given as a vector or dict. Waypoints will be crossed using natural cubic splines. The waypoints may or may not include the src/dst positions."
    waypoints=nothing
    "If the attribute `waypoint_radius` is `nothing` or `:spline` the waypoints will be crossed using natural cubic spline interpolation. If number (dict/vector possible), the waypoints won't be reached, instead they will be connected with straight lines which bend in the given radius around the waypoints."
    waypoint_radius=nothing
end

# replace the Makie generated docstring for `graphplot` with our custom one
let
    # suppress warning about overwriting docstring
    # (https://discourse.julialang.org/t/is-there-any-way-to-remove-the-docstrings-for-all-methods-of-a-function/1497/12)
    docs = Docs.meta(@__MODULE__)
    docs[Docs.Binding(@__MODULE__, :graphplot)] = Docs.MultiDoc()
    @doc graphplot_docstring(GraphPlot) graphplot
end

function Makie.plot!(gp::GraphPlot)
    scene_theme = theme(gp)
    graph_theme = default_theme(gp, GraphPlot)

    # TODO: check that there are no non-scalar values set as default values...

    # create initial vertex positions, will be updated on changes to graph or layout
    # make node_position-Observable available as named attribute from the outside
    default_layout = Spring()
    map!(gp.attributes, [:layout, :graph], :node_pos) do layout, graph
        if layout isa AbstractVector
            if length(layout) != nv(graph)
                throw(ArgumentError("The length of the layout vector does not match the number of nodes in the graph!"))
            else
                to_pointf32.(layout)
            end
        else
            resolved_layout = layout === automatic ? default_layout : layout
            [to_pointf32(p) for p in resolved_layout(graph)]
        end
    end

    sc = Makie.parent_scene(gp)
    add_input!(gp.attributes, :viewport, sc.viewport)
    add_input!(gp.attributes, :projectionview, sc.camera.projectionview)

    # function which projects the point in px space
    map!(gp.attributes, [:viewport, :projectionview], :to_px) do pxa, pv
        # project should transform to 2d point in px space
        (point) -> project(sc, point)
    end
    # get angle in px space from path p at point t
    map!(gp.attributes, :to_px, :to_angle) do to_px
        (path, p0, t) -> begin
            # TODO: maybe shorter tangent? For some perspectives this might give wrong angles in 3d
            p1 = p0 + tangent(path, t)
            any(isnan, p1) && return 0.0  # lines with zero lengths might lead to NaN tangents
            pos_px = to_px(p1) - to_px(p0)
            atan(pos_px[2], pos_px[1])
        end
    end

    # MARK: Set up data for ilabels plot
    map!(x->UnstablePerNodeAttribute(x, graph_theme.ilabels), gp.attributes, :ilabels, :ilabels_m)
    map!(x->UnstablePerNodeAttribute(x, scene_theme.textcolor[]), gp.attributes, :ilabels_color, :ilabels_color_m)
    map!(x->UnstablePerNodeAttribute(x, scene_theme.fontsize[]), gp.attributes, :ilabels_fontsize, :ilabels_fontsize_m)

    map!(gp.attributes, [:ilabels_m, :graph], :ilabel_node_ids) do ilabels, graph
        [i for i in vertices(graph) if !isnothing(ilabels[i])]
    end

    map!(gp.attributes, [:node_pos, :ilabel_node_ids], :ilabel_plot_positions) do node_pos, nodes
        node_pos[nodes]
    end

    map!(gp.attributes, [:ilabels_m, :ilabel_node_ids], :ilabel_plot_texts) do ilabels, nodes
        # TODO: with Makie 0.25 this no longer need to be a string.
        [string(ilabels[i]) for i in nodes] # text always needs to be a vector matching node pos
    end

    map!(expand_vertex_attributes, gp.attributes, [:ilabels_color_m, :ilabel_node_ids], :ilabel_plot_color)
    map!(expand_vertex_attributes, gp.attributes, [:ilabels_fontsize_m, :ilabel_node_ids], :ilabel_plot_fontsize)

    map!(!isempty, gp.attributes, :ilabel_node_ids, :ilabel_plot_visible)
    ilabels_plot = text!(gp, gp[:ilabel_plot_positions];
        text=gp[:ilabel_plot_texts],
        align=(:center, :center),
        color=gp[:ilabel_plot_color],
        fontsize=gp[:ilabel_plot_fontsize],
        visible=gp[:ilabel_plot_visible],
        # TODO: this breaks reactivity for ilabel attributes
        gp.ilabels_attr[]...)
    add_constant!(gp.attributes, :ilabels_plot, ilabels_plot) #make plotobj accessible

    # MARK: resolve node attributes influenced by ilabels
    map!(x->UnstablePerNodeAttribute(x, graph_theme.node_size), gp.attributes, :node_size, :node_size_m)
    map!(gp.attributes, [:ilabel_plot_visible, :ilabels_plot, :ilabel_node_ids, :ilabels_fontsize_m, :node_size_m, :graph], :node_size_expanded) do ilabel_plot_visible, ilabels_plot, ilabel_node_ids, ilabels_fontsize, node_size, graph
        node_size_value = if ilabel_plot_visible
            # find the computed node sizes for all nodes with ilabels
            overwritten_node_sizes = map(zip(ilabel_node_ids, Makie.fast_string_boundingboxes(ilabels_plot))) do (id, bb)
                _ns = node_size[id]
                if _ns === automatic
                    id => norm(bb.widths) + 0.1 * ilabels_fontsize[id]
                else
                    id => _ns
                end
            end |> Dict

            # add all non-ilabel nodes which have a non-default size
            for v in vertices(graph)
                _ns = node_size[v]
                if !(v in ilabel_node_ids) && _ns !== automatic && _ns !== scene_theme.markersize[]
                    overwritten_node_sizes[v] = _ns
                end
            end
            overwritten_node_sizes
        else
            node_size.value === automatic ? scene_theme.markersize[] : node_size.value
        end

        UnstablePerNodeAttribute(node_size_value, scene_theme.markersize[])
    end


    map!(x->UnstablePerNodeAttribute(x, graph_theme.node_color), gp.attributes, :node_color, :node_color_m) 
    map!(gp.attributes, [:ilabel_plot_visible, :node_color_m, :ilabel_node_ids, :graph], :node_color_expanded) do ilabel_plot_visible, node_color, ilabel_node_ids, graph
        node_color_value = if ilabel_plot_visible
            overwritten_node_colors = map(ilabel_node_ids) do id
                _col = node_color[id]
                id => _col == automatic ? :gray80 : _col
            end |> Dict

            for v in vertices(graph)
                _col = node_color[v]
                if !(v in ilabel_node_ids) && _col !== automatic && _col !== scene_theme.markercolor[]
                    overwritten_node_colors[v] = _col
                end
            end
            overwritten_node_colors
        else
            node_color.value === automatic ? scene_theme.markercolor[] : node_color.value
        end

        UnstablePerNodeAttribute(node_color_value, scene_theme.markercolor[])
    end


    map!(x->UnstablePerNodeAttribute(x, graph_theme.node_marker), gp.attributes, :node_marker, :node_marker_m) 
    map!(gp.attributes, [:ilabel_plot_visible, :node_marker_m, :ilabel_node_ids, :graph], :node_marker_expanded) do ilabel_plot_visible, node_marker, ilabel_node_ids, graph
        node_marker_value = if ilabel_plot_visible
            overwritten_node_markers = map(ilabel_node_ids) do id
                _mark = node_marker[id]
                id => _mark === automatic ? Circle : _mark
            end |> Dict

            for v in vertices(graph)
                _mark = node_marker[v]
                if !(v in ilabel_node_ids) && _mark !== automatic && _mark !== scene_theme.marker[]
                    overwritten_node_markers[v] = _mark
                end
            end
            overwritten_node_markers
        else
            node_marker.value === automatic ? scene_theme.marker[] : node_marker.value
        end

        UnstablePerNodeAttribute(node_marker_value, scene_theme.marker[])
    end

    map!(x->UnstablePerNodeAttribute(x, graph_theme.node_strokewidth), gp.attributes, :node_strokewidth, :node_strokewidth_m) 
    map!(gp.attributes, [:ilabel_plot_visible, :node_strokewidth_m, :ilabel_node_ids, :graph], :node_strokewidth_expanded) do ilabel_plot_visible, node_strokewidth, ilabel_node_ids, graph
        node_strokewidth_value = if ilabel_plot_visible
            overwritten_node_strokewidths = map(ilabel_node_ids) do id
                _sw = node_strokewidth[id]
                id => _sw === automatic ? 1.0 : _sw
            end |> Dict

            for v in vertices(graph)
                _sw = node_strokewidth[v]
                if !(v in ilabel_node_ids) && _sw !== automatic && _sw !== scene_theme.markerstrokewidth[]
                    overwritten_node_strokewidths[v] = _sw
                end
            end
            overwritten_node_strokewidths
        else
            node_strokewidth.value === automatic ? scene_theme.markerstrokewidth[] : node_strokewidth.value
        end

        UnstablePerNodeAttribute(node_strokewidth_value, scene_theme.markerstrokewidth[])
    end

    # MARK: edges
    # compute initial edge paths; will be adjusted later if arrow_shift = :end
    # create array of paths triggered by node_pos changes
    # in case of a graph change the node_position will change anyway

    map!(x -> UnstablePerEdgeAttribute(x, graph_theme.curve_distance_usage), gp.attributes, :curve_distance_usage, :curve_distance_usage_m)
    map!(x -> UnstablePerEdgeAttribute(x, graph_theme.curve_distance), gp.attributes, :curve_distance, :curve_distance_m)
    map!(x -> UnstablePerEdgeAttribute(x, graph_theme.selfedge_size), gp.attributes, :selfedge_size, :selfedge_size_m)
    map!(x -> UnstablePerEdgeAttribute(x, graph_theme.selfedge_direction), gp.attributes, :selfedge_direction, :selfedge_direction_m)
    map!(x -> UnstablePerEdgeAttribute(x, graph_theme.selfedge_width), gp.attributes, :selfedge_width, :selfedge_width_m)
    map!(x -> UnstablePerEdgeAttribute(x, graph_theme.tangents), gp.attributes, :tangents, :tangents_m)
    map!(x -> UnstablePerEdgeAttribute(x, graph_theme.tfactor), gp.attributes, :tfactor, :tfactor_m)
    map!(x -> UnstablePerEdgeAttribute(x, graph_theme.waypoints), gp.attributes, :waypoints, :waypoints_m)
    map!(x -> UnstablePerEdgeAttribute(x, graph_theme.waypoint_radius), gp.attributes, :waypoint_radius, :waypoint_radius_m)
    map!(x -> UnstablePerEdgeAttribute(x, graph_theme.arrow_orientation), gp.attributes, :arrow_orientation, :arrow_orientation_m)

    map!(
        gp.attributes, [
            :graph, :node_pos, :force_straight_edges, :curve_distance_usage_m, :curve_distance_m,
            :selfedge_size_m, :selfedge_direction_m, :selfedge_width_m,
            :tangents_m, :tfactor_m, :waypoints_m, :waypoint_radius_m,
        ], :edge_paths
    ) do graph, node_pos, args...
        # returns vector of paths
        find_edge_paths(graph, node_pos, args...)
    end

    map!(gp.attributes, [:arrow_show, :graph], :arrow_show_m) do arrow_show, g
        if arrow_show === automatic
            UnstablePerEdgeAttribute(Graphs.is_directed(g))
        else
            UnstablePerEdgeAttribute(arrow_show, Graphs.is_directed(g))
        end
    end


    map!(x -> UnstablePerNodeAttribute(x, graph_theme.node_outset), gp.attributes, :node_outset, :node_outset_m)
    map!(x -> UnstablePerEdgeAttribute(x, graph_theme.edge_outset), gp.attributes, :edge_outset, :edge_outset_m)
    map!(x -> UnstablePerEdgeAttribute(x, graph_theme.arrow_marker), gp.attributes, :arrow_marker, :arrow_marker_m)
    map!(x -> UnstablePerEdgeAttribute(x, graph_theme.arrow_size), gp.attributes, :arrow_size, :arrow_size_m)
    map!(x -> UnstablePerEdgeAttribute(x, graph_theme.arrow_shift), gp.attributes, :arrow_shift, :arrow_shift_m)
    map!(x -> UnstablePerEdgeAttribute(x, graph_theme.edge_color), gp.attributes, :edge_color, :edge_color_m)
    map!(x -> UnstablePerEdgeAttribute(x, graph_theme.edge_width), gp.attributes, :edge_width, :edge_width_m)
    map!(x -> UnstablePerEdgeAttribute(x, graph_theme.edge_linestyle), gp.attributes, :edge_linestyle, :edge_linestyle_m)


    # find shifts along edge path that intersect with node marker, including arrow size, short circuits when no shifting is required
    map!(gp.attributes,
         [:graph, :edge_paths, :node_pos, :to_px, :node_marker_expanded, :node_size_expanded, :node_outset_m, :edge_outset_m,
          :arrow_marker_m, :arrow_shift_m, :arrow_size_m, :arrow_orientation_m, :arrow_show_m],
         :start_end_shifts
         ) do g, paths, node_pos, to_px, nmarker, nsize, noutset, eoutset, arrow_marker, arrow_shift, arrow_size,
              arrow_orientation, arrow_show
        return find_start_end_shift(g, paths, node_pos, to_px, nmarker, nsize, noutset, eoutset, arrow_marker,
                                    arrow_shift, arrow_size, arrow_orientation, arrow_show)
    end

    # prepare edge plot attributes (makes them vectors of length ne(g) or single elements)
    map!(expand_edge_attributes, gp.attributes, [:edge_color_m, :graph], :edge_plot_color)
    map!(expand_vertex_attributes, gp.attributes, [:edge_width_m, :graph], :edge_plot_linewidth)
    map!(expand_vertex_attributes, gp.attributes, [:edge_linestyle_m, :graph], :edge_plot_linestyle)

    # actually plot edges
    edge_plot = edgeplot!(gp, gp[:edge_paths], gp[:start_end_shifts];
        color=gp[:edge_plot_color],
        linewidth=gp[:edge_plot_linewidth],
        linestyle=gp[:edge_plot_linestyle],
        # TODO: this drops reactivity for edge attributes
        gp.edge_attr[]...)
    add_constant!(gp.attributes, :edge_plot, edge_plot) #make plotobj accessible


    # MARK: prepare arrow heads
    map!(gp.attributes, [:arrow_show_m, :graph], :arrow_edge_ids) do arrow_show, graph
        [(i, e) for (i, e) in enumerate(edges(graph)) if arrow_show[i, e]]
    end

    map!(gp.attributes,
         [:edge_paths, :start_end_shifts, :arrow_shift_m, :arrow_orientation_m, :arrow_edge_ids],
         :arrow_shift_expanded) do edge_paths, start_end_shifts, arrow_shift, arrow_orientation, arrow_edge_ids
        return find_arrow_shift(edge_paths, start_end_shifts, arrow_shift, arrow_orientation, arrow_edge_ids)
    end

    map!(gp.attributes, [:edge_paths, :arrow_shift_expanded, :arrow_edge_ids, :node_pos],
         :arrow_pos
         ) do paths, arrow_shifts, arrow_edge_ids, np
        if !isempty(arrow_edge_ids)
            map(arrow_edge_ids, arrow_shifts) do (edge_id, _), shift
                return interpolate(paths[edge_id], shift)
            end
        else # if no arrows return (empty) vector of points, broadcast yields Vector{Any} which can't be plotted
            Vector{eltype(np)}()
        end
    end

    map!(gp.attributes,
         [:edge_paths, :to_angle, :arrow_shift_expanded, :arrow_pos, :arrow_orientation_m, :arrow_edge_ids], :arrow_rot
         ) do paths, to_angle, arrow_shifts, arrow_positions, arrow_orientations, arrow_edge_ids
        if !isempty(arrow_edge_ids)
            angles = map(arrow_edge_ids, arrow_shifts, arrow_positions) do (i, e), shift, arrow_pos
                angle = to_angle(paths[i], arrow_pos, shift)
                if arrow_orientations[i,e] === :reverse
                    angle + π
                else
                    angle
                end
            end
            Billboard(angles)
        else
            Billboard(Float32[])
        end
    end

    map!(expand_edge_attributes, gp.attributes, [:arrow_marker_m, :arrow_edge_ids], :arrowplot_marker)
    map!(expand_edge_attributes, gp.attributes, [:arrow_size_m, :arrow_edge_ids], :arrowplot_markersize)
    map!(expand_edge_attributes, gp.attributes, [:edge_color_m, :arrow_edge_ids], :arrowplot_color)

    map!(!isempty, gp.attributes, :arrow_edge_ids, :arrowplot_visible)
    arrow_plot = scatter!(gp,
        gp[:arrow_pos];
        marker = gp[:arrowplot_marker],
        markersize = gp[:arrowplot_markersize],
        color = gp[:arrowplot_color],
        rotation = gp[:arrow_rot],
        strokewidth = 0.0,
        markerspace = :pixel,
        visible = gp[:arrowplot_visible],
        # TODO: this drops reactivity for arrow attributes
        gp.arrow_attr[]...)
    add_constant!(gp.attributes, :arrow_plot, arrow_plot) #make plotobj accessible

    # MARK: prepare node plot attributes
    map!(expand_vertex_attributes, gp.attributes, [:node_color_expanded, :graph], :node_plot_color)
    map!(expand_vertex_attributes, gp.attributes, [:node_marker_expanded, :graph], :node_plot_marker)
    map!(expand_vertex_attributes, gp.attributes, [:node_strokewidth_expanded, :graph], :node_plot_strokewidth)
    map!(expand_vertex_attributes, gp.attributes, [:node_size_expanded, :graph], :node_plot_markersize)

    vertex_plot = scatter!(gp, gp[:node_pos];
        color=gp[:node_plot_color],
        marker=gp[:node_plot_marker],
        markersize=gp[:node_plot_markersize],
        strokewidth=gp[:node_plot_strokewidth],
        # TODO: this drops reactivity for node attributes
        gp[:node_attr][]...)
    add_constant!(gp.attributes, :node_plot, vertex_plot) #make plotobj accessible

    # MARK: node labels
    map!(x->UnstablePerNodeAttribute(x, graph_theme.nlabels), gp.attributes, :nlabels, :nlabels_m)
    map!(x->UnstablePerNodeAttribute(x, scene_theme.textcolor[]), gp.attributes, :nlabels_color, :nlabels_color_m)
    map!(x->UnstablePerNodeAttribute(x, scene_theme.fontsize[]), gp.attributes, :nlabels_fontsize, :nlabels_fontsize_m)
    # TODO: default should be zero in correct dimensions, if nothing...
    map!(x->UnstablePerNodeAttribute(x, graph_theme.nlabels_offset), gp.attributes, :nlabels_offset, :nlabels_offset_m)
    map!(x->UnstablePerNodeAttribute(x, graph_theme.nlabels_align), gp.attributes, :nlabels_align, :nlabels_align_m)
    map!(x->UnstablePerNodeAttribute(x, graph_theme.nlabels_distance), gp.attributes, :nlabels_distance, :nlabels_distance_m)

    map!(gp.attributes, [:nlabels_m, :graph], :nlabel_node_ids) do nlabels, graph
        [i for i in vertices(graph) if !isnothing(nlabels[i])]
    end

    map!(gp.attributes, [:node_pos, :nlabels_offset_m, :nlabel_node_ids], :nlabel_plot_positions) do node_pos, offset, nodes
        map(nodes) do id
            _off = offset[id]
            if _off != nothing
                node_pos[id] + _off
            else
                node_pos[id]
            end
        end
    end

    map!(gp.attributes, [:nlabels_align_m, :nlabels_distance_m, :nlabel_node_ids], :nlabel_plot_offsets) do align, distance, nodes
        map(nodes) do id
            distance[id] * align_to_dir(align[id])
        end
    end

    map!(gp.attributes, [:nlabels_m, :nlabel_node_ids], :nlabel_plot_texts) do nlabels, nodes
        # TODO: with Makie 0.25 this no longer need to be a string.
        [string(nlabels[i]) for i in nodes]
    end

    map!(expand_vertex_attributes, gp.attributes, [:nlabels_color_m, :nlabel_node_ids], :nlabel_plot_color)
    map!(expand_vertex_attributes, gp.attributes, [:nlabels_fontsize_m, :nlabel_node_ids], :nlabel_plot_fontsize)
    map!(expand_vertex_attributes, gp.attributes, [:nlabels_align_m, :nlabel_node_ids], :nlabel_plot_align)

    map!(!isempty, gp.attributes, :nlabel_node_ids, :nlabel_plot_visible)
    nlabels_plot = text!(gp, gp[:nlabel_plot_positions];
        text=gp[:nlabel_plot_texts],
        align=gp[:nlabel_plot_align],
        color=gp[:nlabel_plot_color],
        offset=gp[:nlabel_plot_offsets],
        fontsize=gp[:nlabel_plot_fontsize],
        visible=gp[:nlabel_plot_visible],
        # TODO: this drops reactivity for node label attributes
        gp.nlabels_attr[]...)
    add_constant!(gp.attributes, :nlabels_plot, nlabels_plot) #make plotobj accessible

    # shuffle ilabels to back of list for them to be plotted on top
    circshift!(gp.plots, -1)

    # MARK: edge labels
    map!(x -> UnstablePerEdgeAttribute(x, graph_theme.elabels), gp.attributes, :elabels, :elabels_m)
    map!(x -> UnstablePerEdgeAttribute(x, graph_theme.elabels_shift), gp.attributes, :elabels_shift, :elabels_shift_m)
    map!(x -> UnstablePerEdgeAttribute(x, graph_theme.elabels_offset), gp.attributes, :elabels_offset, :elabels_offset_m)
    map!(x -> UnstablePerEdgeAttribute(x, graph_theme.elabels_rotation), gp.attributes, :elabels_rotation, :elabels_rotation_m)
    map!(x -> UnstablePerEdgeAttribute(x, graph_theme.elabels_distance), gp.attributes, :elabels_distance, :elabels_distance_m)
    map!(x -> UnstablePerEdgeAttribute(x, graph_theme.elabels_side), gp.attributes, :elabels_side, :elabels_side_m)
    map!(x -> UnstablePerEdgeAttribute(x, graph_theme.elabels_color), gp.attributes, :elabels_color, :elabels_color_m)
    map!(x -> UnstablePerEdgeAttribute(x, graph_theme.elabels_fontsize), gp.attributes, :elabels_fontsize, :elabels_fontsize_m)
    map!(x -> UnstablePerEdgeAttribute(x, graph_theme.elabels_align), gp.attributes, :elabels_align, :elabels_align_m)

    map!(gp.attributes, [:elabels_m, :graph], :elabel_edge_ids) do elabels, graph
        [(i, e) for (i, e) in enumerate(edges(graph)) if !isnothing(elabels[i, e])]
    end

    map!(gp.attributes, [:elabels_m, :elabel_edge_ids], :elabel_plot_texts) do elabels, elabel_edge_ids
        # TODO: with Makie 0.25 this no longer need to be a string.
        [string(elabels[i, e]) for (i,e) in elabel_edge_ids] # text always needs to be a vector matching edge pos
    end

    # positions: center point between nodes + offset + distance*normal + shift*edge direction
    map!(gp.attributes, [:edge_paths, :elabels_shift_m, :elabels_offset_m, :elabel_edge_ids], :elabel_plot_positions) do paths, shift, eloffset, elabel_edge_ids
        map(elabel_edge_ids) do (i, e)
            p1 = interpolate(paths[i], shift[i,e])
            el_off = eloffset[i,e]
            isnothing(el_off) ? p1 : p1 + el_off
        end
    end

    # rotations based on the edge_vec_px and opposite argument
    map!(gp.attributes, [:elabels_rotation_m, :to_angle, :elabel_plot_positions, :edge_paths, :elabels_shift_m, :elabel_edge_ids], :elabel_plot_rotations) do elabrots, to_angle, pos, paths, shift, elabel_edge_ids
        map(enumerate(elabel_edge_ids)) do (j,(i,e))
            valrot = elabrots[i, e]
            if valrot isa Real
                # fix rotation to a single angle
                valrot
            else
                rot = to_angle(paths[i], pos[j], shift[i, e])
                if valrot === automatic
                    # point the labels up
                    (rot > π/2 || rot < - π/2) ? rot + π : rot
                elseif isnothing(valrot)
                    rot
                else
                    throw(ArgumentError("Invalid elabel rotation $valrot for edge $e (id: $i)!"))
                end
            end
        end
    end

    # calculate the offset in pixels in normal direction to the edge
    map!(gp.attributes, [:elabel_plot_positions, :to_px, :elabels_distance_m, :elabels_side_m, :edge_paths, :elabels_shift_m, :elabels_fontsize_m, :edge_width_m, :elabel_edge_ids], :elabel_plot_offsets) do pos, to_px, dist, side, paths, shift, fontsize, edge_width, elabel_edge_ids
        map(enumerate(elabel_edge_ids)) do (j,(i,e))
            p0 = pos[j]
            p1 = p0 + tangent(paths[i], shift[i,e])
            tangent_px = to_px(p1) - to_px(p0)

            offset_direction = Point(-tangent_px.data[2], tangent_px.data[1])/norm(tangent_px)
            elabel_distance_offset(dist[i,e], side[i,e], fontsize[i,e], edge_width[i,e], i, e) * offset_direction
        end
    end

    map!(expand_edge_attributes, gp.attributes, [:elabels_align_m, :elabel_edge_ids], :elabel_plot_align)
    map!(expand_edge_attributes, gp.attributes, [:elabels_color_m, :elabel_edge_ids], :elabel_plot_color)
    map!(expand_edge_attributes, gp.attributes, [:elabels_fontsize_m, :elabel_edge_ids], :elabel_plot_fontsize)

    map!(!isempty, gp.attributes, :elabel_edge_ids, :elabel_plot_visible)
    elabels_plot = text!(gp, gp[:elabel_plot_positions];
        text=gp[:elabel_plot_texts],
        rotation=gp[:elabel_plot_rotations],
        offset=gp[:elabel_plot_offsets],
        align=gp[:elabel_plot_align],
        color=gp[:elabel_plot_color],
        fontsize=gp[:elabel_plot_fontsize],
        visible=gp[:elabel_plot_visible],
        # TODO: this drops reactivity for edge label attributes
        gp.elabels_attr[]...)
    add_constant!(gp.attributes, :elabels_plot, elabels_plot) #make plotobj accessible

    return gp
end

"""
    elabel_distance_offset(elabel_distance, elabel_side, elabel_fontsize, edge_width, i, e)

Returns the elabel_distance taking into consideration elabel_side
"""
function elabel_distance_offset(elabel_distance, elabel_side, elabel_fontsize, edge_width, i, e)
    distance = if elabel_distance isa Real
        elabel_distance
    elseif elabel_distance === automatic
        (elabel_fontsize + edge_width)/2
    else
        throw(ArgumentError("Invalid elabel distance $elabel_distance for edge $e (id: $i)!"))
    end

    if elabel_side == :left
        distance
    elseif elabel_side == :right
        -distance
    elseif elabel_side == :center
        zero(distance)
    else
        throw(ArgumentError("Invalid elabel side $elabel_side for edge $e (id: $i)!"))
    end
end

"""
    find_edge_paths(g, attr, pos::AbstractVector{PT}) where {PT}

Returns an `AbstractPath` for each edge in the graph. Returns a vector of
paths. If `force_straight_edges` is `true`, the paths will be just plain lines
"""
function find_edge_paths(g, node_pos::AbstractVector{PT}, force_straight_edges, curve_distance_usage, curve_distance, selfedge_size, selfedge_direction, selfedge_width, tangents, tfactor, waypoints, waypoint_radius) where {PT}
    # for straight_lines: return vector of Line rather than vector of AbstractPath
    if force_straight_edges
        return map(edges(g)) do e
            p1, p2 = node_pos[src(e)], node_pos[dst(e)]
            Path(p1, p2)
        end
    end

    paths = Vector{AbstractPath{PT}}(undef, ne(g))
    for (i, e) in enumerate(edges(g))
        p1, p2 = node_pos[src(e)], node_pos[dst(e)]

        tangents_i = tangents[i, e]
        tfactor_i = tfactor[i, e]

        waypoints_i = let wps = waypoints[i, e]
            wps = isnothing(wps) ? PT[] : PT.(wps)
            if !isempty(wps) &&(wps[begin] == p1 || wps[end] == p2)
                    #remove p1 and p2 from waypoints if they are given
                    wps[begin] == p1 && popfirst!(wps)
                    wps[end] == p2 && pop!(wps)
                    wps
            else
                wps
            end
        end

        cdu = curve_distance_usage[i, e]
        curve_distance_i = if cdu === true
            curve_distance[i, e]
        elseif cdu === false
            0.0
        elseif cdu === automatic
            if is_directed(g) && has_edge(g, dst(e), src(e))
                curve_distance[i, e]
            else
                0.0
            end
        else
            0.0
        end

        paths[i] = if !isempty(waypoints_i) #there are waypoints
            radius = waypoint_radius[i, e]
            if radius === nothing || radius === :spline
                Path(p1, waypoints_i..., p2; tangents=tangents_i, tfactor=tfactor_i)
            elseif radius isa Real
                Path(radius, p1, waypoints_i..., p2)
            else
                throw(ArgumentError("Invalid radius $radius for edge $e (id: $i)!"))
            end
        elseif src(e) == dst(e) # selfedge
            size = selfedge_size[i, e]
            direction = selfedge_direction[i, e]
            width = selfedge_width[i, e]
            selfedge_path(g, node_pos, src(e), size, direction, width)
        elseif !isnothing(tangents_i)
            Path(p1, p2; tangents=tangents_i, tfactor=tfactor_i)
        elseif PT <: Point2 && !iszero(curve_distance_i)
            curved_path(p1, p2, curve_distance_i)
        else # straight line
            Path(p1, p2)
        end
    end

    return paths
end

"""
    selfedge_path(g, pos, v, size, direction, width)

Return a BezierPath for a selfedge.
"""
function selfedge_path(g, pos::AbstractVector{<:Point2}, v, size, direction, width)
    vp = pos[v]
    # get the vectors to all the neighbors
    ndirs = [pos[n] - vp for n in all_neighbors(g, v) if n != v]

    # angle and maximum width of loop
    γ, Δ = 0.0, 0.0

    if direction === automatic && !isempty(ndirs)
        angles = SVector{length(ndirs)}(atan(p[2], p[1]) for p in ndirs)
        angles = sort(angles)

        for i in 1:length(angles)
            α = angles[i]
            β = get(angles, i+1, 2π + angles[1])
            if β-α > Δ
                Δ = β-α
                γ = (β+α) / 2
            end
        end

        # set width of selfloop
        Δ = min(.7*Δ, π/2)
    elseif direction === automatic && isempty(ndirs)
        γ = π/2
        Δ = π/2
    else
        @assert direction isa Point2 "Direction of selfedge should be 2 dim vector ($direction)"
        γ = atan(direction[2], direction[1])
        Δ = π/2
    end

    if width !== automatic
        Δ = width
    end

    # the size (max distance to v) of loop
    # if there are no neighbors set to 0.5. Else half dist to nearest neighbor
    if size === automatic
        size = isempty(ndirs) ? 0.5 : minimum(norm.(ndirs)) * 0.5
    end

    # the actual length of the tagent vectors, magic number from `CurveTo`
    l = Float32( size/(cos(Δ/2) * 2*0.375) )
    t1 = vp + l * Point2f(cos(γ-Δ/2), sin(γ-Δ/2))
    t2 = vp + l * Point2f(cos(γ+Δ/2), sin(γ+Δ/2))

    return BezierPath([MoveTo(vp),
                       CurveTo(t1, t2, vp)])
end

function selfedge_path(g, pos::AbstractVector{<:Point3}, v, size, direction, width)
    error("Self edges in 3D not yet supported")
end

"""
    curved_path(p1, p2, curve_distance)

Return a BezierPath for a curved edge (not selfedge).
"""
function curved_path(p1::PT, p2::PT, curve_distance) where {PT}
    d = curve_distance
    s = norm(p2 - p1)
    γ = 2*atan(2 * d/s)
    a = (p2 - p1)/s * (4*d^2 + s^2)/(3s)

    m = @SMatrix[cos(γ) -sin(γ); sin(γ) cos(γ)]
    c1 = PT(p1 + m*a)
    c2 = PT(p2 - transpose(m)*a)

    return BezierPath([MoveTo(p1), CurveTo(c1, c2, p2)])
end

@recipe EdgePlot (paths,start_end_offsets) begin
    Makie.documented_attributes(Lines)...
end

function Makie.plot!(p::EdgePlot)
    alllines = eltype(p[:paths][]) <: Line

    map!(p.attributes, [:paths, :start_end_offsets], [:points, :ranges]) do paths, start_end_offsets
        @assert length(paths) == length(start_end_offsets) "`paths` and `offsets` must have the same length!"

        PT = ptype(eltype(paths))
        points = PT[]
        ranges = UnitRange{Int}[]
        for (path, (start_offset, end_offset)) in zip(paths, start_end_offsets)
            disc = discretize(path, start_offset, end_offset)
            pstart = length(points) + 1
            append!(points, disc)
            push!(points, PT(NaN)) # add NaN to separate segments
            pstop = pstart+length(disc)
            push!(ranges, pstart:pstop)
        end
        (points, ranges)
    end

    # if the user specified different linestyles, we need to fall back to plotting n `lines` rather than plotting
    split_edgeplots = !(p[:linestyle][] isa Union{Nothing,Symbol,Linestyle})
    add_constant!(p.attributes, :split_edgeplots, split_edgeplots)

    if !split_edgeplots
        # expand color and linewidth attributes (for curved edges with multiple segments)
        map!(_expand_args, p.attributes, [:color, :ranges], :color_expanded)
        map!(_expand_args, p.attributes, [:linewidth, :ranges], :linewidth_expanded)

        lines!(p, p.attributes, p[:points];
            color=p[:color_expanded],
            linewidth=p[:linewidth_expanded],
        )
    else
        # manually find colorrange
        if p[:colorrange][] === automatic && p[:color][] isa Union{Number, AbstractVector}
            minc = Inf
            maxc = -Inf
            for c in p[:color][]
                if c isa Number
                    minc = min(minc, c)
                    maxc = max(maxc, c)
                elseif c isa AbstractVector{<:Number} || c isa Tuple{<:Number}
                    minc = min(minc, minimum(c))
                    maxc = max(maxc, maximum(c))
                end
            end
            if minc != Inf || maxc != -Inf
                p[:colorrange][] = Float32.((minc, maxc))
            end
        end

        for i in 1:length(p[:paths][])
            thispoints = Symbol(:points,i)
            map!(p.attributes, [:points, :ranges], thispoints) do points, ranges
                view(points, ranges[i][1:end-1])
            end

            lines!(p, p.attributes, p[thispoints];
                color=_split_arg!(p.attributes, :color, i),
                linewidth=_split_arg!(p.attributes, :linewidth, i),
                linestyle=_split_arg!(p.attributes, :linestyle, i),
            )
        end
    end

    return p
end

function _expand_args(args::Union{AbstractVector, AbstractDict}, ranges)
    N_paths = length(ranges)
    N_points = N_paths > 0 ? ranges[end][end] : 0
    allstraight = N_paths*3 == N_points
    if args isa AbstractVector && length(args) != N_paths
        throw(ArgumentError("The length of the args vector $args does not match the number of edges!"))
    end

    elT = eltype(args) <:Tuple ? eltype(eltype(args)) : eltype(args)
    elT = elT <: Integer ? Float32 : elT # convert integers to floats for interpolation
    expanded = Vector{elT}(undef, N_points)
    for i in 1:N_paths
        attr = getattr(args, i)
        if attr isa Union{Tuple, AbstractVector}
            if length(attr) == length(ranges[i]) - 1
                expanded[ranges[i][1:end-1]] .= attr
                expanded[ranges[i][end]] = attr[end] # last point is always the same
            elseif eltype(attr) <: Number && length(attr) == 2 # interpolate between numbers
                expanded[ranges[i][1:end-1]].= range(attr[1], attr[2], length=length(ranges[i])-1)
                expanded[ranges[i][end]] = attr[end] # last point is always the same
            else
                throw(ArgumentError("Don't know how to map $(attr) to the $(length(ranges[i])) points in this edge."))
            end
        else
            expanded[ranges[i]] .= args[i]
        end
    end
    expanded
end
_expand_args(arg, ranges) = arg
function _split_arg!(cg::Makie.ComputeGraph, name, i)
    splitname = Symbol(name, i)
    map!(cg, [name, Symbol(:points, i)], splitname) do prop, pointsi
        attr = getattr(prop, i)
        # interpolate numeric values for intermediate points
        if attr isa Union{Tuple,AbstractVector} && eltype(attr) <: Number && length(attr) == 2
            attr = range(attr[1], attr[2], length=length(pointsi))
        end
        attr
    end
    cg[splitname]
end

"""
    find_arrow_shift(g, gp, edge_paths::Vector{<:AbstractPath{PT}}, to_px) where {PT}

Checks `arrow_shift` attr so that `arrow_shift = :end` gets transformed so that the arrowhead for that edge
lands on the surface of the destination node.
"""
function find_arrow_shift(edge_paths::Vector{<:AbstractPath{PT}}, start_end_shifts, arrow_shifts, arrow_orientations, arrow_edge_ids) where {PT}
    arrow_shift = Vector{Float32}(undef, length(arrow_edge_ids))

    for (j, (i, e)) in enumerate(arrow_edge_ids)
        arrow_orientation = arrow_orientations[i, e]

        edge_shifts = start_end_shifts[i]
        t = arrow_shifts[i, e]
        arrow_shift[j] = if arrow_orientation === :forward
            t === :end ? edge_shifts[2] : t
        elseif arrow_orientation === :reverse
            t === :end ? edge_shifts[1] : 1-t
        else
            throw(ArgumentError("Invalid arrow orientation $arrow_orientation for edge $e (id: $i)!"))
        end
    end

    return arrow_shift
end

function find_arrow_shift(edge_paths::Vector{<:AbstractPath{<:Point3}}, start_end_shifts, arrow_shifts, arrow_orientations, arrow_edge_ids)
    arrow_shift = Vector{Float32}(undef, length(arrow_edge_ids))

    for (j, (i, e)) in enumerate(arrow_edge_ids)
        t = arrow_shifts[i, e]
        if t === :end #not supported because to_px does not give pixels in 3D space (would need to map 3D coordinates to pixels...?)
            error("`arrow_shift = :end` not supported for 3D plots.")
        end
        arrow_shift[j] = t
    end

    return arrow_shift
end

function find_start_end_shift(g, edge_paths::Vector{<:AbstractPath{<:Point3}}, node_pos, to_px,
                              node_markers,
                              node_sizes, node_outsets, edge_outsets, arrow_markers, arrow_shifts, arrow_sizes,
                              arrow_orientation, arrow_show)
    shifts = Vector{Tuple{Float32,Float32}}(undef, ne(g))
    for (i, e) in enumerate(edges(g))
        start_node_outset = node_outsets[src(e)]
        end_node_outset = node_outsets[dst(e)]
        !isnothing(start_node_outset) && start_node_outset != 0.0 && error("`node_outset != 0.0` not supported for 3D plots.")
        !isnothing(end_node_outset) && end_node_outset != 0.0 && error("`node_outset != 0.0` not supported for 3D plots.")

        edge_outset = edge_outsets[i, e]
        start_edge_outset = edge_outset[1]
        end_edge_outset = edge_outset[2]
        (!isnothing(start_edge_outset) && start_edge_outset != 0.0) && error("`edge_outset != (0.0, 0.0)` not supported for 3D plots.")
        (!isnothing(end_edge_outset) && end_edge_outset != 0.0) && error("`edge_outset != (0.0, 0.0)` not supported for 3D plots.")

        shifts[i] = (0.0, 1.0)
    end
    return shifts
end

sum_if_not_nothing(a, b) = isnothing(a) ? b : isnothing(b) ? a : a + b

function find_start_end_shift(g, edge_paths::Vector{<:AbstractPath{PT}}, node_pos, to_px, node_markers,
                              node_sizes, node_outsets, edge_outsets, arrow_markers, arrow_shifts, arrow_sizes,
                              arrow_orientations, arrow_show) where {PT}
    shifts = Vector{Tuple{Float32,Float32}}(undef, ne(g))

    for (i, e) in enumerate(edges(g))
        # find start shift
        edge_outset = edge_outsets[i, e]

        t = arrow_shifts[i, e]
        arrow_orientation = arrow_orientations[i, e]
        if !(arrow_orientation in (:forward, :reverse))
            throw(ArgumentError("Invalid arrow orientation $arrow_orientation for edge $e (id: $i)!"))
        end

        start_node_outset = node_outsets[src(e)]
        start_edge_outset = edge_outset[1]
        start_outset = sum_if_not_nothing(start_node_outset, start_edge_outset)

        start_shift = if !isnothing(start_outset) || (t === :end && arrow_orientation === :reverse)
            start_outset = isnothing(start_outset) ? 0.0 : start_outset

            j = src(e)
            p0 = node_pos[j]
            node_marker = node_markers[j]
            node_size = node_sizes[j]
            arrow_marker = arrow_markers[i, e]
            arrow_size = arrow_show[i, e] && t == :end && arrow_orientation === :reverse ? arrow_sizes[i, e] : 0
            d = distance_between_markers(node_marker, node_size, arrow_marker, arrow_size) + start_outset
            p1 = point_near_offset(edge_paths[i], p0, -d, to_px, 0)
            inverse_interpolate(edge_paths[i], p1, 0.0)
        else
            0.0
        end

        # find end shift
        end_node_outset = node_outsets[dst(e)]
        end_edge_outset = edge_outset[2]
        end_outset = sum_if_not_nothing(end_node_outset, end_edge_outset)

        end_shift = if !isnothing(end_outset) || (t === :end && arrow_orientation == :forward)
            end_outset = isnothing(end_outset) ? 0.0 : end_outset

            j = dst(e)
            p0 = node_pos[j]
            node_marker = node_markers[j]
            node_size = node_sizes[j]
            arrow_marker = arrow_markers[i, e]
            arrow_size = arrow_show[i, e] && t == :end && arrow_orientation === :forward ? arrow_sizes[i, e] : 0
            d = distance_between_markers(node_marker, node_size, arrow_marker, arrow_size) + end_outset
            p1 = point_near_offset(edge_paths[i], p0, d, to_px, 1)
            inverse_interpolate(edge_paths[i], p1, 1.0)
        else
            1.0
        end

        if isnan(start_shift)
            @warn """
                Shifting edge start to start-node edge failed.
                This can happen when the markers are inadequately scaled (e.g., when zooming out too far).
                Startpoint shift has been reset to 0.0.
            """
            start_shift = 0.0
        end

        if isnan(end_shift)
            @warn """
                Shifting edge end to destination-node edge failed.
                This can happen when the markers are inadequately scaled (e.g., when zooming out too far).
                Endpoint shift has been reset to 1.0.
            """
            end_shift = 1.0
        end


        if start_shift >= end_shift
            start_shift = end_shift = 0.5
        end

        shifts[i] = (start_shift, end_shift)
    end

    return shifts
end

function Makie.preferred_axis_type(plot::Plot{GraphMakie.graphplot})
    if haskey(plot.kw, :layout)
        layout = plot.kw[:layout]
        dim = _dimensionality(layout, plot[1][])
        dim == 3 && return LScene
        dim == 2 && return Axis
    end
    Axis
end

_dimensionality(obs::Observable, g) = _dimensionality(obs[], g)
_dimensionality(layout::AbstractLayout, _) = dim(layout)
_dimensionality(layout::AbstractArray, _) = length(first(layout))
_dimensionality(layout, g) = length(first(layout(g)))
