function _infer(model, inputs; client=client(), use_gpu=false, use_cache=true, wait_for_model=false, kw...)
    model = _repo_id(model)
    endpoint = "models/$model"
    params = Dict(String(k)=>v for (k, v) in pairs(kw))
    options = Dict("use_gpu"=>use_gpu, "use_cache"=>use_cache, "wait_for_model"=>wait_for_model)
    json = Dict("inputs"=>inputs, "parameters"=>params, "options"=>options)
    return _api_request_json("POST", endpoint; json, inference=true)
end

Base.@kwdef mutable struct TextGenerationResult <: Object
    generated_text::Union{String,Nothing} = nothing
    raw::Any = nothing
end

_nlp_inputs(x::AbstractString) = (String[x], Val(true))
_nlp_inputs(x) = (collect(String, x), Val(false))

_nlp_output(x, ::Val{true}) = only(x)
_nlp_output(x, ::Val{false}) = x

function _convert(::Type{T}, @nospecialize(x)) where {T}
    convert(T, x)::T
end

function Base.show(io::IO, x::TextGenerationResult)
    if get(io, :typeinfo, Any) == typeof(x)
        show(io, x.generated_text)
    else
        show(io, typeof(x))
        print(io, "(")
        show(io, x.generated_text)
        print(io, ", ...)")
    end
end

function infer_text_generation(inputs; model="gpt2", kw...)
    inputs, single = _nlp_inputs(inputs)
    res = _infer(model, inputs; kw...)
    res = _convert(Vector{Vector{TextGenerationResult}}, res)
    return _nlp_output(res, single)
end

function infer(model::Model, inputs; kw...)
    p = model.pipeline_tag
    if p === nothing
        error("no pipeline_tag")
    elseif p == "text-generation"
        return infer_text_generation(inputs; model, kw...)
    else
        error("unimplemented pipeline: $p")
    end
end
