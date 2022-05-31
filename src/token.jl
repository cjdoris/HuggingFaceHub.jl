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

function token_set(token; client::Client=client(), save::Bool=client.token_file!==nothing)
    client.token = Token(token)
    save && token_save(; client)
    return
end

function token_prompt(; kw...)
    buffer = Base.getpass("Token")
    token = read(buffer, String)
    Base.shred!(buffer)
    token_set(token; kw...)
    return
end
