# vector-narrower - Vector Content Narrower

> **Note:** This application is in the development and testing phase, is not ready for production use, and may change without prior notice.

`vector-narrower` is a high-performance command-line application for semantic content filtering. It identifies known text fragments within a stream by performing vector similarity matching against a memory-mapped database.

Designed to work as a first-class executable within the KaisarCode ecosystem, it abstracts complex internal flow logic into two simple public operations: `pack` and `match`.

## Usage

### Build the Vector Database (Pack)
Transform source text into a serialized vector store:

```bash
printf "The history of Rome\nCooking pasta" | vector-narrower pack --store kb.bin --model bge-small.gguf
```

### Semantic Matching (Match)
Search the database using natural language queries:

```bash
echo "How to cook italian food" | vector-narrower match --store kb.bin --model bge-small.gguf --threshold 0.7
```

## Parameter Reference

### Commands
- `pack`: Build a vector database from source text.
- `match`: Search the database with a query.

### Shared Options
| Option | Description | Default |
| :--- | :--- | :--- |
| `--store` | Path to the vector database file. | `/tmp/vector-narrower.store` |
| `--model` | Path to the GGUF model file. | `NULL` |
| `--dim` | Vector dimension of the model. | `384` |
| `--emb-socket`| Path to the embedding daemon socket (`kc-dmn`). | `NULL` |
| `--fd-in` | Input descriptor for text or query. | `0` (stdin) |
| `--fd-out` | Output descriptor for results or logs. | `1` (stdout) |
| `--trace` | Show internal execution trace for debugging. | `false` |
| `--help` | Show help and usage. | `false` |

### `match` Specific Options
| Option | Description | Default |
| :--- | :--- | :--- |
| `--threshold` | Similarity threshold (0.0 to 1.0) for matching. | `0.9` |
| `--select-mode`| Filtering mode: `best-per-unit` or `all`. | `best-per-unit` |
| `--score-mode` | Scoring algorithm: `cosine-similarity`. | `cosine-similarity` |

## Install

Run the autonomous installer:

```bash
wget -qO- https://raw.githubusercontent.com/kaisarcode/flows/slave/vector-narrower/install.sh | sudo bash
```

## Testing

```bash
./test.sh
```

## Internal Architecture

The `vector-narrower` executable is powered by an internal implementation based on `kc-flow` and modular FD-oriented helpers. This allows for transparent orchestration of high-performance primitives.

### Core Flows
- `src/flow/pack.flow`: Entry point for database construction.
- `src/flow/match.flow`: Entry point for similarity search logic.

### Internal Components
- `src/flow/internal/embed.flow`: Encapsulates embedding generation.
- `src/flow/internal/store-write.flow`: Handles vector store serialization.
- `src/flow/internal/store-read.flow`: Handles vector store retrieval.
- `src/flow/internal/query-segment.flow`: Decomposes query stream into chunks.
- `src/flow/internal/score-select.flow`: Filters results based on threshold and mode.

### Advanced Usage (Flow Parameters)
For advanced integration, the launcher maps public flags to internal `flow.param` values. You can override these directly if using `kc-flow` as your entry point:

| Flag | Flow Parameter |
| :--- | :--- |
| `--store` | `flow.param.store.path` |
| `--model` | `flow.param.emb.model` |
| `--threshold` | `flow.param.select.threshold` |

---

**Author:** KaisarCode

**Email:** <kaisar@kaisarcode.com>

**Website:** [https://kaisarcode.com](https://kaisarcode.com)

**License:** [GNU GPL v3.0](https://www.gnu.org/licenses/gpl-3.0.html)

© 2026 KaisarCode
