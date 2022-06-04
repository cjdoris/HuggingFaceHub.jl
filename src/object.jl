abstract type Object end

Base.convert(::Type{T}, x::JSON3.Object) where {T<:Object} = _from_json(T, x)

function _to_json(x; tight::Bool=false)
    @nospecialize x
    if x isa Union{Real,AbstractString,Nothing}
        return x
    elseif x isa AbstractVector
        if tight
            return [_to_json(x; tight) for x in x]
        else
            return Any[_to_json(x; tight) for x in x]
        end
    elseif x isa AbstractDict
        if tight
            ks = sort([String(k) for k in keys(x)])
            ns = Tuple(Symbol[Symbol(k) for k in ks])
            vs = Tuple(Any[_to_json(x[k]; tight) for k in ks])
            NamedTuple{ns}(vs)
        else
            return Dict{String,Any}(String(k) => _to_json(v; tight) for (k, v) in x)
        end
    else
        error("expecting nothing, number, string, vector or dict, got $(typeof(x))")
    end
end

_id_field(x::Object) = hasfield(typeof(x), :id) ? :id : nothing
_show_fields(x::Object) = _id_field(x) === nothing ? fieldnames(typeof(x)) : (_id_field(x),)

function _from_json(::Type{T}, x) where {T<:Object}
    ans = T()
    ans.raw = x
    dict = Dict{Symbol,Any}(x)
    for (k, v) in dict
        if hasfield(T, k)
            if k == :lastModified
                v2 = Dates.DateTime(rstrip(v::String, 'Z'))
            elseif k == :siblings
                v2 = RepoFile[_from_json(RepoFile, x) for x in v]
            elseif k in (:config, :cardData, :transformersInfo)
                v2 = _to_json(v)
            elseif k in (:tags, :labels)
                v2 = collect(String, v)
            elseif k == :scores
                v2 = collect(Float64, v)
            elseif k in (:files, :raw)
                continue
            else
                v2 = v
            end
            setfield!(ans, k, v2)
        end
    end
    _from_json_post(ans)
    return ans
end

_from_json_post(x::Object) = return

function Base.show(io::IO, x::Object)
    k = _id_field(x)
    if k !== nothing && get(io, :typeinfo, Any) == typeof(x)
        show(io, getfield(x, k))
    else
        show(io, typeof(x))
        print(io, "(")
        first = true
        for k in _show_fields(x)
            k == :raw && continue
            first || print(io, ", ")
            first = false
            show(io, getfield(x, k))
        end
        print(io, ", ...)")
    end
    return
end

function Base.show(io::IO, ::MIME"text/plain", x::Object)
    show(io, typeof(x))
    print(io, ":")
    blank = true
    for k in fieldnames(typeof(x))
        k in (:raw, :siblings) && continue
        blank = false
        v = getfield(x, k)
        v === nothing && continue
        println(io)
        print(io, "  ", k, " = ")
        show(io, v)
    end
    blank && print(io, " (blank)")
    return
end

abstract type AbstractRepo <: Object end

_repo_type(T::Type) = error("not implemented")
_repo_types(T::Type) = "$(_repo_type(T))s"
_repo_prefix(T::Type) = "$(_repo_types(T))/"

_repo_type(x) = _repo_type(typeof(x))
_repo_types(x) = _repo_types(typeof(x))
_repo_prefix(x) = _repo_prefix(typeof(x))

function _from_json_post(x::AbstractRepo)
    sibs = x.siblings
    if sibs !== nothing
        x.files = String[x.rfilename for x in sibs]
    end
    return
end

_show_fields(::AbstractRepo) = (:id, :sha)

Base.@kwdef mutable struct RepoFile <: Object
    rfilename::Union{String,Nothing} = nothing
    raw::Any = nothing
end

_id_field(::RepoFile) = :rfilename

Base.@kwdef mutable struct Model <: AbstractRepo
    id::Union{String,Nothing} = nothing
    sha::Union{String,Nothing} = nothing
    author::Union{String,Nothing} = nothing
    revision::Union{String,Nothing} = nothing
    lastModified::Union{Dates.DateTime,Nothing} = nothing
    private::Union{Bool,Nothing} = nothing
    files::Union{Vector{String},Nothing} = nothing
    siblings::Union{Vector{RepoFile},Nothing} = nothing
    pipeline_tag::Union{String,Nothing} = nothing
    tags::Union{Vector{String},Nothing} = nothing
    downloads::Union{Int,Nothing} = nothing
    library_name::Union{String,Nothing} = nothing
    mask_token::Union{String,Nothing} = nothing
    likes::Union{Int,Nothing} = nothing
    config::Any = nothing  # TODO: ::Config ?
    cardData::Any = nothing  # TODO: ::CardData ?
    transformersInfo::Any = nothing  # TODO: ::TransformersInfo ?
    raw::Any = nothing
end

_repo_type(::Type{Model}) = "model"
_repo_prefix(::Type{Model}) = ""

Base.@kwdef mutable struct Dataset <: AbstractRepo
    id::Union{String,Nothing} = nothing
    sha::Union{String,Nothing} = nothing
    author::Union{String,Nothing} = nothing
    revision::Union{String,Nothing} = nothing
    lastModified::Union{Dates.DateTime,Nothing} = nothing
    private::Union{Bool,Nothing} = nothing
    files::Union{Vector{String},Nothing} = nothing
    siblings::Union{Vector{RepoFile},Nothing} = nothing
    tags::Union{Vector{String},Nothing} = nothing
    gated::Union{Bool,Nothing} = nothing
    raw::Any = nothing
end

_repo_type(::Type{Dataset}) = "dataset"

Base.@kwdef mutable struct Space <: AbstractRepo
    id::Union{String,Nothing} = nothing
    sha::Union{String,Nothing} = nothing
    author::Union{String,Nothing} = nothing
    revision::Union{String,Nothing} = nothing
    lastModified::Union{Dates.DateTime,Nothing} = nothing
    private::Union{Bool,Nothing} = nothing
    files::Union{Vector{String},Nothing} = nothing
    siblings::Union{Vector{RepoFile},Nothing} = nothing
    tags::Union{Vector{String},Nothing} = nothing
    sdk::Union{String,Nothing} = nothing
    cardData::Any = nothing
    gated::Union{Bool,Nothing} = nothing
    raw::Any = nothing
end

_repo_type(::Type{Space}) = "space"

abstract type AbstractRepoTag <: Object end

Base.@kwdef mutable struct ModelTag <: AbstractRepoTag
    id::Union{String,Nothing} = nothing
    label::Union{String,Nothing} = nothing
    type::Union{String,Nothing} = nothing
    raw::Any = nothing
end

_tag_type(::Type{Model}) = ModelTag

Base.@kwdef mutable struct DatasetTag <: AbstractRepoTag
    id::Union{String,Nothing} = nothing
    label::Union{String,Nothing} = nothing
    type::Union{String,Nothing} = nothing
    raw::Any = nothing
end

_tag_type(::Type{Dataset}) = DatasetTag

Base.@kwdef mutable struct Metric <: Object
    id::Union{String,Nothing} = nothing
    citation::Union{String,Nothing} = nothing
    description::Union{String,Nothing} = nothing
    key::Union{String,Nothing} = nothing
    raw::Any = nothing
end

Base.@kwdef mutable struct User <: Object
    name::Union{String,Nothing} = nothing
    fullname::Union{String,Nothing} = nothing
    email::Union{String,Nothing} = nothing
    emailVerified::Union{Bool,Nothing} = nothing
    plan::Union{String,Nothing} = nothing
    raw::Any = nothing
end

_id_field(::User) = :name
