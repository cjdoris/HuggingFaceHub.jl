"""
    token(; [client])

Get the authentication token. Can return `nothing` if it is not set.
"""
function token(; client::Client=client())
    # already set
    token = client.token
    token !== nothing && return token
    # env var
    tok = get(ENV, "HUGGING_FACE_HUB_TOKEN", nothing)
    if tok !== nothing
        token = client.token = Token(tok)
        return token
    end
    # file
    file = token_file(; client)
    if file !== nothing
        if isfile(file)
            tok = read(file, String)
            token = client.token = Token(tok)
            return token
        end
    end
    # give up
    return nothing
end

token_dir() = Scratch.@get_scratch!("tokens")

"""
    token_file(; [client])

The path of the file where the token can be saved.
"""
function token_file(; client::Client=client())
    file = client.token_file
    if file === nothing
        return nothing
    elseif startswith(file, "@")
        return joinpath(token_dir(), file[2:end])
    elseif isabspath(file)
        return file
    else
        error("token_file must start with '@' or be an absolute path")
    end
end

function token_save(; client::Client=client())
    file = token_file(; client)
    file === nothing && error("token_file not set")
    tok = token(; client)
    mkpath(dirname(file))
    write(file, tok.value)
    return
end

"""
    token_set(token; [client], [save])

Set the authentication token.

Will automatically save the token for future re-use if `client.token_file` is set (it is
by default). This can be over-ridden with `save=false`.
"""
function token_set(token; client::Client=client(), save::Bool=client.token_file!==nothing)
    client.token = Token(token)
    save && token_save(; client)
    return
end

"""
    token_prompt(; [client], [save])

Set the authentication token by prompting for it in the REPL.

Will automatically save the token for future re-use if `client.token_file` is set (it is
by default). This can be over-ridden with `save=false`.
"""
function token_prompt(; kw...)
    buffer = Base.getpass("Token")
    token = read(buffer, String)
    Base.shred!(buffer)
    token_set(token; kw...)
    return
end
