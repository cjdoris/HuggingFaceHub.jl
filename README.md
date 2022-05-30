# 🤗 HuggingFaceHub.jl

A Julia package to interact with the [Hugging Face Hub](https://huggingface.co/).

You can use it to inspect, download and update models, datasets and spaces, including
private ones.

## Install

```
pkg> add https://github.com/cjdoris/HuggingFaceHub.jl
```

## API

### Models

- `models`
- `model`
- `model_tags`
- `model_create`
- `model_delete`
- `model_update`
- `model_move`
- `model_files`
- `model_file_upload`
- `model_file_delete`
- `model_file_open`
- `model_file_read`

### Datasets

- `datasets`
- `dataset`
- `dataset_tags`
- `dataset_create`
- `dataset_delete`
- `dataset_update`
- `dataset_move`
- `dataset_files`
- `dataset_file_upload`
- `dataset_file_delete`
- `dataset_file_open`
- `dataset_file_read`

### Spaces

- `spaces`
- `space`
- `space_create`
- `space_delete`
- `space_update`
- `space_move`
- `space_files`
- `space_file_upload`
- `space_file_delete`
- `space_file_open`
- `space_file_read`

### Metrics

- `metrics`

### Users / Tokens

Some operations, such as modifying a repo or accessing a private repo, require you to
authenticate yourself using a token.

You can generate a token at [Hugging Face settings](https://huggingface.co/settings/tokens),
then copy it, call `token_prompt()` and paste the token. The token will be saved to
`~/.huggingface/token` so you only need to do this once.

- `whoami`
- `token`
- `token_set`
- `token_prompt`

### Clients

A client controls things like the URL of the Hugging Face REST API and the token to
authenticate with.

There is a global default client, which is suitable for most users. But you may also create
new clients and pass them as the `client` keyword argument to most other functions.

- `client`
- `Client`
