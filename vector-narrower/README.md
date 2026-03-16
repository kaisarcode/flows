# vector-narrower - Vector Content Narrower

> **Note:** This application is in the development and testing phase, is not ready for production use, and may change without prior notice.

`vector-narrower` is an application for semantic content filtering. It identifies known vectorized fragments within a text stream using vector similarity matching against a memory-mapped database.

## Usage

### Build the Vector Database (Pack)
Take a list of text entries and generate their embeddings to create a serialized vector store:

```bash
# Line-by-line text input to a vectorized map
printf "The history of Rome\nCooking pasta" | vector-narrower pack --store kb.bin --model bge-small.gguf
```

### Semantic Matching (Match)
Search the database using natural language. `vector-narrower` segments the query and finds the best semantic matches:

```bash
# Querying the knowledge base
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
| `--trace` | Show internal flow execution trace. | `false` |
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

`vector-narrower` is implemented as a `kc-flow` module. The public `vector-narrower` binary is a launcher that coordinates internal flow graphs and FD-oriented helpers.

### Flow Decomposition
- `src/flow/pack.flow`: Orchestrates the database building process.
- `src/flow/match.flow`: Orchestrates the semantic search process.
- `src/flow/internal/`: Contains reusable subflows for embedding, storage, and scoring.

### Internal Helpers
Located in `src/bin/`, these small FD-oriented utilities implement atomic actions that cannot be safely expressed inline within flow templates:
- `vnw-pack-source`: Prepares source text for embedding.
- `vnw-match-query`: Prepares matching environment.
- `vnw-embed`: Handles model/daemon embedding logic.
- `vnw-store-read`/`write`: Manages record serialization using `kc-mmp`.
- `vnw-score-select`: Final candidate selection logic.

---

**Author:** KaisarCode

**Email:** <kaisar@kaisarcode.com>

**Website:** [https://kaisarcode.com](https://kaisarcode.com)

**License:** [GNU GPL v3.0](https://www.gnu.org/licenses/gpl-3.0.html)

© 2026 KaisarCode
