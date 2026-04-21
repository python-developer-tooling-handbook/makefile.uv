# Makefile.uv

A drop-in, `include`-based Makefile that gives any Python project a
[uv](https://docs.astral.sh/uv/)-backed test orchestration layer: `make sync`,
`make test`, `make test-py3.12`, `make test-all`, `make matrix`, `make clean`.

Inspired by [sio/Makefile.venv](https://github.com/sio/Makefile.venv).

## Install

From your project root, pull a tagged version:

```bash
curl -sSL https://raw.githubusercontent.com/python-developer-tooling-handbook/makefile.uv/v0.1.1/Makefile.uv -o Makefile.uv
```

Then, in your project's `Makefile`:

```makefile
PYTHON_VERSIONS := 3.12 3.13

include Makefile.uv
```

Add `Makefile.uv` to your repo (it's tiny; committing it locks the version) and
add the per-version venv directories to `.gitignore`:

```gitignore
.venv
.venv-*
```

## Usage

```console
$ make sync
$ make test
$ make test-py3.12
$ make test-all
$ make clean
$ make help
```

## Variables

All variables are `?=` assignments. Override them *before* `include Makefile.uv`.

| Variable | Default | Purpose |
|---|---|---|
| `PYTHON_VERSIONS` | `3.11 3.12 3.13 3.14` | Versions `test-all` iterates |
| `DEP_VARIANTS` | (empty) | Extras names for the 2-axis matrix. Empty disables `matrix`. |
| `PYTEST` | `pytest` | Test command (swap in `pytest --tb=short`, etc.) |
| `UV_VENV_PREFIX` | `.venv-` | Directory prefix for per-version venvs |
| `UV_SYNC_FLAGS` | (empty) | Extra flags forwarded to `uv sync` |
| `UV_RUN_FLAGS` | (empty) | Extra flags forwarded to every `uv run` (e.g. `--extra cli`, `--group test`, `--with ipython`) |

## Targets

| Target | What it does |
|---|---|
| `sync` | `uv sync $(UV_SYNC_FLAGS)` |
| `test` | `uv run $(PYTEST)` in the default venv |
| `test-py<VER>` | Run pytest on Python `<VER>` in `$(UV_VENV_PREFIX)<VER>` |
| `test-all` | `test-py<VER>` for each version in `PYTHON_VERSIONS` |
| `matrix` | Run every Python × `DEP_VARIANTS` cell |
| `test-cell-py<VER>-<VAR>` | Run one matrix cell |
| `clean` | Remove `.venv`, `$(UV_VENV_PREFIX)*`, `dist`, `*.egg-info`, `.pytest_cache` |
| `help` | Print targets and current variable values |

## The 2-axis matrix

Set `DEP_VARIANTS` to the names of extras you want to test against, and declare
the conflict in your `pyproject.toml`:

```toml
[project.optional-dependencies]
pd1 = ["pandas<2"]
pd2 = ["pandas>=2"]

[tool.uv]
conflicts = [
    [{extra = "pd1"}, {extra = "pd2"}],
]
```

Then:

```makefile
PYTHON_VERSIONS := 3.11 3.12
DEP_VARIANTS    := pd1 pd2

include Makefile.uv
```

`make matrix` runs four cells: `3.11 × pd1`, `3.11 × pd2`, `3.12 × pd1`, `3.12 × pd2`.
Each uses its own `$(UV_VENV_PREFIX)cell-<VER>-<VAR>` venv.

`DEP_VARIANTS` names must match keys in `[project.optional-dependencies]`
exactly. A `DEP_GROUPS` variant for [PEP 735 dependency groups](https://peps.python.org/pep-0735/)
is on the v0.2 roadmap.

## Gotchas

- **Per-version venvs use disk.** Four Python versions × two variants = eight
  venvs, each with the full dependency tree. `make clean` sweeps them.
- **Your `pyproject.toml` needs pytest in a dev group.** Otherwise `uv run pytest`
  fails. The `examples/basic/` directory shows the minimum required.
- **If you ship via `uv build`**, exclude the per-version venvs:
  ```toml
  [tool.hatch.build.targets.sdist]
  exclude = [".venv-*", ".tox"]
  ```
- **Collisions with your own `test` target** resolve by Make's "later definition
  wins" rule. Delete your version and adopt the included one, or rename yours.
- **Don't put pattern-matched targets in your own `.PHONY`** line — Make will
  then refuse to pattern-match them. `Makefile.uv` handles its own `.PHONY`
  internally; leave the generated `test-py<VER>` and `test-cell-py<VER>-<VAR>`
  names out of yours.
- **Windows native shells** can't parse the matrix cell recipe (it uses `cut`).
  Use Git Bash or WSL. Plain `test-py<VER>` works everywhere.

## Examples

- [`examples/basic/`](examples/basic/) — minimal project, single Python variant.
- [`examples/with-matrix/`](examples/with-matrix/) — two extras with a conflict
  block, exercised via `make matrix`.

## Compatibility

- GNU Make 3.81+ (macOS's default `/usr/bin/make` works)
- uv 0.4+
- macOS, Linux. Windows via Git Bash or WSL (see Gotchas).

## Roadmap

- **v0.2** — `lint`, `format`, `typecheck` targets (auto-detect ruff/ty/mypy);
  `DEP_GROUPS` variant for PEP 735; per-env log redirection.
- **v0.3** — `Taskfile.uv.yml` and `justfile.uv` companions with the same API.
- **v1.0** — Variable and target names freeze as stable.

## License

MIT. See [`LICENSE`](LICENSE).
