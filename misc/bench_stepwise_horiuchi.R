# Benchmark ddec::stepwise_decomp() / horiuchi_decomp() against DemoDecomp.
# Run from the package root:  Rscript misc/bench_stepwise_horiuchi.R
#
# Fair comparison: DemoDecomp and the non-vectorised ddec path get the *same* scalar func, so the
# difference is purely the decomposition machinery. The vectorised ddec path uses a matrix
# version of the same function and returns the same numbers.
pkgload::load_all(".", quiet = TRUE)

# Median over `reps` timings, each of `inner` back-to-back runs, in seconds per run
timeit <- function(expr, reps = 5L, inner = 20L) {
  e <- substitute(expr); env <- parent.frame()
  t <- vapply(seq_len(reps), function(i)
    system.time(for (k in seq_len(inner)) eval(e, env))[["elapsed"]] / inner, numeric(1))
  stats::median(t)
}
row <- function(case, method, impl, secs, maxdiff) data.frame(case, method, impl, seconds = secs, max_abs_diff_vs_DemoDecomp = maxdiff)

## Case 1: e0 by single year of age, Denmark 2000 vs 2019 (96 parameters)
d0 <- subset(dk_mortality, year == 2000); d1 <- subset(dk_mortality, year == 2019)
e0s <- function(m) life_expectancy(m)            # scalar use, same formulas
p1 <- d0$mx; p2 <- d1$mx

## Case 2: e0 by cause of death, DemoDecomp's Mxc1/Mxc2 (19 abridged ages x 6 causes = 114)
data("Mxc1", package = "DemoDecomp", envir = environment()); data("Mxc2", package = "DemoDecomp", envir = environment())
nx_abr <- c(1, 4, rep(5, 17))
age_id <- rep(seq_len(nrow(Mxc1)), ncol(Mxc1))
cod_s <- function(v) life_expectancy(rowsum(v, age_id, reorder = FALSE), nx = nx_abr)
cod_v <- function(M) life_expectancy(rowsum(M, age_id, reorder = FALSE), nx = nx_abr)
q1 <- c(Mxc1); q2 <- c(Mxc2)

res <- list()
for (cs in list(list("e0, 96 ages", e0s, e0s, p1, p2), list("e0 by cause, 114 pars", cod_s, cod_v, q1, q2))) {
  nm <- cs[[1]]; fs <- cs[[2]]; fv <- cs[[3]]; a <- cs[[4]]; b <- cs[[5]]
  ref_s <- DemoDecomp::stepwise_replacement(fs, a, b, symmetrical = TRUE, direction = "both")
  ref_h <- DemoDecomp::horiuchi(fs, a, b, N = 20)
  res[[length(res) + 1]] <- row(nm, "stepwise (both, symm.)", "DemoDecomp",
    timeit(DemoDecomp::stepwise_replacement(fs, a, b, symmetrical = TRUE, direction = "both")), 0)
  res[[length(res) + 1]] <- row(nm, "stepwise (both, symm.)", "ddec, scalar func",
    timeit(s1 <- stepwise_decomp(fs, a, b, direction = "both")), max(abs(s1 - ref_s)))
  res[[length(res) + 1]] <- row(nm, "stepwise (both, symm.)", "ddec, vectorized",
    timeit(s2 <- stepwise_decomp(fv, a, b, direction = "both", vectorized = TRUE)), max(abs(s2 - ref_s)))
  res[[length(res) + 1]] <- row(nm, "horiuchi (N = 20)", "DemoDecomp",
    timeit(DemoDecomp::horiuchi(fs, a, b, N = 20), reps = 3L, inner = 3L), 0)
  res[[length(res) + 1]] <- row(nm, "horiuchi (N = 20)", "ddec, scalar func",
    timeit(h1 <- horiuchi_decomp(fs, a, b, N = 20), reps = 3L, inner = 3L), max(abs(h1 - ref_h)))
  res[[length(res) + 1]] <- row(nm, "horiuchi (N = 20)", "ddec, vectorized",
    timeit(h2 <- horiuchi_decomp(fv, a, b, N = 20, vectorized = TRUE), reps = 3L, inner = 3L), max(abs(h2 - ref_h)))
}
res <- do.call(rbind, res)
res$speedup <- ave(res$seconds, res$case, res$method, FUN = function(s) s[1] / s)
print(res, digits = 3, row.names = FALSE)
