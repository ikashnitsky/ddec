# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`ddec` is an R package (v0.1.0, GPL-3) that sets two families of decompositions side by side:

- **GVC decompositions** of gross exports from inter-country input-output (ICIO) tables:
  Borin-Mancini (2019), Leontief (Hummels-Ishii-Yi 2001), KWW (Koopman-Wang-Wei 2014) and WWZ
  (Wang-Wei-Zhu 2013). This code is a fork of the `icio` package (Krantz & Quast). `bm()`
  reproduces the Stata `icio` command and is the 1:1 R counterpart of `decompose()` in
  [GlobalValueChains.jl](https://github.com/SebKrantz/GlobalValueChains.jl).
- **Demographic decompositions** written from scratch: Kitagawa, Das Gupta, Arriaga and
  fixed-design LTRE.
- **A bridging layer**: Leontief inverse = fundamental matrix, a generic Shapley decomposition,
  and sensitivities (lambda and Leontief), all of which are outer products.

The project brief is the user's `ddec-jump-start.md`. The Quarto report in `analysis/` is the
deliverable that shows the parallels. There is **no backwards compatibility with `icio` or
`decompr`**, so do not add shims or aliases. The class of the ICIO object is still `"icio"`
(`load_icio()`); that is the object type, not the package name.

## Commands

All from the package root. `renv` is active (`.Rprofile`). `renv.lock` uses
`snapshot.type = "all"` and includes the dev toolchain (`devtools`, `roxygen2`), because the renv
sandbox hides the system library.

```r
renv::restore()           # exact package versions
devtools::load_all()      # load with C code compiled
devtools::document()      # regenerate man/*.Rd and NAMESPACE from roxygen comments
devtools::test()          # run the testthat suite
devtools::check()         # full R CMD check (what CI runs)
```

```sh
quarto render                                # the report: analysis/*.qmd -> _site/
Rscript data-raw/get_demo_data.R             # rebuild data/dk_mortality.rda (uses data-raw/cache/)
Rscript data-raw/get_icio_data.R             # rebuild data/icio_synth.rda
Rscript -e 'devtools::test(filter = "bm")'   # single test file (tests/testthat/test_bm.R)
Rscript misc/validate_bm_emerging.R          # local-only: bm() vs Julia on real ICIO data
```

The Quarto pages `source("analysis/_setup.R")`, which calls `pkgload::load_all(".")`
(`execute-dir: project`). That setup chunk must stay `cache: false`. If it is cached, a cached
re-render skips `load_all()` and the package functions go missing.

`NAMESPACE` and everything under `man/` are roxygen-generated — never hand-edit them; edit the
roxygen block above the function and re-run `devtools::document()`. Renaming anything that
`useDynLib` touches requires `rm src/*.o src/*.so && pkgbuild::compile_dll(force = TRUE)`;
`make` alone will report "Nothing to be done" because the stale `.o` is newer than the `.c`.

CI (`.github/workflows/`): `R-CMD-check` on Windows/macOS(release+devel)/Ubuntu, `test-coverage`,
and `pkgdown` deploy — all on push/PR to `master`.

## Demography and bridging layer

| File | Exports | Notes |
|---|---|---|
| [R/utils.R](R/utils.R) | — | `.inverse_I_minus()` is the single routine behind both `leontief_inverse()` and `fundamental_matrix()` |
| [R/leontief_inverse.R](R/leontief_inverse.R) | `leontief_inverse()`, `value_added_multipliers()` | |
| [R/markov_fundamental.R](R/markov_fundamental.R) | `fundamental_matrix()`, `expected_time_in_state()` | Caswell's column convention, `U[i, j] = P(j -> i)`, like `A` |
| [R/shapley.R](R/shapley.R) | `shapley_decomp()`, `sequential_decomp()`, `all_orderings()` | evaluates `f` on all 2^K subsets (bitmasks); `groups =` splits one parameter into several players |
| [R/kitagawa.R](R/kitagawa.R) | `kitagawa2()`, `das_gupta_n()` | `das_gupta_n()` is a thin wrapper around `shapley_decomp()` |
| [R/arriaga.R](R/arriaga.R) | `life_table()`, `arriaga_decomp()` | defaults to `ax = nx/2`; pass `ax` to match LEdecomp's Andreev-Kingkade a0 |
| [R/ltre.R](R/ltre.R) | `ltre_fixed()`, `lambda_sensitivity()`, `leontief_sensitivity()`, `numeric_sensitivity()` | midpoint-matrix sensitivity × change, as in `popbio::LTRE()` |
| [R/gvc_components.R](R/gvc_components.R) | `gvc_components()` | all four GVC methods mapped onto VAX/REF/DDC/FVA/FDC (Leontief: DC/FC) |
| [R/simulate_icio.R](R/simulate_icio.R) | `simulate_icio()` | balanced synthetic `iot` tables |

The tests cross-check against `DasGuptR`, `LEdecomp` and `popbio` (in Suggests, guarded with
`skip_if_not_installed()`) to 1e-6. `leontief_sensitivity(A, v, e)` differentiates the **full**
sum `v'(I-A)^-1 e`. To attribute a single country's domestic content, mask `v` (and `e`) to that
country's rows first.

## Architecture

The package is organised as **one file per decomposition**, all operating on a single shared
intermediate object.

### The `icio` object

`load_icio()` ([R/load_icio.R](R/load_icio.R)) is the entry point for everything. It takes the
raw ICIO matrices (`inter` = GN×GN intermediate demand, `final` = GN×(G·M) final demand,
`countries` = G, `industries` = N, optional `output` and `va`) and precomputes what the
decompositions need. An `iot`-class list like `data(leather)` passed as the first argument is
detected via `inherits()` — there is deliberately no separate `iot` parameter. Note that
`leather` names its output vector `out` while other `iot` producers use `output`; the loader
accepts both (`$` partial matching does *not* bridge them, which was a silent bug in `decompr`).

`load_icio_csv()` reads the Stata `icio` CSV format (headerless `GN × (GN + G)` matrix
`[inter | final]` + a one-column country list) via `data.table::fread()`, and delegates.

The object's fields:

- `A` = input coefficients (**full**, including domestic blocks); `B` = Leontief inverse `(I-A)^-1`.
  These are the **only** two dense GN×GN matrices, and the only two fields carrying independent
  information.
- `Lb` = **list of G local Leontief blocks** `(I-A_gg)^-1`, one N×N matrix per country — not a
  dense GN×GN matrix, which would be `1 - 1/G` structural zeros.
- `Vc` = value-added coefficients `va/output`; `E`/`ESR` = exports; `X`/`Y`/`Yd`/`Ym`;
  `G`/`N`/`GN`/`k`/`i`.

**Do not add masked or block-diagonal copies back to the object.** `decompr` up to 6.9.0 also
stored `Am` (A with domestic blocks zeroed), `Bd`/`Bm` (domestic/foreign parts of B), a dense
`L`, plus `Eint`/`Efd`/`rownam`. All were derivable, and `Bd`/`L` were ~99% zeros at realistic
G. Each decomposition derives what it needs:

- `bm()` and `kww()` never materialise `Bd`, `Bm` or a dense `L` — every product involving them is
  block-diagonal, so they loop over `B[bg, bg]` and `Lb[[g]]`. Both materialise `Am` once.
- `wwz()` uses the masked matrices in dense GN×GN products throughout, so it rebuilds `Am`, `Bd`,
  `Bm`, `Eint` (`= ESR - Ym`) and `Efd` (`= Ym`) on entry. It uses `Lb` blockwise.
- Re-associate before materialising: `kww()` computes `Bm %*% (Am %*% (L %*% Z))` with `Z` only G
  columns wide instead of `Bm %*% Am %*% L`, which is what made it ~10× faster.

Row/column ordering is **country-major**: `C1I1, C1I2, ..., C2I1, ...`, so country `g`'s block is
`(g-1)*N + seq_len(N)`. Every engine relies on this. Names come from
`as.vector(t(outer(k, i, paste, sep = ".")))` and are on `names(Vc)` / `dimnames(B)`.

Decomposition functions all start with `list2env(x, environment())` to pull the object's fields
into scope (initialise them to `NULL` first — `R CMD check` flags undefined globals otherwise).

### Decompositions

| File | Export | Output |
|------|--------|--------|
| [R/bm.R](R/bm.R) | `bm()` | up to 13 terms; the recommended method |
| [R/leontief.R](R/leontief.R) | `leontief()` | VA origins of exports/output/final demand; long or wide |
| [R/kww.R](R/kww.R) | `kww()`, `wwz2kww()` | 9 country-level terms; `wwz2kww()` aggregates a WWZ result instead of recomputing |
| [R/wwz.R](R/wwz.R) | `wwz()` | G·N·G rows × 16 terms + totals + checksums |
| [R/decomp.R](R/decomp.R) | `decomp()` | `switch(method)` + `...`; on a *list* of `icio` objects runs each and `rbindlist`s with an `idcol` |

Results are **data.tables** with factor identifier columns (`Exporting_Country`,
`Exporting_Industry`, `Importing_Country`, `Origin_Country`) followed by term columns, tagged
with `attr(x, "decomposition")` (`"wwz"`, `"kww"`, `"bm"`) — `wwz2kww()` dispatches on that
attribute. They are built **column-list-first** and then handed to `data.table::setDT()`, which
is why the engines never call `data.frame()`; set attributes with `setattr()`, not `attr<-`,
to avoid copying. Consequence to remember when writing tests or examples: `d[, "GEXP"]` yields a
one-column table and `d[c("a","b")]` is a *join*, not a column subset — use `d$GEXP`,
`d[, .(a, b)]` or `as.data.frame(d)`.

### `bm()` structure

[R/bm.R](R/bm.R) is a **dispatcher + shared prep + one engine per variant**:

- `bm()` validates the `aggregation` × `perspective` × `approach` × `flow` combination and routes.
- `.bm_prep(x)` computes everything shared: `Am`, the three VA multipliers (`VBdom`/`VBfor`/`VLdom`,
  built blockwise from `B[bg, bg]` and `Lb[[g]]`), `fvacoef`, `Wcol` and `BFD`. Engines get this
  list as `P` and pull it into scope with `list2env(P, environment())`.
- `.bm_source` (exporter/source, 13 terms), `.bm_world` (country-level "corrected KWW"),
  `.bm_sink` (BM19 eq. 33-39), `.bm_self` (eq. 47-49), `.bm_imports` (eq. 51, Woodbury update of
  `B` per importer). Each is a line-by-line port of the corresponding Julia engine.

Term columns are UPPER-CASE by convention here (the other decompositions use mixed case), and
`bm()`'s argument is `aggregation` where Julia's is `level` — this divergence is deliberate.
[misc/bm_expansion_plan.md](misc/bm_expansion_plan.md) documents the Julia↔R field mapping (its
"Field mapping" section is historical/stale — see the note at its top).

### C code

[src/rowmult.c](src/rowmult.c) contains a single routine, `C_rowmult(x, v)` = column-scaling of a
matrix (`t(t(x) * v)`), registered via `R_init_ddec` with `R_forceSymbols(TRUE)` — call it as
`.Call(C_rowmult, ...)`, not by string name. Used in `load_icio()` and `wwz()`.
`matrixStats::rowSums2`/`colSums2` are used throughout for the same reason (avoiding copies on
large ICIO tables, which run to thousands of rows).

## Testing

`tests/testthat/` covers the GVC code (`load_icio`/`load_icio_csv`, `leontief`, `wwz`, `bm`,
`gvc_components`) against the 3×3 `leather` table and `icio_synth`, plus the demographic and
bridging functions (`test_kitagawa.R`, `test_arriaga.R`, `test_ltre.R`, `test_shapley.R`,
`test_matrix_models.R`). The `bm` tests are the model to follow for new work: output dimensions,
**accounting identities** (`GEXP = DC + FC`, `DC = DVA + DDC`, `DVA = VAX + REF`,
`GIMP = VA + DC`), **additivity** (bilateral sums to sector sums to country), cross-engine
anchors, and error paths for invalid option combinations. Ground truth beyond identities is
established externally against `GlobalValueChains.jl`/Stata `icio` via
`misc/validate_bm_emerging.R`, which needs local data not in the repo.

Two testthat gotchas here: the suite runs on edition 2, so `ignore_attr =` is not honoured —
use `unname()`. And `expect_identical()` fails on two equal data.tables because each carries
its own `.internal.selfref` pointer — use `expect_equal()`.

## Not part of the build

`.Rbuildignore` excludes `misc/`, `pkgdown/`, `.github/`, `CLAUDE.md`, `renv/`, `analysis/`,
`data-raw/`, the Quarto config and outputs, and `references.bib`.
