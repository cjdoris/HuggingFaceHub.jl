module HuggingFaceHub

import HTTP
import JSON3
import Scratch

include("client.jl")
include("token.jl")
include("rest.jl")

function __init__()
    CLIENT[] = Client()
end

end # module
