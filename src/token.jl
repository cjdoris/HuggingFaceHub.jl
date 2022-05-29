function token(; client::Client=client())
    # already set
    token = client.token
    token !== nothing && return token
    # env var
    token_env = client.token_env
    if token_env !== nothing
        tok = get(ENV, token_env, nothing)
        if tok !== nothing
            token = client.token = Token(tok)
            return token
        end
    end
    # file
    token_file = client.token_file
    if token_file !== nothing
        if isfile(token_file)
            tok = read(token_file, String)
            token = client.token = Token(tok)
            return token
        end
    end
    # give up
    return nothing
end

function token_save(; client::Client=client())
    file = client.token_file
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

# function token_header!(headers, token)
#     if token !== nothing
#         push!(headers, "Authorization" => "Bearer $token")
#     end
#     return headers
# end
