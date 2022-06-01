struct Token
    value::String
end
Token(token::Token) = token

function Base.show(io::IO, x::Token)
    show(io, typeof(x))
    print(io, "(\"*****\")")
end

"""
    Client(;
        token = nothing,
        token_file = "@default",
        api_url = "https://huggingface.co",
        inference_api_url = "https://api-inference.huggingface.co",
    )

Construct a new client.

You can pass this as the `client` argument to most functions instead of using the default
client.

- `token`: The token to use when authenticating. If not given, it will be looked up from
  the `HUGGING_FACE_HUB_TOKEN` environment variable or the `token_file`.
- `token_file`: The file where the token is cached. It must either be an absolute path or
  be of the form `@name`, in which case it is stored in a scratch space which the Julia
  package manager can delete when this package is uninstalled (see `token_file(; client)`
  for the exact location).
- `api_url`: The base URL of the Hugging Face Hub API.
- `inference_api_url`: The base URL of the Hugging Face Inference API.
"""
mutable struct Client
    token::Union{Token,Nothing}
    token_file::Union{String,Nothing}
    api_url::String
    inference_api_url::String
    function Client(;
        token_file = "@default",
        token = nothing,
        api_url = "https://huggingface.co",
        inference_api_url = "https://api-inference.huggingface.co",
    )
        return new(token, token_file, api_url, inference_api_url)
    end
end

const CLIENT = Ref(Client())

"""
    client()

Return the default client.
"""
client() = CLIENT[]
