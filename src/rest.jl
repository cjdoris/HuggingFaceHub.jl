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

function _api_request(method, endpoint; headers=[], json=nothing, payload="", client=client(), handler=_api_default_handler, kw...)
    tok = token(; client)
    headers = collect(Pair{String,String}, headers)
    if tok !== nothing
        headers = push!(headers, "Authorization" => "Bearer $(tok.value)")
    end
    if json !== nothing
        payload = JSON3.write(json)
        push!(headers, "Content-Type" => "application/json")
    end
    url = "$(client.api_url)/$endpoint"
    res = HTTP.request(method, url, headers, payload; kw..., status_exception=false)
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

function repos(type; search=nothing, author=nothing, filter=nothing, sort=nothing, direction=nothing, limit=nothing, full=nothing, config=nothing, client=client())
    query = _api_query(; search, author, filter, sort, direction, limit, full, config)
    return _api_request_json("GET", "api/$(type)s"; query, client)
end

models(; kw...) = repos("model"; kw...)
datasets(; kw...) = repos("dataset"; kw...)
spaces(; kw...) = repos("space"; kw...)

function repo(type, id; revision=nothing, client=client())
    endpoint = "api/$(type)s/$id"
    if revision !== nothing
        endpoint *= "/revision/$revision"
    end
    return _api_request_json("GET", endpoint; client)
end

model(id; kw...) = repo("model", id; kw...)
dataset(id; kw...) = repo("dataset", id; kw...)
space(id; kw...) = repo("space", id; kw...)

function model_tags(; client=client())
    return _api_request_json("GET", "api/models-tags-by-type"; client)
end

function dataset_tags(; client=client())
    return _api_request_json("GET", "api/datasets-tags-by-type"; client)
end

function metrics(; client=client())
    return _api_request_json("GET", "api/metrics"; client)
end

function _split_repo_id(id)
    parts = split(id, '/')
    if length(parts) == 2
        return (parts[1], parts[2])
    else
        error("id must contain exactly one '/'")
    end
end

function repo_create(type, id; client=client(), private=false, sdk=nothing, exist_ok=false)
    organization, name = _split_repo_id(id)
    json = _api_json(; name, organization, type, private, sdk)
    if exist_ok
        handler = res -> res.status == 409 ? res : _api_default_handler(res)
        return _api_request_json("POST", "api/repos/create"; client, json, handler)
    else
        return _api_request_json("POST", "api/repos/create"; client, json)
    end
end

dataset_create(id; kw...) = repo_create("dataset", id; kw...)
model_create(id; kw...) = repo_create("model", id; kw...)
space_create(id; kw...) = repo_create("space", id; kw...)

function repo_delete(type, id; client=client())
    organization, name = _split_repo_id(id)
    json = _api_json(; name, organization, type)
    _api_request("DELETE", "api/repos/delete"; client, json)
    return
end

dataset_delete(id; kw...) = repo_delete("dataset", id; kw...)
model_delete(id; kw...) = repo_delete("model", id; kw...)
space_delete(id; kw...) = repo_delete("space", id; kw...)

function repo_update(type, id; client=client(), private=nothing)
    json = _api_json(; private)
    prefix = type == "model" ? "" : "$(type)s/"
    endpoint = "api/$prefix$id/settings"
    return _api_request_json("PUT", endpoint; client, json)
end

dataset_update(id; kw...) = repo_update("dataset", id; kw...)
model_update(id; kw...) = repo_update("model", id; kw...)
space_update(id; kw...) = repo_update("space", id; kw...)

function repo_move(type, fromRepo, toRepo; client=client())
    json = _api_json(; fromRepo, toRepo, type)
    _api_request("POST", "api/repos/move"; client, json)
    return
end

dataset_move(a, b; kw...) = repo_move("dataset", a, b; kw...)
model_move(a, b; kw...) = repo_move("model", a, b; kw...)
space_move(a, b; kw...) = repo_move("space", a, b; kw...)

function repo_file_upload(type, id, path, file::IO; client=client(), revision="main")
    prefix = type == "model" ? "" : "$(type)s/"
    endpoint = "api/$prefix$id/upload/$revision/$path"
    return _api_request_json("POST", endpoint; client, payload=file)
end

function repo_file_upload(type, id, path, file::AbstractString; kw...)
    open(file) do
        repo_file_upload(type, id, path, io; kw...)
    end
end

dataset_file_upload(id, path, file; kw...) = repo_file_upload("dataset", id, path, file; kw...)
model_file_upload(id, path, file; kw...) = repo_file_upload("model", id, path, file; kw...)
space_file_upload(id, path, file; kw...) = repo_file_upload("space", id, path, file; kw...)

function repo_file_delete(type, id, path; client=client(), revision="main")
    prefix = type == "model" ? "" : "$(type)s/"
    endpoint = "api/$prefix$id/delete/$revision/$path"
    _api_request("DELETE", endpoint; client)
    return
end

dataset_file_delete(id, path; kw...) = repo_file_delete("dataset", id, path; kw...)
model_file_delete(id, path; kw...) = repo_file_delete("model", id, path; kw...)
space_file_delete(id, path; kw...) = repo_file_delete("space", id, path; kw...)

function repo_files(type, id; kw...)
    return String[x["rfilename"] for x in repo(type, id; kw...)["siblings"]]
end

dataset_files(id; kw...) = repo_files("dataset", id; kw...)
model_files(id; kw...) = repo_files("model", id; kw...)
space_files(id; kw...) = repo_files("space", id; kw...)

function repo_file_open(func::Function, type, id, path; result_type::Type{T}=Any, client=client(), revision="main") where {T}
    prefix = type == "model" ? "" : "$(type)s/"
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

dataset_file_open(func, id, path; kw...) = repo_file_open(func, "dataset", id, path; kw...)
model_file_open(func, id, path; kw...) = repo_file_open(func, "model", id, path; kw...)
space_file_open(func, id, path; kw...) = repo_file_open(func, "space", id, path; kw...)

repo_file_read(type, id, path; kw...) = repo_file_open(read, type, id, path; result_type=Vector{UInt8}, kw...)
repo_file_read(type, id, path, ::Type{T}; kw...) where {T} = repo_file_open(io->read(io, T), type, id, path; result_type=T, kw...)

dataset_file_read(args...; kw...) = repo_file_read("dataset", args...; kw...)
model_file_read(args...; kw...) = repo_file_read("model", args...; kw...)
space_file_read(args...; kw...) = repo_file_read("space", args...; kw...)

function whoami(; client=client())
    return _api_request_json("GET", "api/whoami-v2"; client)
end
