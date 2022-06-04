# 🤗 HuggingFaceHub.jl

A Julia package to interact with the [Hugging Face Hub](https://huggingface.co/).

- Search for repos (models, datasets and spaces).
- Get repo metadata.
- Download and upload files.
- Supports private repos.
- Call the Inference API to easily make model predictions.

## Install

```
pkg> add https://github.com/cjdoris/HuggingFaceHub.jl
```

## API

None of these functions are exported. You can import the module like
`import HuggingFaceHub as HF` to access the functions like `HF.models()`.

Read the docstrings for more information about each function.

### Repositories

- `Model()`: type representing a model
- `Dataset()`: type representing a dataset
- `Space()`: type representing a space
- `search(repotype)`: search for repos of the given type
- `info(repo)` or `info(repotype, id)`: information about a repo
- `create(repo)` or `create(repotype, id)`: create a new repo
- `delete(repo)` or `delete(repotype, id)`: delete a repo
- `update(repo)` or `update(repotype, id)`: update metadata on a repo
- `move(repo, dest)` or `move(repotype, id, dest)`: move a repo

### Other Metadata

- `tags(repotype)`: dict of groups of tags
- `metrics()`: list of metrics

### Files

- `file_download(repo, path)`: download a file from a repo
- `file_upload(repo, path, file)`: upload a file to a repo
- `file_delete(repo, path)`: delete a file from a repo

### Users / Tokens

Some operations, such as modifying a repo or accessing a private repo, require you to
authenticate yourself using a token.

You can generate a token at [Hugging Face settings](https://huggingface.co/settings/tokens),
then copy it, call `token_prompt()` and paste the token. The token will be saved to disk so
you only need to do this once.

Alternatively you can set the token in the environment variable `HUGGING_FACE_HUB_TOKEN`.

- `whoami()`: get info about the current user
- `token()`: get the current token
- `token_set(token)`: set the token
- `token_prompt()`: set the token from a prompt
- `token_file()`: the file where the token is saved

### Clients

A client controls things like the URL of the Hugging Face REST API and the token to
authenticate with.

There is a global default client, which is suitable for most users. But you may also create
new clients and pass them as the `client` keyword argument to most other functions.

- `client()`: get the default client
- `Client()`: construct a new client

### Inference API

Refer to [the Inference API documentation](https://huggingface.co/docs/api-inference/detailed_parameters)
for details about inputs and parameters.

- `infer(model, inputs)`: call the Inference API, return the inference results
