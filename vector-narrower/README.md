# vector-narrower - kc-flow module

> **Note:** This module is in the development and testing phase, is not ready
> for production use, and may change without prior notice.

`vector-narrower` is a reusable `kc-flow` module for vector narrowing
processes.

It keeps the same two real processes:

- `pack`: read source texts, generate embeddings, persist text + vector records
- `match`: segment a query, embed each unit, read the store, score candidates,
    and emit matches

The source of truth is now the flow model itself rather than one dedicated
binary.

The root launcher is `bin/vector-narrower`, which simply executes the module's
root flow through `kc-flow`.

Small helper scripts under `src/bin/` implement fd-oriented atomic actions that
the current `kc-flow` runtime cannot safely express inline because its
template parser reserves `<...>` for placeholders.

## Flow Set

- `src/flow/vnw-embed.flow`
- `src/flow/vnw-store-write.flow`
- `src/flow/vnw-store-read.flow`
- `src/flow/vnw-query-segment.flow`
- `src/flow/vnw-score-select.flow`
- `src/flow/vnw-pack.flow`
- `src/flow/vnw-match.flow`
- `src/flow/vector-narrower.flow`

## Hierarchy

```text
vector-narrower.flow
├── vnw-pack.flow
│   ├── vnw-embed.flow
│   └── vnw-store-write.flow
└── vnw-match.flow
    ├── vnw-query-segment.flow
    ├── vnw-embed.flow
    ├── vnw-store-read.flow
    └── vnw-score-select.flow
```

## Store Format

The persisted map content is flow-defined and editable. Each stored record is
one line:

```text
<source-text>\t<embedding-json>
```

The file is persisted through `kc-mmp`, so the backing store remains mmap-ready
without hardcoding a binary-only record layout into a dedicated application.

## Usage

### Pack

```bash
exec 3<input.txt
./bin/vector-narrower \
    --fd-in 3 \
    --set flow.param.mode=pack \
    --set flow.param.store.path=/tmp/vnw.store \
    --set flow.param.emb.model=./etc/bge-small.gguf \
    --set flow.param.emb.dim=384
```

### Match

```bash
exec 3<<<"how to cook italian food"
./bin/vector-narrower \
    --fd-in 3 \
    --set flow.param.mode=match \
    --set flow.param.store.path=/tmp/vnw.store \
    --set flow.param.emb.model=./etc/bge-small.gguf \
    --set flow.param.emb.dim=384 \
    --set flow.param.ngr.max_tokens=5 \
    --set flow.param.select.threshold=0.7
```

### Optional persistent embedding daemon

If embeddings are served through `kc-dmn`, set:

```bash
--set flow.param.emb.socket=./run/kc-emb.sock
```

`vnw-embed.flow` will use `kc-dmn` instead of `kc-emb --model`.

## Important Params

- `flow.param.mode`
- `flow.param.store.path`
- `flow.param.source.path`
- `flow.param.query.path`
- `flow.param.emb.model`
- `flow.param.emb.socket`
- `flow.param.emb.dim`
- `flow.param.ngr.max_tokens`
- `flow.param.ngr.min_tokens`
- `flow.param.ngr.separator`
- `flow.param.score.mode`
- `flow.param.select.threshold`
- `flow.param.select.mode`

## Testing

```bash
./test.sh
```

---

**Author:** KaisarCode

**Email:** <kaisar@kaisarcode.com>

**Website:** [https://kaisarcode.com](https://kaisarcode.com)

**License:** [GNU GPL v3.0](https://www.gnu.org/licenses/gpl-3.0.html)

© 2026 KaisarCode
