# 🤗 HuggingFaceHub.jl

A Julia package to interact with the [Hugging Face Hub](https://huggingface.co/).

You can use it to inspect, download and update models, datasets and spaces, including
private ones.

## Install

```
pkg> add https://github.com/cjdoris/HuggingFaceHub.jl
```

## API

None of these functions are exported. You can import the module like
`import HuggingFaceHub as HF` to access the functions like `HF.models()`.

### Repositories

- `models` (search for models)
- `datasets` (search for datasets)
- `spaces` (search for spaces)
- `model` (get info about a model)
- `dataset` (get info about a dataset)
- `space` (get info about a space)
- `refresh` (return updated info for a repo)
- `model_create` (create a new model)
- `dataset_create` (create a new dataset)
- `space_create` (create a new space)
- `delete` (delete a repo)
- `update` (update metadata on a repo)
- `move` (move a repo)
- `file_upload` (upload a file to a repo)
- `file_delete` (delete a file from a repo)
- `file_open` (open a file from a repo)
- `file_read` (read a file from a repo)

### Metadata

- `model_tags` (dict of groups of model tags)
- `dataset_tags` (dict of groups of dataset tags)
- `metrics` (list of metrics)

### Users / Tokens

Some operations, such as modifying a repo or accessing a private repo, require you to
authenticate yourself using a token.

You can generate a token at [Hugging Face settings](https://huggingface.co/settings/tokens),
then copy it, call `token_prompt()` and paste the token. The token will be saved to disk so
you only need to do this once.

Alternatively you can set the token in the environment variable `HUGGING_FACE_HUB_TOKEN`.

- `whoami` (get info about the current user)
- `token` (get the current token)
- `token_set` (set the token)
- `token_prompt` (set the token from a prompt)
- `token_file` (the file where the token is saved)

### Clients

A client controls things like the URL of the Hugging Face REST API and the token to
authenticate with.

There is a global default client, which is suitable for most users. But you may also create
new clients and pass them as the `client` keyword argument to most other functions.

- `client` (get the default client)
- `Client` (construct a new client)

### Inference API

Refer to [the Hugging Face documentation](https://huggingface.co/docs/api-inference/detailed_parameters)
for details about the inputs and parameters to these functions.

- `infer` (convenience function to select one of the below functions automatically)
- `infer_fill_mask` (Fill Mask inference)
- `infer_text_generation` (Text Generation inference)
- `infer_text2text_generation` (Text2Text Generation inference)
- `infer_summarization` (Summarization inference)
- `infer_text_classification` (Text Classification inference)
- `infer_zero_shot_classification` (Zero-Shot Classification inference)
- `infer_token_classification` (Token Classification inference)
- `infer_translation` (Translation inference)
- `infer_feature_extraction` (Feature Extraction inference)
- `infer_question_answering` (Question Answering inference)
- `infer_generic` (generic inference with no pre- or post-processing)
