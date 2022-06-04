# 🤗 HuggingFaceHub.jl

A Julia package to interact with the [Hugging Face Hub](https://huggingface.co/).

- Search for repos (models, datasets and spaces).
- Get repo metadata.
- Download and upload files.
- Supports private repos.
- Call the Inference API to easily make model predictions.

## Install

```julia-repl
pkg> add https://github.com/cjdoris/HuggingFaceHub.jl
```

## Tutorial

HuggingFaceHub does not export any functions, so it is convenient to import it as `HF`.

```julia
import HuggingFaceHub as HF
```

Here we search for models called 'distilbert', taking the top 5 by number of downloads.

```julia
HF.search(HF.Model, search="distilbert", sort="downloads", direction=-1, limit=5)
```
```
5-element Vector{HuggingFaceHub.Model}:
 "distilbert-base-uncased-finetuned-sst-2-english"
 "distilbert-base-uncased"
 "distilbert-base-multilingual-cased"
 "distilbert-base-cased-distilled-squad"
 "sentence-transformers/msmarco-distilbert-base-v4"
```

Now we select a single model from the list, which displays some more information.

```julia
model = ans[2]
```
```
HuggingFaceHub.Model:
  id = "distilbert-base-uncased"
  private = false
  pipeline_tag = "fill-mask"
```

Models returned from searching do not contain much information. The `info` function gets all
the information.

```julia
model = HF.info(model)
```
```
HuggingFaceHub.Model:
  id = "distilbert-base-uncased"
  sha = "043235d6088ecd3dd5fb5ca3592b6913fd516027"
  revision = "main"
  lastModified = Dates.DateTime("2022-05-31T19:08:36")
  private = false
  files = [".gitattributes", "LICENSE", "README.md", "config.json", "flax_model.msgpack", "pytorch_model.bin", "rust_model.ot", "tf_model.h5", "tokenizer.json", "tokenizer_config.json", "vocab.txt"]
  pipeline_tag = "fill-mask"
  tags = ["pytorch", "tf", "jax", "rust", "distilbert", "fill-mask", "en", "dataset:bookcorpus", "dataset:wikipedia", "arxiv:1910.01108", "transformers", "exbert", "license:apache-2.0", "autotrain_compatible", "infinity_compatible"]
  downloads = 7214355
  library_name = "transformers"
  mask_token = "[MASK]"
  likes = 64
  config = Dict{String, Any}("model_type" => "distilbert", "architectures" => Any["DistilBertForMaskedLM"])
  cardData = Dict{String, Any}("language" => "en", "tags" => Any["exbert"], "license" => "apache-2.0", "datasets" => Any["bookcorpus", "wikipedia"])
  transformersInfo = Dict{String, Any}("pipeline_tag" => "fill-mask", "processor" => "AutoTokenizer", "auto_model" => "AutoModelForMaskedLM")
```

We see in `model.files` that there is a `config.json` file. Let's download it and take a
look.

```julia
HF.file_download(model, "config.json") |> read |> String |> print
```
```
{
  "activation": "gelu",
  "architectures": [
    "DistilBertForMaskedLM"
  ],
  "attention_dropout": 0.1,
  "dim": 768,
  "dropout": 0.1,
  "hidden_dim": 3072,
  "initializer_range": 0.02,
  "max_position_embeddings": 512,
  "model_type": "distilbert",
  "n_heads": 12,
  "n_layers": 6,
  "pad_token_id": 0,
  "qa_dropout": 0.1,
  "seq_classif_dropout": 0.2,
  "sinusoidal_pos_embds": false,
  "tie_weights_": true,
  "transformers_version": "4.10.0.dev0",
  "vocab_size": 30522
}
```

Now let's use the Hugging Face Inference API to make some predictions. We see from
`model.pipeline_tag` that this model is for the Fill Mask task, and we see from
`model.mask_token` that `[MASK]` is the mask token.

If this step doesn't work, you probably need to authenticate yourself. See the Tokens
section below.

```julia
HF.infer(model, "The meaning of life is [MASK].")
```
```
5-element Vector{NamedTuple{(:score, :sequence, :token, :token_str), Tuple{Float64, String, Int64, String}}}:
 (score = 0.3163859248161316, sequence = "the meaning of life is unknown.", token = 4242, token_str = "unknown")
 (score = 0.07957715541124344, sequence = "the meaning of life is unclear.", token = 10599, token_str = "unclear")
 (score = 0.03341785818338394, sequence = "the meaning of life is uncertain.", token = 9662, token_str = "uncertain")
 (score = 0.03218647092580795, sequence = "the meaning of life is ambiguous.", token = 20080, token_str = "ambiguous")
 (score = 0.02055794931948185, sequence = "the meaning of life is simple.", token = 3722, token_str = "simple")
```

## API

Read the docstrings for more information about each function.

### Repositories

- `Model()`: Type representing a model.
- `Dataset()`: Type representing a dataset.
- `Space()`: Type representing a space.
- `search(repotype)`: Search for repos of the given type.
- `info(repo)` or `info(repotype, id)`: Information about a repo.
- `create(repo)` or `create(repotype, id)`: Create a new repo.
- `delete(repo)` or `delete(repotype, id)`: Delete a repo.
- `update(repo)` or `update(repotype, id)`: Update metadata on a repo.
- `move(repo, dest)` or `move(repotype, id, dest)`: Move a repo.

### Other Metadata

- `tags(repotype)`: Dict of groups of tags.
- `metrics()`: List of metrics.

### Files

- `file_download(repo, path)`: Download a file from a repo, return its local path.
- `file_upload(repo, path, file)`: Upload a file to a repo.
- `file_delete(repo, path)`: Delete a file from a repo.

### Users / Tokens

Some operations, such as modifying a repo or accessing a private repo, require you to
authenticate yourself using a token.

You can generate a token at [Hugging Face settings](https://huggingface.co/settings/tokens),
then copy it, call `token_prompt()` and paste the token. The token will be saved to disk so
you only need to do this once.

Alternatively you can set the token in the environment variable `HUGGING_FACE_HUB_TOKEN`.

- `whoami()`: Get info about the current user.
- `token()`: Get the current token.
- `token_set(token)`: Set the token.
- `token_prompt()`: Set the token from a prompt.
- `token_file()`: The file where the token is saved.

### Clients

A client controls things like the URL of the Hugging Face REST API and the token to
authenticate with.

There is a global default client, which is suitable for most users. But you may also create
new clients and pass them as the `client` keyword argument to most other functions.

- `client()`: Get the default client.
- `Client()`: Construct a new client.

### Inference API

Refer to [the Inference API documentation](https://huggingface.co/docs/api-inference/detailed_parameters)
for details about inputs and parameters.

- `infer(model, inputs)`: Call the Inference API, return the inference results.
