struct APIError <: Exception
    status::Int
    msg::String
end

abstract type Object end

Base.convert(::Type{T}, x::JSON3.Object) where {T<:Object} = _from_json(T, x)

_to_json(x::AbstractDict) = Dict{String,Any}(String(k)=>_to_json(v) for (k,v) in x)
_to_json(x::AbstractVector) = Any[_to_json(x) for x in x]
_to_json(x::Union{Real,AbstractString,Nothing}) = x

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

function _api_default_handler(res)
    if res.status >= 300
        msg = try
            JSON3.read(res.body)["error"]::String
        catch
            String(res.body)
        end
        throw(APIError(res.status, msg))
    end
    return res
end

function _api_request(method, endpoint; headers=[], json=nothing, body="", client=client(), handler=_api_default_handler, inference=false, kw...)
    tok = token(; client)
    headers = collect(Pair{String,String}, headers)
    if tok !== nothing
        headers = push!(headers, "Authorization" => "Bearer $(tok.value)")
    end
    if json !== nothing
        body = JSON3.write(json)
        push!(headers, "Content-Type" => "application/json")
    end
    base = inference ? client.inference_api_url : client.api_url
    url = "$base/$endpoint"
    res = HTTP.request(method, url, headers, body; kw..., status_exception=false)
    return handler(res)
end

_api_request_json(args...; kw...) = JSON3.read(_api_request(args...; kw...).body)

function _api_query(; kw...)
    query = Pair{String,String}[]
    for (k, v) in pairs(kw)
        if v === nothing
            # pass
        elseif k in (:search, :author, :filter, :sort)
            if v isa AbstractString
                push!(query, string(k) => convert(String, v))
            else
                error("$k must be a string")
            end
        elseif k in (:direction, :limit)
            if v isa Integer
                push!(query, string(k) => string(convert(Int, v)))
            else
                error("$k must be an integer")
            end
        elseif k in (:full, :config)
            if v isa Bool
                if v
                    push!(query, string(k) => "true")
                end
            else
                error("$k must be true or false")
            end
        else
            @assert false
        end
    end
    return query
end

function _api_json(; kw...)
    json = Dict{String,Any}()
    for (k, v) in pairs(kw)
        if v === nothing
            # pass
        elseif k in (:organization, :name, :type, :sdk, :fromRepo, :toRepo)
            if v isa AbstractString
                json[string(k)] = convert(String, v)
            else
                error("$k must be a string")
            end
        elseif k in (:private,)
            if v isa Bool
                json[string(k)] = v
            else
                error("$k must be true or false")
            end
        else
            @assert false
        end
    end
    return json
end

function repos(::Type{T}; search=nothing, author=nothing, filter=nothing, sort=nothing, direction=nothing, limit=nothing, full=nothing, config=nothing, client::Client=client()) where {T<:AbstractRepo}
    query = _api_query(; search, author, filter, sort, direction, limit, full, config)
    res = _api_request_json("GET", "api/$(_repo_types(T))"; query, client)
    return T[_from_json(T, x) for x in res]
end

"""
    models(; [client], [search], [author], [filter], [sort], [direction], [limit], [full], [config])

A list of models.
"""
models(; kw...) = repos(Model; kw...)

"""
    datasets(; [client], [search], [author], [filter], [sort], [direction], [limit], [full], [config])

A list of datasets.
"""
datasets(; kw...) = repos(Dataset; kw...)

"""
    spaces(; [client], [search], [author], [filter], [sort], [direction], [limit], [full], [config])

A list of spaces.
"""
spaces(; kw...) = repos(Space; kw...)

function repo(::Type{T}, src; revision::Union{AbstractString,Nothing}=nothing, client::Client=client(), latest::Bool=true) where {T<:AbstractRepo}
    if src isa T
        id = src.id !== nothing ? src.id : error("no id")
        sha = revision !== nothing ? revision : (!latest && src.sha !== nothing) ? src.sha : src.revision
        revision = revision !== nothing ? revision : src.revision
    elseif src isa AbstractString
        id = src
        sha = revision
    else
        error("expecting a String (the ID) or a $T")
    end
    endpoint = "api/$(_repo_types(T))/$id"
    if sha !== nothing
        endpoint *= "/revision/$sha"
    end
    res = _api_request_json("GET", endpoint; client)
    ans = _from_json(T, res)
    ans.revision = revision
    return ans
end

"""
    model(id; [client], [revision])

The model with the given `id`.
"""
model(id; kw...) = repo(Model, id; kw...)

"""
    dataset(id; [client], [revision])

The dataset with the given `id`.
"""
dataset(id; kw...) = repo(Dataset, id; kw...)

"""
    space(id; [client], [revision])

The space with the given `id`.
"""
space(id; kw...) = repo(Space, id; kw...)

"""
    refresh(repo; [client], [revision], [latest])

An updated copy of the given `repo`.

If `revision` is not given, then by default the latest commit on `repo.revision` is
returned. Set `latest=false` to instead return the same commit as `repo`.
"""
refresh(repo::AbstractRepo; kw...) = repo(typeof(repo), repo; kw...)

function repo_tags(::Type{T}; client::Client=client()) where {T<:AbstractRepo}
    Tag = _tag_type(T)
    res = _api_request_json("GET", "api/$(_repo_types(T))-tags-by-type"; client)
    return Dict{String,Vector{Tag}}(String(k) => Tag[_from_json(Tag, v) for v in v] for (k, v) in res)
end

"""
    model_tags(; [client])

A dict mapping tag group names to lists of tags for models.
"""
model_tags(; kw...) = repo_tags(Model; kw...)

"""
    dataset_tags(; [client])

A dict mapping tag group names to lists of tags for datasets.
"""
dataset_tags(; kw...) = repo_tags(Dataset; kw...)

"""
    metrics(; [client])

List all metrics.
"""
function metrics(; client::Client=client())
    res = _api_request_json("GET", "api/metrics"; client)
    return Metric[_from_json(Metric, x) for x in res]
end

_repo_id(x::AbstractString) = x
_repo_id(x::Nothing) = error("id missing")
_repo_id(x::AbstractRepo) = _repo_id(x.id)

_repo_revision(x::AbstractString) = x
_repo_revision(x::Nothing) = error("revision missing")
_repo_revision(x::AbstractRepo) = _repo_revision(x.revision)

_repo_sha(x::AbstractString) = x
_repo_sha(x::Nothing) = error("revision (sha) missing")
_repo_sha(x::AbstractRepo) = _repo_sha(x.sha)

function _split_repo_id(id::AbstractString)
    parts = split(_repo_id(id), '/')
    if length(parts) == 2
        return (parts[1], parts[2])
    else
        error("id must contain exactly one '/'")
    end
end

function create(::Type{T}, id::AbstractString; client::Client=client(), private=false, sdk=nothing, exist_ok=false) where {T<:AbstractRepo}
    organization, name = _split_repo_id(id)
    type = _repo_type(T)
    json = _api_json(; name, organization, type, private, sdk)
    if exist_ok
        handler = res -> res.status == 409 ? res : _api_default_handler(res)
        _api_request("POST", "api/repos/create"; client, json, handler)
    else
        _api_request("POST", "api/repos/create"; client, json)
    end
    return
end

"""
    dataset_create(id; [client], [private], [exist_ok])

Create a new dataset with the given `id`, of the form `<username>/<reponame>`.
"""
dataset_create(id; kw...) = create(Dataset, id; kw...)

"""
    model_create(id; [client], [private], [exist_ok])

Create a new model with the given `id`, of the form `<username>/<reponame>`.
"""
model_create(id; kw...) = create(Model, id; kw...)

"""
    space_create(id; [client], [private], [exist_ok], [sdk])

Create a new space with the given `id`, of the form `<username>/<reponame>`.
"""
space_create(id; kw...) = create(Space, id; kw...)

"""
    delete(repo; [client])

Delete the given `repo`.
"""
function delete(repo::AbstractRepo; client::Client=client())
    organization, name = _split_repo_id(repo.id)
    type = _repo_type(repo)
    json = _api_json(; name, organization, type)
    _api_request("DELETE", "api/repos/delete"; client, json)
    return
end

"""
    update(repo; [client], [private])

Update metadata on the given `repo`.

Currently, you may only update the `private` setting.
"""
function update(repo::AbstractRepo; client::Client=client(), private::Union{Bool,Nothing}=nothing)
    id = _repo_id(repo)
    json = _api_json(; private)
    prefix = _repo_prefix(repo)
    endpoint = "api/$prefix$id/settings"
    _api_request("PUT", endpoint; client, json)
    return
end

"""
    move(repo, dest; [client])

Move the given `repo` to `dest`.
"""
function move(repo::AbstractRepo, toRepo::AbstractString; client::Client=client())
    fromRepo = _repo_id(repo)
    type = _repo_type(repo)
    json = _api_json(; fromRepo, toRepo, type)
    _api_request("POST", "api/repos/move"; client, json)
    return
end

"""
    file_upload(repo, path, file; [client], [revision])

Upload the given `file` to `path` in `repo`.

The `file` may be a readable IO stream or a filename.
"""
function file_upload(repo::AbstractRepo, path::AbstractString, file::IO; client::Client=client(), revision::AbstractString=_repo_revision(repo))
    revision === nothing && error("revision missing")
    id = _repo_id(repo)
    prefix = _repo_prefix(repo)
    endpoint = "api/$prefix$id/upload/$revision/$path"
    _api_request("POST", endpoint; client, body=file)
    return
end

function file_upload(repo::AbstractRepo, path::AbstractString, file::AbstractString; kw...)
    open(file) do io
        repo_file_upload(repo, path, io; kw...)
    end
end

"""
    file_delete(repo, path; [client], [revision])

Delete the file `path` from the given `repo`.
"""
function file_delete(repo::AbstractRepo, path::AbstractString; client::Client=client(), revision::AbstractString=_repo_revision(repo))
    id = _repo_id(repo)
    prefix = _repo_prefix(repo)
    endpoint = "api/$prefix$id/delete/$revision/$path"
    _api_request("DELETE", endpoint; client)
    return
end

"""
    file_open(func, repo, path; [client], [revision], [result_type])

Open the file `path` from the given `repo`, call `func` on the resulting IO stream and
return the result.

See also [`file_read`](@ref).
"""
function file_open(func::Function, repo::AbstractRepo, path::AbstractString; result_type::Type{T}=Any, client::Client=client(), revision::AbstractString=_repo_sha(repo)) where {T}
    id = _repo_id(repo)
    prefix = _repo_prefix(repo)
    url = "$(client.api_url)/$prefix$id/resolve/$revision/$path"
    headers = []
    tok = token(; client)
    if tok !== nothing
        push!(headers, "Authorization" => "Bearer $(tok.value)")
    end
    if T == Nothing
        res = HTTP.open(func, "GET", url, headers; status_exception=false)
        _api_default_handler(res)
        return
    else
        ans = Ref{T}()
        res = HTTP.open(io->(ans[]=func(io)), "GET", url, headers; status_exception=false)
        _api_default_handler(res)
        return ans[]
    end
end

"""
    file_read(repo, path, [T]; [client], [revision])

Read the file `path` from the given `repo`.

Returns a `Vector{UInt8}` by default, but can read a string by passing `T=String`.

See also [`file_open`](@ref).
"""
file_read(repo::AbstractRepo, path; kw...) = file_open(read, repo, path; result_type=Vector{UInt8}, kw...)
file_read(repo::AbstractRepo, path, ::Type{T}; kw...) where {T} = file_open(io->read(io, T), repo, path; result_type=T, kw...)

"""
    whoami(; [client])

Information about the current Hugging Face Hub user.
"""
function whoami(; client=client())
    res = _api_request_json("GET", "api/whoami-v2"; client)
    return _from_json(User, res)
end
