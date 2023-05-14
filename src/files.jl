"""
    file_upload(repo, path, file; [client])

Upload the given `file` to `path` in `repo`.

The `file` may be a readable IO stream or a filename.
"""
function file_upload(repo::AbstractRepo, path::AbstractString, file::IO; client::Client=client())
    type = _repo_type(repo)
    id = _repo_id(repo)
    revision = _repo_revision(repo)
    prefix = _repo_prefix(repo)
    endpoint = "api/$(type)s/$prefix$id/upload/$revision/$path"
    _api_request("POST", endpoint; client, body=file)
    return
end

function file_upload(repo::AbstractRepo, path::AbstractString, file::AbstractString; kw...)
    open(file) do io
        file_upload(repo, path, io; kw...)
    end
end

"""
    file_delete(repo, path; [client])

Delete the file `path` from the given `repo`.
"""
function file_delete(repo::AbstractRepo, path::AbstractString; client::Client=client())
    id = _repo_id(repo)
    revision = _repo_revision(repo)
    prefix = _repo_prefix(repo)
    endpoint = "api/$prefix$id/delete/$revision/$path"
    _api_request("DELETE", endpoint; client)
    return
end

file_cache_dir() = Scratch.@get_scratch!("cache")

const REGEX_COMMIT_HASH = r"^[0-9a-f]{40}$"

"""
    file_download(repo, path; [client], [progress])

Download a file from a repo to a local cache. Return the path to the local file.

The `progress` argument is as for the `Downloads.download` function, namely it is called
periodically like `progress(total, now)` where `total` is the total size of the download (or
`0` if unknown) and `now` is the amount downloaded so far.

On Windows, this function may raise an error when trying to create symlinks. If so, you need
to enable Developer Mode or run with Administrator privileges.
"""
function file_download(repo::AbstractRepo, path::AbstractString; client::Client=client(), progress=nothing)
    # TODO: we should probably put file locks around a lot of this
    id = _repo_id(repo)
    revision = repo.revision
    sha = repo.sha
    locpath = joinpath(split(path, "/"))

    # if revision is a commit hash, use that for sha
    if revision !== nothing && occursin(REGEX_COMMIT_HASH, revision)
        if sha === nothing
            sha = revision
        else
            sha == revision || error("repo.revision is a commit hash, but is different from repo.sha")
        end
    end

    # the cache dir for the repo
    repodir = joinpath(file_cache_dir(), _repo_types(repo), replace(id, "/"=>"--"))

    # look up sha in refs, or save sha to refs
    if sha === nothing
        if revision === nothing
            revision = "main"
        end
        refpath = joinpath(repodir, "refs", revision)
        if isfile(refpath)
            sha = read(refpath, String)
        end
    elseif revision !== nothing
        refpath = joinpath(repodir, "refs", revision)
        mkpath(dirname(refpath))
        write(refpath, sha)
    end

    # see if the file is already in the cache
    if sha !== nothing
        ans = joinpath(repodir, "snapshots", sha, locpath)
        if isfile(ans)
            return ans
        end
    end

    # If we get to here, then either we don't know the sha for the given revision
    # or we know the sha but don't have the file already in the cache.

    # HEAD request to get the commit sha and etag
    prefix = _repo_prefix(repo)
    url = "$(client.api_url)/$prefix$id/resolve/$(@something(sha, revision))/$path"
    headers = []
    tok = token(; client)
    if tok !== nothing
        push!(headers, "Authorization" => "Bearer $(tok.value)")
    end
    res0 = HTTP.request("HEAD", url; headers, redirect=false)

    # get or check the commit sha
    sha0 = HTTP.header(res0, "X-Repo-Commit")
    if sha0 == ""
        error("X-Repo-Commit header missing")
    elseif sha === nothing
        sha = sha0
        # save the ref
        if revision !== nothing
            refpath = joinpath(repodir, "refs", revision)
            mkpath(dirname(refpath))
            write(refpath, sha)
        end
    elseif sha != sha0
        error("X-Repo-Commit header is $(repr(sha0)) but requested $(repr(sha))")
    end

    # get the etag
    etag = convert(String, HTTP.header(res0, "X-Linked-Etag"))
    if etag == ""
        etag = HTTP.header(res0, "ETag")
        if etag == ""
            error("ETag header missing")
        end
    end
    if startswith(etag, '"') && endswith(etag, '"')
        etag = strip(etag, '"')
    else
        error("ETag header is invalid, got $(repr(etag))")
    end

    # get the redirected url
    if 300 ≤ res0.status < 400
        url = convert(String, HTTP.header(res0, "Location"))
        if url == ""
            error("Location header missing")
        end
    end

    # the path to the blob
    blobpath = joinpath(repodir, "blobs", etag)

    # if the blob doesn't already exist, we need to download it
    if !isfile(blobpath)
        tmpblobpath = "$blobpath.downloading"
        mkpath(dirname(blobpath))
        Downloads.download(url, tmpblobpath; method="GET", headers, progress)
        mv(tmpblobpath, blobpath)
    end
    @assert isfile(blobpath)

    # the path to the snapshot
    ans = joinpath(repodir, "snapshots", sha, locpath)

    # if the snapshot doesn't exist, create it
    if !isfile(ans)
        mkpath(dirname(ans))
        symlink(relpath(blobpath, dirname(ans)), ans)
    end

    return ans
end


# """
#     file_open(func, repo, path; [client], [revision], [result_type])

# Open the file `path` from the given `repo`, call `func` on the resulting IO stream and
# return the result.

# See also [`file_read`](@ref).
# """
# function file_open(func::Function, repo::AbstractRepo, path::AbstractString; result_type::Type{T}=Any, client::Client=client(), revision::AbstractString=_repo_sha(repo)) where {T}
#     id = _repo_id(repo)
#     prefix = _repo_prefix(repo)
#     url = "$(client.api_url)/$prefix$id/resolve/$revision/$path"
#     headers = []
#     tok = token(; client)
#     if tok !== nothing
#         push!(headers, "Authorization" => "Bearer $(tok.value)")
#     end
#     if T == Nothing
#         res = HTTP.open(func, "GET", url, headers; status_exception=false)
#         _api_default_handler(res)
#         return
#     else
#         ans = Ref{T}()
#         res = HTTP.open(io->(ans[]=func(io)), "GET", url, headers; status_exception=false)
#         _api_default_handler(res)
#         return ans[]
#     end
# end

# """
#     file_read(repo, path, [T]; [client], [revision])

# Read the file `path` from the given `repo`.

# Returns a `Vector{UInt8}` by default, but can read a string by passing `T=String`.

# See also [`file_open`](@ref).
# """
# file_read(repo::AbstractRepo, path; kw...) = file_open(read, repo, path; result_type=Vector{UInt8}, kw...)
# file_read(repo::AbstractRepo, path, ::Type{T}; kw...) where {T} = file_open(io->read(io, T), repo, path; result_type=T, kw...)
