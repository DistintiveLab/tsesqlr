# AGENTS.md

Guidance for agents working in the **tsesqlr** R package.

## What this is

An R package that acts as a **persistence layer** for TSE (Brazilian electoral
court) data. It downloads electoral data once via the sibling package
[`tsebr`](https://github.com/DistintiveLab/tsebr), writes it into a dedicated
PostgreSQL database (`tsedb`), and serves fast SQL/DBI queries without
re-downloading. The `beep` dashboard consumes this DB. Design is inspired by
`raisqlr`.

Everything lives in a single source file: `R/tsesqlr.R` (~330 lines). There are
no other `R/` files.

## Commands

There is no Makefile. Use `devtools` (installed) from the package root. The only
CI is the pkgdown workflow (see "Site de documentação" below); it does not run
tests or checks.

```r
devtools::test()        # run the testthat suite (offline, no DB needed)
devtools::document()    # regenerate NAMESPACE + man/*.Rd from roxygen comments
devtools::check()       # full R CMD check (examples are \dontrun, so no DB needed)
devtools::load_all()    # load package for interactive testing
```

Run `devtools::test()` after every change. The suite is fast and offline.

## Package conventions & gotchas

- **Docs are roxygen2-generated.** `NAMESPACE` and everything in `man/` carry a
  "do not edit by hand" / generated header. Never edit those by hand; edit the
  `#'` comments in `R/tsesqlr.R` and run `devtools::document()`. `RoxygenNote:
  7.3.2`, markdown is enabled (`Roxygen: list(markdown = TRUE)`).
- **Language is pt-BR.** All roxygen text, comments, and commit messages are in
  Portuguese. Match that when adding docs/comments. Code identifiers are mostly
  English-ish but domain terms stay Portuguese (`cargas`, `padronizar`, `ufs`).
- **Uses R 4.5 lambda syntax.** Every function is defined as
  `name <- \(args) {...}` (the `\` shorthand), not `function(args)`. Follow suit.
- **Internal helpers use a dot prefix** (`.ufs_br`, `.padrao_colunas`,
  `.padronizar`, `.agregar_boletins`, `.carregar_um`) and are documented with
  `@keywords internal`. Roxygen still emits `man/dot-*.Rd` for them. They are
  accessed in tests via `tsesqlr:::.name`.
- **Only 5 exported functions:** `tsesqlr_con`, `tsesqlr_init`, `tsesqlr_carregar`,
  `tsesqlr_resultados`, `tsesqlr_candidatos` (see `NAMESPACE`).
- **`tsebr` is in `Suggests`, not `Imports`,** but is called at runtime via
  `tsebr::` qualified calls. Do not move it to Imports without discussion; the
  query/init functions must work without it.
- **Single quotes vs. SQL:** `DBI::dbGetQuery`/`dbExecute` use `$1, $2, ...`
  placeholders with `params = list(...)`. Keep that pattern (no string
  interpolation of user values).
- **Cargo filters are Postgres regex** (`cargo ~* $3`), case-insensitive.

## Database / credentials

Connection is configured through `.Renviron` environment variables, NOT function
defaults in normal use: **`user`, `password`, `host`, `dbname`** (lowercase;
these same names are shared with `beep` / `prepare_db`). `tsesqlr_con()` has
hardcoded fallbacks (`beep`, a default password, `127.0.0.1`, `tsedb`) — these
are dev conveniences, keep them in sync with the sibling projects.

`dbname` defaults to `"tsedb"`. All functions accept an optional `con`; when
`con = NULL` they open a connection and close it on exit via
`on.exit(..., add = TRUE)`. Follow that ownership pattern in new functions.

## Architecture & data flow

```
tsebr (download)  ->  .carregar_um()  ->  .padronizar()  ->  PostgreSQL tsedb
                                                                   |
                              tsesqlr_resultados() / tsesqlr_candidatos()
```

- `tsesqlr_init()` creates only the `cargas` control table. Data tables are
  created lazily on first load with the canonical schema.
- `tsesqlr_carregar(tipo, ano, uf, refrescar)` is the entry point. It loops over
  scopes calling `.carregar_um()`.
- `.carregar_um()` dispatches to the right `tsebr::` downloader by `tipo`:
  `candidatos`→`tse_candidaturas`, `resultados`→`tse_votacao_municipio`
  (pre-2026) or `.agregar_boletins` (2026+, which wraps `tse_boletins`),
  `perfil`→`tse_perfis_secao`, `locais`→`tse_locais_votacao`.
- `.padronizar()` enforces the canonical column set from `.padrao_colunas`
  (missing columns filled with `NA`, extras dropped, column order fixed). An
  `ano` column already present in the data wins over the `ano` argument.

## Tables

| Table | Content |
|---|---|
| `candidatos` | candidacies per year/UF (key: `sq_candidato`) |
| `resultados` | votes per municipio/candidate/cargo/turno |
| `perfil_eleitorado` | voters per section (age/gender/education) |
| `locais_votacao` | sections with polling place, address, lat/lon |
| `mapa_municipios` | TSE ↔ IBGE municipality mapping |
| `cargas` | load registry (idempotency) |

> Note: `mapa_municipios` is documented in `README.md` and the package doc but is
> **not yet implemented** — no code creates it (`grep mapa_municipios R/` finds
> only the doc comment). Don't assume it exists in `tsedb`.

Canonical columns for the four loaded tables (`resultados`, `candidatos`,
`perfil_eleitorado`, `locais_votacao`) are defined in `.padrao_colunas`
(`R/tsesqlr.R:97`); `mapa_municipios` and `cargas` are not in that list. Each
entry has `ano` and `uf` and no duplicated columns — a test asserts this
invariant.

## Critical gotchas

- **Idempotency is keyed on `(tipo, ano, uf)` in `cargas`.** A load is skipped
  unless `refrescar = TRUE`. On reload the scope is `DELETE`d (by `ano`+`uf`, or
  only `ano` when `uf = "ALL"`) and re-inserted. A successful `ALL` load also
  deletes stale per-UF `cargas` rows for the same year, because the `ALL` load
  already covers them.
- **Schema mismatch forces a full table rebuild.** The layout check compares
  both column **names and types** (`.layout_compativel()`, via
  `information_schema` + `DBI::dbDataType`) against the data about to be written.
  On a mismatch, `.carregar_um()` errors and asks for `refrescar = TRUE`; with it,
  it `DROP TABLE`s, clears that table's `cargas` rows, and recreates. Warn users
  that all other loads of that table must be redone.
- **The two sides of that type comparison use different casing and vocabulary.**
  `information_schema.columns.data_type` is lowercase Postgres (`integer`,
  `double precision`, `character varying`) while RPostgres' `dbDataType()` returns
  uppercase aliases (`INTEGER`, `DOUBLE PRECISION`, `TEXT`). Both sides MUST go
  through `.normalizar_tipo_pg()` before comparing; a raw `==` makes every column
  mismatch and turns every load after the first into a `refrescar = TRUE` rebuild
  (or a hard error). `tests/testthat/` covers this offline.
- **A truncated ZIP extraction silently truncates the load.** `tsebr::tse_read()`
  extracts with `try(utils::unzip(...), silent = TRUE)`. When the write fails
  mid-file, `unzip` reports `write error in extracting from zip file`, the error
  is swallowed, `fread()` reads the cut CSV and merely drops the partial last line
  as `Discarded single-line footer`, and the load reports success with fewer rows.
  Every tsebr read in `.carregar_um()` therefore goes through `.ler_tsebr()`,
  which promotes that specific `unzip` warning into a hard error before anything
  is written to the DB. Do not add a raw `tsebr::` read call outside
  `.ler_tsebr()`.
- **The real space limit is the per-user disk quota, not `df`.** Observed on this
  host: `distintive` has a 60 GiB ext4 quota (`quota -s`); `df` showed tens of GB
  free while every write past the quota failed. The extraction runs in
  `tempdir()` (`/tmp`, same filesystem as `/`), and SP's 2026 bweb is the worst
  case: `bweb_1t_SP_051020261403.zip` holds an 8,316,061,252-byte CSV (7.75 GiB),
  by far the largest bweb (RJ is 3.1 GiB). Stale `/tmp/Rtmp*` directories from
  killed R sessions grow to tens of GB and eat the quota, which is what broke a
  2026 `uf = "ALL"` load of SP. Check with `quota -s` before blaming free space,
  and set `TMPDIR` to another filesystem when `/tmp` is tight.
- **Beware untyped `NA` when adding a canonical column.** `.padronizar()` fills
  missing columns with `NA` of the canonical type from `.tipos_colunas` (an
  `integer NA` for `turno`, a `Date NA` for `periodo`, etc.). An untyped logical
  `NA` makes `dbWriteTable` create the Postgres column as `BOOLEAN`, which then
  rejects real values: Postgres accepts `"1"`/`"0"` as boolean but not `"2"`, so a
  later load fails with `invalid input syntax for type boolean`. Any new canonical
  column MUST be added to BOTH `.padrao_colunas` and `.tipos_colunas` (a test
  enforces the coverage).
- **Memory-bounded loading.** `resultados` aggregates vote-by-section into
  municipality × turno × cargo × votável, one UF at a time. A national by-section
  load previously OOM-killed R sessions. `perfil` and `resultados` (2026+) have
  one file per UF so `uf = "ALL"` fans out per-UF via `.ufs_br` (incremental
  idempotency: load DF today, SP later). `candidatos`/`locais` are national and
  load in a single shot. Pre-2026 `resultados` with `ALL` is a single call
  because `tse_votacao_municipio` already processes UF-by-UF internally.
- **`"ALL"` vs `"all"` casing.** The public API takes `UF` or `"ALL"` (upper);
  `.carregar_um` translates to lowercase `"all"` for tsebr. For `locais`, `ALL`
  passes `NULL` (no UF filter) — passing a per-UF filter after reading would
  empty the load.
- **UF validation** rejects anything outside `.ufs_br` (27 UFs, no `ZZ`).
- **`nr_votavel` is stored as text** in queries; coerced with `as.character()`
  when filtering.

## Tests

`tests/testthat/test-tsesqlr.R` is **offline by design** — it only exercises pure
helpers (`.ufs_br`, `.padronizar`, `.padrao_colunas`) via `tsesqlr:::`. No DB, no
network. Follow this: don't add tests that require a live `tsedb` or downloads
unless you set up skips. `Config/testthat/edition: 3`.

## Git & versioning

- **Always bump the version on every commit.** Increment the last component of
  `Version:` in `DESCRIPTION` (a small dev bump: `0.0.1.9002` → `0.0.1.9003`).
- Commit messages are written in **Portuguese** (see `git log` for style).
- The repo has no `user.name`/`user.email` configured; commits have been authored
  as `Rodrigo Borges <rodrigoesborges@gmail.com>`. Pass the identity via
  `GIT_AUTHOR_*`/`GIT_COMMITTER_*` env vars rather than changing git config.

## Site de documentação (pkgdown)

- Site público: <https://distintivelab.github.io/tsesqlr/>, servido da branch
  `gh-pages` (docs em português, `lang: pt` em `_pkgdown.yml`).
- `.github/workflows/pkgdown.yaml` builda e publica a cada push em `main`
  (além de `pull_request`, `release` e `workflow_dispatch`). Ele instala
  `github::DistintiveLab/tsebr` porque o pacote chama `tsebr::` em runtime.
- `docs/` é o diretório de build e está no `.gitignore` — não commite nada ali.
  Para inspecionar localmente use
  `pkgdown::build_site(preview = FALSE)` e abra `docs/index.html`.
- **Gotcha:** o pkgdown renderiza *todo* `*.md` da raiz (e de `.github/`) como
  página do site e **ignora o `.Rbuildignore`**. Por isso o workflow roda
  `rm -f AGENTS.md` antes de buildar; sem isso este arquivo vira
  `docs/AGENTS.html` numa página pública. Se você renomear/mover os arquivos de
  documentação de agentes, ajuste (ou remova) esse passo.
- A branch `gh-pages` foi iniciada à mão (órfã, só com o conteúdo de `docs/` mais
  um `.nojekyll`); a partir daí o próprio workflow a mantém via
  `JamesIves/github-pages-deploy-action` com `clean: false`. Arquivos que
  deixarem de ser gerados **não** somem sozinhos — apague-os na branch.

## Files not to touch / generated

- `NAMESPACE`, `man/*.Rd` — generated by roxygen2.
- `.Rbuildignore` already excludes `AGENTS.md` and `README.Rmd`.
  `_pkgdown.yml`, `docs/` and `pkgdown/` were added by `usethis::use_pkgdown()`.
- `data-raw/` is currently empty.
