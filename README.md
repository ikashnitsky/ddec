# ddec

[![License](http://img.shields.io/badge/license-GPLv3-brightgreen.svg?style=flat)](https://www.gnu.org/licenses/gpl-3.0.html)
[![R build status](https://github.com/ikashnitsky/ddec/workflows/R-CMD-check/badge.svg)](https://github.com/ikashnitsky/ddec/actions?workflow=R-CMD-check)

**ddec** — *decomposition methods across trade and demography* — puts global value chain (GVC)
decompositions of inter-country input-output tables side by side with demographic
decompositions, and shows with code and numbers that they share their machinery:

1. Both partition an aggregate into additive contributions from structured factors.
2. The Leontief inverse $(I - A)^{-1}$ is the fundamental matrix $(I - U)^{-1}$ of an absorbing
   Markov chain (multistate life tables, matrix population models).
3. The non-uniqueness of multi-factor decompositions is solved the same way in both fields: by
   averaging over all orderings (Shapley), as in Das Gupta standardisation and in structural
   decomposition analysis.
4. LTRE (sensitivity × parameter change) and Leontief-based attribution are both
   decompositions of a scalar output of a matrix model into per-cell contributions.

The GVC code is a fork of the [`icio`](https://github.com/SebKrantz/icio) package
(Krantz and Quast), itself derived from `decompr`. There is no compatibility layer with either.

## Functions

| Area | Functions |
|---|---|
| GVC decompositions | `load_icio()`, `load_icio_csv()`, `bm()` (Borin & Mancini 2019), `leontief()` (Hummels, Ishii & Yi 2001), `kww()` (Koopman, Wang & Wei 2014), `wwz()` (Wang, Wei & Zhu 2013), `decomp()`, `gvc_components()` |
| Demographic decompositions | `kitagawa2()` (Kitagawa 1955), `das_gupta_n()` (Das Gupta 1993), `life_table()`, `arriaga_decomp()` (Arriaga 1984), `ltre_fixed()` (Caswell 1989) |
| Shared matrix models | `leontief_inverse()`, `value_added_multipliers()`, `fundamental_matrix()`, `expected_time_in_state()`, `lambda_sensitivity()`, `leontief_sensitivity()`, `numeric_sensitivity()` |
| Order-independent decomposition | `shapley_decomp()`, `sequential_decomp()`, `all_orderings()` |
| Data | `leather`, `icio_synth`, `dk_mortality`, `simulate_icio()` |

The demographic functions are written from scratch. The test suite checks them against
`DasGuptR` (Das Gupta's published examples), `LEdecomp::arriaga()` and `popbio::LTRE()` /
`popbio::fundamental.matrix()` to 1e-6. Every decomposition's adding-up identity is also tested,
including all four GVC methods summing to gross exports to 1e-8.

## Installation

```r
# install.packages("remotes")
remotes::install_github("ikashnitsky/ddec")
```

## Usage

```r
library(ddec)

# GVC: all four decompositions of the same gross exports
m <- load_icio(leather)
bm(m)
gvc_components(m)

# Demography: Danish crude death rate and life expectancy, 2000 vs 2019
d0 <- subset(dk_mortality, year == 2000); d1 <- subset(dk_mortality, year == 2019)
k <- kitagawa2(d0$mx, d1$mx, d0$pop, d1$pop)
colSums(k[, -1])                       # rate vs composition (ageing) effect
arriaga_decomp(d0$mx, d1$mx)           # age contributions to the e0 gain

# The bridge: one inverse, one Shapley
U <- matrix(c(0.85, 0.1, 0.05, 0.8), 2) # transient transitions; death absorbs the rest
identical(fundamental_matrix(U), leontief_inverse(U))
f <- function(p) sum(p$m * p$c)
shapley_decomp(f, list(m = d0$mx, c = d0$pop / sum(d0$pop)),
                  list(m = d1$mx, c = d1$pop / sum(d1$pop)))
```

## Data sources and caveats

| Dataset | Source | Caveat |
|---|---|---|
| `leather` | inherited from `icio`/`decompr` | toy 3 × 3 ICIO table |
| `icio_synth` | `simulate_icio()` via `data-raw/get_icio_data.R` | **synthetic**: internally consistent, but has no empirical meaning |
| `dk_mortality` | Eurostat `demo_magec` (deaths) and `demo_pjan` (population) via `data-raw/get_demo_data.R` | $m_x$ = deaths / mid-year population (the mean of two 1 January counts); open age 95+ |
| `hudsonia` (used in the report) | `popbio` | real stage-projection matrices |

Real ICIO tables (OECD TiVA, ADB MRIO) are not bundled because of their size and licences.
`load_icio()` and `load_icio_csv()` read them directly. The Human Mortality Database needs a
login, so it was not used; `data-raw/get_demo_data.R` describes the manual steps for swapping it
in. The raw Eurostat downloads are cached in `data-raw/cache/`, so nothing is downloaded at
render time.

## Reproducing the report

The Quarto report lives in `analysis/`: motivation and data, GVC results, demographic results,
structural parallels with the concept map, and limits of the analogy.

```sh
git clone https://github.com/ikashnitsky/ddec && cd ddec
Rscript -e 'renv::restore()'                 # exact package versions from renv.lock
Rscript -e 'devtools::test()'                # test suite
Rscript -e 'devtools::check()'               # R CMD check
quarto render                                # builds _site/ (loads ddec via pkgload)
Rscript data-raw/get_demo_data.R             # optional: rebuild data (uses the cache)
```

## References

- Arriaga, E. E. (1984). Measuring and explaining the change in life expectancies. *Demography*, 21(1), 83–96.
- Belotti, F., Borin, A., & Mancini, M. (2021). icio: Economic analysis with intercountry input-output tables. *The Stata Journal*, 21(3), 708–755.
- Borin, A., & Mancini, M. (2019). *Measuring What Matters in Global Value Chains and Value-Added Trade*. World Bank Policy Research Working Paper 8804.
- Caswell, H. (1989). Analysis of life table response experiments I. Decomposition of effects on population growth rate. *Ecological Modelling*, 46(3–4), 221–237.
- Das Gupta, P. (1993). *Standardization and Decomposition of Rates: A User's Manual*. U.S. Bureau of the Census, P23-186.
- Hummels, D., Ishii, J., & Yi, K.-M. (2001). The nature and growth of vertical specialization in world trade. *Journal of International Economics*, 54(1), 75–96.
- Kitagawa, E. M. (1955). Components of a difference between two rates. *JASA*, 50(272), 1168–1194.
- Koopman, R., Wang, Z., & Wei, S.-J. (2014). Tracing value-added and double counting in gross exports. *American Economic Review*, 104(2), 459–494.
- Oaxaca, R. L., & Sierminska, E. (2025). Oaxaca-Blinder meets Kitagawa: What is the link? *PLOS ONE*, 20(5), e0321874.
- Wang, Z., Wei, S.-J., & Zhu, K. (2013). *Quantifying International Production Sharing at the Bilateral and Sector Levels*. NBER Working Paper 19677.

Full, DOI-checked entries are in [`references.bib`](references.bib).
