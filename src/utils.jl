export get_edge_plot, get_arrow_plot, get_node_plot, get_nlabel_plot, get_elabel_plot
export PerNodeAttribute, PerEdgeAttribute, nodes_with_values

"Get the `EdgePlot` subplot from a `GraphPlot`."
get_edge_plot(gp::GraphPlot) = gp.edge_plot[]

"Get the scatter plot of the arrow heads from a `GraphPlot`."
get_arrow_plot(gp::GraphPlot) = gp.arrow_plot[]

"Get the scatter plot of the nodes from a `GraphPlot`."
get_node_plot(gp::GraphPlot) = gp.node_plot[]

"Get the text plot of the node labels from a `GraphPlot`."
get_nlabel_plot(gp::GraphPlot) = haskey(gp.attributes, :nlabels_plot) ? gp[:nlabels_plot][] : nothing
"Get the text plot of the edge labels from a `GraphPlot`."
get_elabel_plot(gp::GraphPlot) = haskey(gp.attributes, :elabels_plot) ? gp[:elabels_plot][] : nothing

"""
    getedgekeys(gr::G, edgedat::D) where {G<:AbstractGraph, K<:AbstractEdge, D<:AbstractDict{K}, IsDirected{G}}

Return enumeration of edges for directed graph
"""
@traitfn function getedgekeys(gr::G, edgedat::D) where {G<:AbstractGraph, K<:AbstractEdge, D<:AbstractDict{K}; IsDirected{G}}
    return edges(gr)
end

"""
    getedgekeys(gr::G, edgedat::D) where {G<:AbstractGraph, K<:AbstractEdge, D<:AbstractDict{K}, IsDirected{G}}

Return enumeration of edges for undirected graph such that the user's keys are used

# Extended help
Wraps the `edges()` method such that the edges are referenced as the user defined them in the dictionary.
"""
@traitfn function getedgekeys(gr::G, edgedat::D) where {G<:AbstractGraph, K<:AbstractEdge, D<:AbstractDict{K}; !IsDirected{G}}
    Iterators.map(e -> reverse(e) ∈ keys(edgedat) ? reverse(e) : e , edges(gr))
end

"""
    getedgekeys(gr::AbstractGraph, <:AbstractDict{AbstractEdge})

Return enumeration of edge indices
"""
getedgekeys(gr::AbstractGraph, _) = 1:ne(gr)

"""
    getattr(o::Observable, idx, default=nothing)

If observable wraps an AbstractVector or AbstractDict return
the value at idx. If dict has no key idx returns default.
Else return the one and only element.
"""
getattr(o::Union{Observable,Makie.Computed}, idx, default=nothing) = getattr(o[], idx, default)

"""
    getattr(x, idx, default=nothing)

If `x` wraps an AbstractVector or AbstractDict return
the value at idx. If dict has no key idx return default.
Else return the one and only element.
"""
function getattr(x, idx, default=nothing)
    if x isa AbstractVector && !isa(x, Point)
        return x[idx]
    elseif x isa DefaultDict || x isa DefaultOrderedDict
        return getindex(x, idx)
    elseif x isa AbstractDict
        return get(x, idx, default)
    else
        return x === nothing ? default : x
    end
end

"""
    PerNodeAttribute(value, default=nothing)

Wrap a node attribute so it can be accessed uniformly by node id.

`value` may be a scalar, a vector indexed by node id, or a dict-like object
indexed by node id. Missing dict entries fall back to `default`, except for
`DefaultDict` and `DefaultOrderedDict`, which provide their own fallback.
"""
struct PerNodeAttribute{T,D}
    value::T
    default::D
end

UnstablePerNodeAttribute(pna::PerNodeAttribute) = Ref{PerNodeAttribute}(pna)
UnstablePerNodeAttribute(value) = UnstablePerNodeAttribute(PerNodeAttribute(value))
UnstablePerNodeAttribute(value,default) = UnstablePerNodeAttribute(PerNodeAttribute(value, default))

PerNodeAttribute(value) = PerNodeAttribute(value, nothing)

is_scalar_nothing(attr) = issingleattribute(attr.value) && isnothing(attr.value)

Base.getindex(attr::PerNodeAttribute, node) = _per_node_getindex(attr.value, node, attr.default)
function Base.getindex(attr::PerNodeAttribute, nodes::AbstractVector)
    if issingleattribute(attr.value)
        attr.value
    else
        [_per_node_getindex(attr.value, i, attr.default) for i in nodes]
    end
end

function Base.get(attr::PerNodeAttribute, node, default)
    if attr.value isa AbstractDict && !(attr.value isa Union{DefaultDict, DefaultOrderedDict})
        return get(attr.value, node, default)
    else
        return attr[node]
    end
end

function _per_node_getindex(value, node, default)
    if value isa AbstractVector && !isa(value, Point)
        return value[node]
    elseif value isa DefaultDict || value isa DefaultOrderedDict
        return value[node]
    elseif value isa AbstractDict
        return get(value, node, default)
    else
        return value
    end
end

"""
    nodes_with_values(attr::PerNodeAttribute, graph)

Return the vertices whose attribute value is not `nothing`.
"""
nodes_with_values(attr::PerNodeAttribute, graph::AbstractGraph) = filter(i->attr[i] !== nothing, vertices(graph))


"""
    PerEdgeAttribute(value, default=nothing)

Wrap an edge attribute so it can be accessed uniformly by edge id or edge key.

The first type parameter stores the supported index type:
- `Int` for scalars, vectors, and dicts indexed by edge id
- the concrete edge key type for dicts indexed by `AbstractEdge`
"""
struct PerEdgeAttribute{E,T,D}
    value::T
    default::D
end

PerEdgeAttribute(value) = PerEdgeAttribute(value, nothing)

function PerEdgeAttribute(value, default)
    E = per_edge_index_type(value)
    return PerEdgeAttribute{E, typeof(value), typeof(default)}(value, default)
end

UnstablePerEdgeAttribute(pea::PerEdgeAttribute) = Ref{PerEdgeAttribute}(pea)
UnstablePerEdgeAttribute(value) = UnstablePerEdgeAttribute(PerEdgeAttribute(value))
UnstablePerEdgeAttribute(value,default) = UnstablePerEdgeAttribute(PerEdgeAttribute(value,default))


per_edge_index_type(value) = Int
per_edge_index_type(value::AbstractVector) = Int
per_edge_index_type(value::AbstractDict) = per_edge_index_type(keytype(value))

per_edge_index_type(::Type{K}) where {K<:Integer} = Int
per_edge_index_type(::Type{K}) where {K<:AbstractEdge} = K
function per_edge_index_type(::Type{K}) where {K}
    throw(ArgumentError("PerEdgeAttribute dict keys must be edge ids or AbstractEdge values, got $K."))
end

Base.getindex(attr::PerEdgeAttribute{Int}, edge_id::Integer) =
    _per_edge_getindex(attr.value, edge_id, attr.default)

Base.getindex(attr::PerEdgeAttribute{Int}, edge_id::Integer, edge::AbstractEdge) = attr[edge_id]

Base.getindex(attr::PerEdgeAttribute{<:AbstractEdge}, edge_id::Integer, edge::AbstractEdge) =
    _per_edge_getindex(attr.value, edge, attr.default)

function _per_edge_getindex(value, index, default)
    if value isa AbstractVector && !isa(value, Point)
        return value[index]
    elseif value isa DefaultDict || value isa DefaultOrderedDict
        return value[index]
    elseif value isa AbstractDict
        return get(value, index, default)
    else
        return value
    end
end




"""
    prep_vertex_attributes(attr, graph::AbstractGraph, default_value)

Prepare the vertex attributes to be forwarded to the internal recipes.
If the attribute is a `Vector` or single value forward it as is (or the `default_value` if isnothing).
If it is an `AbstractDict` expand it to a `Vector` using vertex indices.
"""
function expand_vertex_attributes(attr, graph::AbstractGraph)
    if issingleattribute(attr.value)
        isnothing(attr.value) ? attr.default : attr.value
    elseif attr.value isa AbstractVector
        attr.value
    else
        [attr[i] for i in vertices(graph)]
    end
end

function expand_vertex_attributes(attr, vertex_ids)
    if issingleattribute(attr.value)
        isnothing(attr.value) ? attr.default : attr.value
    else
        [attr[i] for i in vertex_ids]
    end
end

"""
    expand_edge_attributes(attr::PerEdgeAttribute, graph::AbstractGraph)

Expands the edge attribute to be forwarded to the internal recipes.
If the attribute is a `Vector` or single value forward it as is (or the `default_value` if isnothing).
If it is an `AbstractDict` expand it to a `Vector` using edge indices.
"""
function expand_edge_attributes(attr, graph::AbstractGraph)
    if issingleattribute(attr.value)
        isnothing(attr.value) ? attr.default_value : attr.value
    elseif attr.value isa AbstractVector
        attr.value
    else
        [attr[i,e] for (i, e) in enumerate(edges(graph))]
    end
end

function expand_edge_attributes(attr, edge_ids)
    if issingleattribute(attr.value)
        isnothing(attr.value) ? attr.default : attr.value
    else
        [attr[i, e] for (i, e) in edge_ids]
    end
end

"""
    issingleattribute(x)

Return `true` if `x` represents a single attribute value
"""
issingleattribute(x) = isa(x, Point) || (!isa(x, AbstractVector) && !isa(x, AbstractDict))

"""
    to_pointf32(p::Point{N, T})

Convert Point{N, T} or NTuple{N, T} to Point{N, Float32}.
"""
to_pointf32(p::Union{Point{N,T}, NTuple{N,T}}) where {N,T} = Point{N, Float32}(p)
to_pointf32(p::StaticVector{N, T}) where {N,T} = Point{N, Float32}(p)
to_pointf32(p::Vararg{T,N}) where {N,T} = Point{N, Float32}(p)
to_pointf32(p::Vector{T}) where {T} = Point{length(p), Float32}(p)

"""
    align_to_dir(align::Tuple{Symbol, Symbol})

Given a tuple of alignment (i.e. `(:left, :bottom)`) return a normalized
2d vector which points in the direction of the offset.
"""
function align_to_dir(align::Tuple{Symbol, Symbol})
    halign, valign = align

    x = 0.0
    if halign === :left
        x = 1.0
    elseif halign === :right
        x = -1.0
    end

    y = 0.0
    if valign === :top
        y = -1.0
    elseif valign === :bottom
        y = 1.0
    end
    norm = x==y==0.0 ? 1 : sqrt(x^2 + y^2)
    return Point2f(x/norm, y/norm)
end

"""
    plot_controlpoints!(ax::Axis, gp::GraphPlot)
    plot_controlpoints!(ax::Axis, path::BezierPath)

Add all the bezier controlpoints of graph plot or a single
path to the axis `ax`.
"""
function plot_controlpoints!(ax::Axis, gp::GraphPlot)
    ep = get_edge_plot(gp)
    paths = ep[:paths][]

    for (i, p) in enumerate(paths)
        p isa Line && continue
        color = getattr(gp.edge_color, i)
        plot_controlpoints!(ax, p; color)
    end
end

function plot_controlpoints!(ax::Axis, p::BezierPath; color=:black)
    for (j, c) in enumerate(p.commands)
        if c isa CurveTo
            segs = [p.commands[j-1].p, c.c1, c.p, c.c2]
            linesegments!(ax, segs; color, linestyle=:dot)
            scatter!(ax, [c.c1, c.c2]; color)
        end
    end
end

"""
    scale_factor(marker)

Get base size (scaling) in pixels for `marker`.
"""
scale_factor(marker) = 1 #for 1x1 base sizes (Circle, Rect, Arrow)
function scale_factor(marker::Char)
    if marker == '➤'
        d = 0.675
    else
        d = 0.705 #set to the same value as :circle, but is really dependent on the Char
    end

    return d
end
function scale_factor(marker::Symbol)
    size_factor = 0.75 #Makie.default_marker_map() has all markers scaled by 0.75
    if marker == :circle #BezierCircle
        r = 0.47
    elseif marker in [:rect, :diamond, :vline, :hline] #BezierSquare
        rmarker = 0.95*sqrt(pi)/2/2
        r = sqrt(2*rmarker^2) #pithagoras to get radius of circle that circumscribes marker
    elseif marker in [:utriangle, :dtriangle, :ltriangle, :rtriangle] #Bezier Triangles
        r = 0.97/2
    elseif marker in [:star4, :star5, :star6, :star8] #Bezier Stars
        r = 0.6
    else #Bezier Crosses/Xs and Ngons
        r = 0.5
    end

    return 2*r*size_factor #get shape diameter
end

"""
    distance_between_markers(marker1, size1, marker2, size2)

Calculate distance between 2 markers.
TODO: Implement for noncircular marker1.
      (will require angle for line joining the 2 markers).

`size1` / `size2` may be scalars or `(width, height)` / `Vec2` marker sizes;
non-scalar sizes use `maximum` (larger axis / circumscribed extent).
"""
function distance_between_markers(marker1, size1, marker2, size2)
    marker1_scale = scale_factor(marker1)
    marker2_scale = scale_factor(marker2)
    d = marker1_scale * maximum(size1) / 2 +
        marker2_scale * maximum(size2) / 2

    return d
end

"""
    point_near_offset(edge_path, p0::PT, d, to_px, offset) where {PT}

Find point near the `offset ∈ [0, 1]` along `edge_path` a 
distance `d` pixels along the tangent line.
"""
function point_near_offset(edge_path, p0::PT, d, to_px, offset) where {PT}
    pt = tangent(edge_path, offset) #edge tangent along path
    r = to_px(pt) - to_px(PT(0)) #direction vector in pixels
    scale_px = 1 ./ (to_px(PT(1)) - to_px(PT(0)))
    p1 = p0 - d*normalize(r)*scale_px

    return p1
end
