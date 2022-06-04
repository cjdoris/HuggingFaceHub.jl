struct APIError <: Exception
    status::Int
    msg::String
end

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

"""
    search(repotype; [client],
        # filters
        [search], [author], [filter],
        # sorting
        [sort], [direction], [limit],
        # include extra details
        [full=false], [config=false],
    )

Search for repos of the given type (e.g. `Model` or `Dataset`).

The results typically only have a few pieces of information about each repo. For more
details, you can pass results of interest through [`info`](@ref).
"""
function search(::Type{T};
    search::Union{AbstractString,Nothing}=nothing,
    author::Union{AbstractString,Nothing}=nothing,
    filter::Union{AbstractString,Nothing}=nothing,
    sort::Union{AbstractString,Nothing}=nothing,
    direction::Union{Integer,Nothing}=nothing,
    limit::Union{Integer,Nothing}=nothing,
    full::Bool=false,
    config::Bool=false,
    client::Client=client(),
) where {T<:AbstractRepo}
    query = Pair{String,Any}[]
    search !== nothing && push!(query, "search" => convert(String, search))
    author !== nothing && push!(query, "author" => convert(String, author))
    filter !== nothing && push!(query, "filter" => convert(String, filter))
    sort !== nothing && push!(query, "sort" => convert(String, sort))
    direction !== nothing && push!(query, "direction" => string(convert(Int, direction)))
    limit !== nothing && push!(query, "limit" => string(convert(Int, limit)))
    full && push!(query, "full" => "true")
    config && push!(query, "config" => "true")
    res = _api_request_json("GET", "api/$(_repo_types(T))"; query, client)
    return T[_from_json(T, x) for x in res]
end

"""
    info(repo; [client], [refresh=false])
    info(repotype, id; [revision], ...)

Information about the given `repo`.

By default, this returns information at exactly the same commit as `repo`. Pass
`refresh=true` to get information about the latest commit on the given revision.
"""
function info(repo::AbstractRepo; client::Client=client(), refresh::Bool=false)
    id = _repo_id(repo)
    revision = @something(repo.revision, "main")
    commit = @something(refresh ? nothing : repo.sha, revision)
    endpoint = "api/$(_repo_types(repo))/$id/revision/$commit"
    res = _api_request_json("GET", endpoint; client)
    ans = _from_json(typeof(repo), res)
    ans.revision = revision
    return ans
end
function info(::Type{T}, id::AbstractString; revision::Union{AbstractString,Nothing}=nothing, kw...) where {T<:AbstractRepo}
    return info(T(; id, revision); kw...)
end

"""
    tags(repotype; [client])

A dict mapping tag group names to lists of tags for repos of the given type (e.g. `Model` or
`Dataset`).
"""
function tags(::Type{T}; client::Client=client()) where {T<:AbstractRepo}
    Tag = _tag_type(T)
    res = _api_request_json("GET", "api/$(_repo_types(T))-tags-by-type"; client)
    return Dict{String,Vector{Tag}}(String(k) => Tag[_from_json(Tag, v) for v in v] for (k, v) in res)
end

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
_repo_id(x::AbstractRepo) = @something(x.id, error("id missing"))

_repo_revision(x::AbstractString) = x
_repo_revision(x::Nothing) = error("revision missing")
_repo_revision(x::AbstractRepo) = @something(x.revision, error("revision missing"))

_repo_sha(x::AbstractString) = x
_repo_sha(x::Nothing) = error("revision sha missing")
_repo_sha(x::AbstractRepo) = @something(x.sha, error("revision sha missing"))

function _split_repo_id(id::AbstractString)
    parts = split(id, '/')
    if length(parts) == 2
        return (parts[1], parts[2])
    else
        error("id must contain exactly one '/'")
    end
end

"""
    create(repo; [client], [exist_ok=false])
    create(repotype, id; ...)

Create the given `repo`.
"""
function create(repo::AbstractRepo; client::Client=client(), exist_ok::Bool=false)
    id = _repo_id(repo)
    organization, name = _split_repo_id(id)
    type = _repo_type(repo)
    private = repo.private
    sdk = hasproperty(repo, :sdk) ? repo.sdk : nothing
    json = _api_json(; name, organization, type, private, sdk)
    if exist_ok
        handler = res -> res.status == 409 ? res : _api_default_handler(res)
        _api_request("POST", "api/repos/create"; client, json, handler)
    else
        _api_request("POST", "api/repos/create"; client, json)
    end
    return
end
function create(::Type{T}, id::AbstractString; kw...) where {T<:AbstractRepo}
    return create(T(; id); kw...)
end


"""
    delete(repo; [client])
    delete(repotype, id; ...)

Delete the given `repo`.
"""
function delete(repo::AbstractRepo; client::Client=client())
    organization, name = _split_repo_id(repo.id)
    type = _repo_type(repo)
    json = _api_json(; name, organization, type)
    _api_request("DELETE", "api/repos/delete"; client, json)
    return
end
function delete(::Type{T}, id::AbstractString; kw...) where {T<:AbstractRepo}
    return delete(T(; id); kw...)
end

"""
    update(repo; [client], [private])
    update(repotype, id; ...)

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
function update(::Type{T}, id::AbstractString; kw...) where {T<:AbstractRepo}
    return update(T(; id); kw...)
end

"""
    move(repo, dest; [client])
    move(repotype, id, dest; ...)

Move the given `repo` to `dest`.
"""
function move(repo::AbstractRepo, toRepo::AbstractString; client::Client=client())
    fromRepo = _repo_id(repo)
    type = _repo_type(repo)
    json = _api_json(; fromRepo, toRepo, type)
    _api_request("POST", "api/repos/move"; client, json)
    return
end
function move(::Type{T}, id::AbstractString, toRepo::AbstractString; kw...) where {T<:AbstractRepo}
    return move(T(; id), toRepo; kw...)
end

"""
    whoami(; [client])

Information about the current Hugging Face Hub user.
"""
function whoami(; client=client())
    res = _api_request_json("GET", "api/whoami-v2"; client)
    return _from_json(User, res)
end
