module HuggingFaceHub

import Dates
import HTTP
import JSON3
import Scratch

include("client.jl")
include("token.jl")
include("rest.jl")
include("infer.jl")

function __init__()
    CLIENT[] = Client()
end

end # module
