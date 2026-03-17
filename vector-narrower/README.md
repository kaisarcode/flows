# vector-narrower - Vector Content Narrower

> **Note:** This application is in the development and testing phase, is not ready for production use, and may change without prior notice.

`vector-narrower` builds vectorized text stores from source text and matches natural language queries against those stores. It uses n-gram segmentation, embedding generation, persisted text/vector records, and score-based selection to narrow candidate content from a larger text space.

## Usage

### Pack

Take line-by-line source text and build a persisted vector store:

```bash
printf "The history of Rome\nCooking pasta" \
  | ./bin/vector-narrower pack \
      --store /tmp/vnw.store \
      --model ./etc/bge-small.gguf \
      --dim 384
```

### Match

Query an existing vector store using natural language:

```bash
echo "How to cook italian food" \
  | ./bin/vector-narrower match \
      --store /tmp/vnw.store \
      --model ./etc/bge-small.gguf \
      --dim 384 \
      --threshold 0.7
```

### Match using explicit descriptors

```bash
exec 3<<<"roman empire history"

./bin/vector-narrower match \
    --fd-in 3 \
    --store /tmp/vnw.store \
    --model ./etc/bge-small.gguf \
    --dim 384 \
    --threshold 0.7
```

## Parameter Reference

| Flag | Description | Default |
| :--- | :--- | :--- |
| `--store` | Path to the persisted vector store. | `NULL` |
| `--map` | Alias for `--store`. | `NULL` |
| `--model` | Path to the embedding model. | `NULL` |
| `--emb-socket` | Optional embedding daemon socket. | `NULL` |
| `--dim` | Embedding dimension. | `384` |
| `--min-tokens` | Minimum n-gram token count. | implementation-defined |
| `--max-tokens` | Maximum n-gram token count. | implementation-defined |
| `--threshold` | Minimum selection threshold for `match`. | implementation-defined |
| `--select-mode` | Selection strategy for `match`. | implementation-defined |
| `--score-mode` | Scoring strategy for `match`. | implementation-defined |
| `--fd-in` | Input descriptor. | `stdin` |
| `--fd-out` | Output descriptor. | `stdout` |
| `--help` | Show help and usage. | `false` |

## Internal Architecture

`vector-narrower` is launched through:

- `bin/vector-narrower`

Its current flow layout is:

- `src/flow/pack.flow`
- `src/flow/match.flow`
- `src/flow/vector-narrower.flow`
- `src/flow/internal/embed.flow`
- `src/flow/internal/store-write.flow`
- `src/flow/internal/store-read.flow`
- `src/flow/internal/query-segment.flow`
- `src/flow/internal/score-select.flow`

Helper scripts under `src/bin/` implement fd-oriented atomic operations used by the flow layer.

## Install

Install through the surrounding flows/tooling environment required by this repository.

## Build

No standalone package build step is required beyond the repository runtime/tooling used by `kc-flow`.

## Testing

```bash
./test.sh
```

---

**Author:** KaisarCode

**Email:** kaisar@kaisarcode.com

**Website:** https://kaisarcode.com

**License:** GNU GPL v3.0

© 2026 KaisarCode