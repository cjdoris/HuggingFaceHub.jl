struct Token
    value::String
end
Token(token::Token) = token

function Base.show(io::IO, x::Token)
    show(io, typeof(x))
    print(io, "(\"*****\")")
end

mutable struct Client
    token::Union{Token,Nothing}
    token_file::Union{String,Nothing}
    api_url::String
    function Client(;
        token_file = "@default",
        token = nothing,
        api_url = "https://huggingface.co",
    )
        return new(token, token_file, api_url)
    end
end

const CLIENT = Ref(Client())

client() = CLIENT[]
