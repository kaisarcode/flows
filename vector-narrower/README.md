# vector-narrower - Vector Content Narrower

> **Note:** This application is in the development and testing phase, is not ready for production use, and may change without prior notice.

`vector-narrower` is a command-line application for semantic content filtering. It identifies known text fragments within a stream by performing vector similarity matching against a memory-mapped database.

The application exposes two primary operations: `pack` (to build the database) and `match` (to query it).

## Usage

### Build the Vector Database (Pack)
Transform source text into a serialized vector store:

```bash
printf "The history of Rome\nCooking pasta" | vector-narrower pack --store kb.bin --model bge-small.gguf
```

### Semantic Matching (Match)
Search the database using natural language queries. `vector-narrower` reads queries from stdin and emits matching segments:

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
| `--emb-socket`| Path to the embedding daemon socket. | `NULL` |
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

## Advanced Examples

### Flow Parameter Overrides
For advanced integration and deep overriding, the application accepts direct `flow.param.*` mappings if explicitly needed.

| Flag | Equivalent Flow Parameter |
| :--- | :--- |
| `--store <path>` | `--set flow.param.store.path=<path>` |
| `--model <path>` | `--set flow.param.emb.model=<path>` |
| `--threshold <f>` | `--set flow.param.select.threshold=<f>` |

## Internal Architecture

Internally, `vector-narrower` is implemented using the KaisarCode flow engine and a series of dedicated helper binaries. The application orchestration relies on these transparent components:

### Flow Decomposition
- `src/flow/pack.flow`: Entry point for database construction.
- `src/flow/match.flow`: Entry point for similarity search logic.
- `src/flow/internal/embed.flow`: Encapsulates embedding generation.
- `src/flow/internal/store-read.flow`: Handles vector store retrieval.
- `src/flow/internal/store-write.flow`: Handles vector store serialization.
- `src/flow/internal/query-segment.flow`: Decomposes the query stream into chunks.
- `src/flow/internal/score-select.flow`: Filters results based on threshold and mode.

### Internal Helpers
Located in `src/bin/`, these atomic, FD-oriented utilities handle tasks that require low-level I/O manipulation:
- `vnw-pack-source`: Prepares source text for embedding.
- `vnw-match-query`: Prepares matching environment.
- `vnw-embed`: Handles model/daemon embedding logic.
- `vnw-store-read` / `vnw-store-write`: Manages record serialization using `kc-mmp`.
- `vnw-score-select`: Final candidate selection logic based on vector similarity.

---

**Author:** KaisarCode

**Email:** <kaisar@kaisarcode.com>

**Website:** [https://kaisarcode.com](https://kaisarcode.com)

**License:** [GNU GPL v3.0](https://www.gnu.org/licenses/gpl-3.0.html)

© 2026 KaisarCode
