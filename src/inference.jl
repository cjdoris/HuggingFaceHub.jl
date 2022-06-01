struct Undefined end

function _check_pipeline(m, t)
    m isa Model && m.pipeline_tag !== nothing && m.pipeline_tag != t && @warn "This model is for $(m.pipeline_tag) but you are using it for $t."
end

_validate_string_input(x) = x isa AbstractString ? String(x) : Undefined()

function _validate_qa_input(x)
    if x isa Tuple{Any,Any}
        q, c = x
    elseif x isa NamedTuple && length(x) == 2 && hasfield(typeof(x), :question) && hasfield(typeof(x), :context)
        q = x.question
        c = x.context
    else
        return Undefined()
    end
    return (question=String(q), context=String(c))
end

function _validate_inputs(validator, x)
    y = validator(x)
    if y !== Undefined()
        return ([y], Val(true))
    end
    if x isa AbstractVector
        z = [validator(x) for x in x]
        z = [z for z in z if z !== Undefined()]
        if length(z) == length(x)
            return (z, Val(false))
        end
    end
    error("invalid inputs")
end

_infer_output(x, ::Val{single}) where {single} = single ? only(x) : x

function _infer_json(::Type{R}, pipeline, model, inputs; client::Client=client(), input_validator=_validate_string_input, only_singleton=false, fix_singleton=false, use_gpu::Bool=false, use_cache::Bool=true, wait_for_model::Bool=true, kw...) where {R}
    @nospecialize kw
    _check_pipeline(model, pipeline)
    model_id = _repo_id(model)
    inputs, single = _validate_inputs(input_validator, inputs)
    if only_singleton
        single === Val(true) || error("$pipeline task only takes single inputs")
        inputs = only(inputs)
    end
    endpoint = "pipeline/$pipeline/$model_id"
    params = Dict{String,Any}(String(k)=>v for (k, v) in pairs(kw) if v !== Undefined())
    options = Dict{String,Any}("use_gpu"=>use_gpu, "use_cache"=>use_cache, "wait_for_model"=>wait_for_model)
    json = Dict{String,Any}("inputs"=>inputs, "parameters"=>params, "options"=>options)
    res = _api_request_json("POST", endpoint; json, inference=true)
    if only_singleton || (fix_singleton && length(inputs) == 1)
        res = [res]
    end
    res = convert(Vector{R}, res)::Vector{R}
    return _infer_output(res, single)
end

"""
    infer_fill_mask(inputs; [client], [model],
        # model parameters
        ...,
        # inference options
        [use_gpu], [use_cache], [wait_for_model],
    )

Call the Fill Mask Inference API with the given `inputs`.
"""
function infer_fill_mask(inputs; model="bert-base-uncased", kw...)
    return _infer_json(Vector{FillMaskResult}, "fill-mask", model, inputs; fix_singleton=true, kw...)
end

Base.@kwdef mutable struct FillMaskResult <: Object
    sequence::Union{String,Nothing} = nothing
    token_str::Union{String,Nothing} = nothing
    token::Union{Int,Nothing} = nothing
    score::Union{Float64,Nothing} = nothing
    raw::Any = nothing
end

_id_field(::FillMaskResult) = :sequence

"""
    infer_text_generation(inputs; [client], [model],
        # model parameters
        [top_k], [top_p], [temperature], [repetition_penalty], [max_new_tokens], [max_time],
        [return_full_text], [num_return_sequences], [do_sample], ...,
        # inference options
        [use_gpu], [use_cache], [wait_for_model],
    )

Call the Text Generation Inference API with the given `inputs`.
"""
function infer_text_generation(inputs; model="gpt2", kw...)
    return _infer_json(Vector{TextGenerationResult}, "text-generation", model, inputs; kw...)
end

"""
    infer_text2text_generation(inputs; [client], [model],
        # model parameters
        [top_k], [top_p], [temperature], [repetition_penalty], [max_new_tokens], [max_time],
        [return_full_text], [num_return_sequences], [do_sample], ...,
        # inference options
        [use_gpu], [use_cache], [wait_for_model],
    )

Call the Text2Text Generation Inference API with the given `inputs`.
"""
function infer_text2text_generation(inputs; model="google/mt5-base", kw...)
    return _infer_json(Vector{TextGenerationResult}, "text2text-generation", model, inputs; kw...)
end

Base.@kwdef mutable struct TextGenerationResult <: Object
    generated_text::Union{String,Nothing} = nothing
    raw::Any = nothing
end

_id_field(::TextGenerationResult) = :generated_text

"""
    infer_summarization(inputs; [client], [model],
        # model parameters
        [min_length], [max_length], [top_k], [top_p], [temperature], [repetition_penalty],
        [max_time], ...,
        # inference options
        [use_gpu], [use_cache], [wait_for_model],
    )

Call the Summarization Inference API with the given `inputs`.
"""
function infer_summarization(inputs; model="facebook/bart-large-cnn", kw...)
    return _infer_json(SummarizationResult, "summarization", model, inputs; kw...)
end

Base.@kwdef mutable struct SummarizationResult <: Object
    summary_text::Union{String,Nothing} = nothing
    raw::Any = nothing
end

_id_field(::SummarizationResult) = :summary_text

"""
    infer_text_classification(inputs; [client], [model],
        # model parameters
        ...,
        # inference options
        [use_gpu], [use_cache], [wait_for_model],
    )

Call the Text Classification Inference API with the given `inputs`.
"""
function infer_text_classification(inputs; model="distilbert-base-uncased-finetuned-sst-2-english", kw...)
    return _infer_json(Vector{ClassificationResult}, "text-classification", model, inputs; kw...)
end

Base.@kwdef mutable struct ClassificationResult <: Object
    label::Union{String,Nothing} = nothing
    score::Union{Float64,Nothing} = nothing
    raw::Any = nothing
end

"""
    infer_zero_shot_classification(inputs; [client], [model],
        # model parameters
        candidate_labels, [multi_label], ...
        # inference options
        [use_gpu], [use_cache], [wait_for_model],
    )

Call the Zero-Shot Classification Inference API with the given `inputs`.
"""
function infer_zero_shot_classification(inputs; model="facebook/bart-large-mnli", candidate_labels::AbstractVector, kw...)
    candidate_labels = collect(String, candidate_labels)
    return _infer_json(ZeroShotClassificationResult, "zero-shot-classification", model, inputs; candidate_labels, kw...)
end

Base.@kwdef mutable struct ZeroShotClassificationResult <: Object
    labels::Union{Vector{String},Nothing} = nothing
    scores::Union{Vector{Float64},Nothing} = nothing
    sequence::Union{String,Nothing} = nothing
    raw::Any = nothing
end

"""
    infer_token_classification(inputs; [client], [model],
        # model parameters
        [aggregation_strategy], ...,
        # inference options
        [use_gpu], [use_cache], [wait_for_model],
    )

Call the Token Classification Inference API with the given `inputs`.
"""
function infer_token_classification(inputs; model="dbmdz/bert-large-cased-finetuned-conll03-english", kw...)
    return _infer_json(Vector{TokenClassificationResult}, "token-classification", model, inputs; kw...)
end

Base.@kwdef mutable struct TokenClassificationResult <: Object
    entity_group::Union{String,Nothing} = nothing
    score::Union{Float64,Nothing} = nothing
    word::Union{String,Nothing} = nothing
    start::Union{Int,Nothing} = nothing
    var"end"::Union{Int,Nothing} = nothing
    raw::Any = nothing
end

_show_fields(::TokenClassificationResult) = (:word, :entity_group, :score)

"""
    infer_translation(inputs; [client], [model],
        # model parameters
        ...,
        # inference options
        [use_gpu], [use_cache], [wait_for_model],
    )

Call the Translation Inference API with the given `inputs`.
"""
function infer_translation(inputs; model="Helsinki-NLP/opus-mt-en-es", kw...)
    return _infer_json(TranslationResult, "translation", model, inputs; kw...)
end

Base.@kwdef mutable struct TranslationResult <: Object
    translation_text::Union{String,Nothing} = nothing
    raw::Any = nothing
end

_id_field(::TranslationResult) = :translation_text

"""
    infer_feature_extraction(inputs; [client], [model],
        # model parameters
        ...,
        # inference options
        [use_gpu], [use_cache], [wait_for_model],
    )

Call the Feature Extraction Inference API with the given `inputs`.
"""
function infer_feature_extraction(inputs; model="sentence-transformers/paraphrase-xlm-r-multilingual-v1", kw...)
    return _infer_json(Vector{Float64}, "feature-extraction", model, inputs; kw...)
end

"""
    infer_question_answering(inputs; [client], [model],
        # model parameters
        ...,
        # inference options
        [use_gpu], [use_cache], [wait_for_model],
    )

Call the Question Answering Inference API with the given `inputs`.
"""
function infer_question_answering(inputs; model="deepset/roberta-base-squad2", kw...)
    return _infer_json(QuestionAnsweringResult, "question-answering", model, inputs; input_validator=_validate_qa_input, only_singleton=true, kw...)
end

Base.@kwdef mutable struct QuestionAnsweringResult <: Object
    answer::Union{String,Nothing} = nothing
    score::Union{Float64,Nothing} = nothing
    start::Union{Int,Nothing} = nothing
    var"end"::Union{Int,Nothing} = nothing
    raw::Any = nothing
end

_id_field(::QuestionAnsweringResult) = :answer
_show_fields(::QuestionAnsweringResult) = (:answer, :score)

const INFER = Dict(
    "fill-mask" => infer_fill_mask,
    "text-generation" => infer_text_generation,
    "text2text-generation" => infer_text2text_generation,
    "summarization" => infer_summarization,
    "text-classification" => infer_text_classification,
    "zero-shot-classification" => infer_zero_shot_classification,
    "token-classification" => infer_token_classification,
    "translation" => infer_translation,
    "sentence-similarity" => infer_feature_extraction,
    "question-answering" => infer_question_answering,
)

"""
    infer(model, inputs; ...)

Convenience function to call one the following, depending on `model.pipeline_tag`:
- [`infer_text_generation`](@ref)
"""
function infer(model::Model, inputs; kw...)
    p = model.pipeline_tag
    if p === nothing
        error("no pipeline_tag")
    end
    f = get(INFER, p, nothing)
    if f === nothing
        error("unimplemented inference task: $p")
    end
    return f(inputs; model, kw...)
end
