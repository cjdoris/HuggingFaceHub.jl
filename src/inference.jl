"""
    infer(model, inputs; [client], [pipeline], [use_gpu], [use_cache], [wait_for_model], params...)

Call the Hugging Face Inference API on the given `model` and `inputs`.

See [the Inference API documentation](https://huggingface.co/docs/api-inference/detailed_parameters)
for details about inputs and parameters.
"""
function infer(model::Union{Model,AbstractString}, inputs; pipeline::Union{Nothing,AbstractString}=nothing, client::Client=client(), use_gpu::Bool=false, use_cache::Bool=true, wait_for_model::Bool=true, kw...)
    @nospecialize kw
    model_id = _repo_id(model)
    endpoint = pipeline === nothing ? "models/$model_id" : "pipeline/$pipeline/$model_id"
    params = Dict{String,Any}(String(k)=>v for (k, v) in pairs(kw))
    options = Dict{String,Any}("use_gpu"=>use_gpu, "use_cache"=>use_cache, "wait_for_model"=>wait_for_model)
    json = Dict{String,Any}("inputs"=>inputs, "parameters"=>params, "options"=>options)
    res = _api_request_json("POST", endpoint; json, inference=true)
    return _to_json(res; tight=true)
end
