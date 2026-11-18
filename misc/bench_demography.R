# Benchmark ddec's demographic and matrix-model functions against their reference packages:
# arriaga_decomp() vs LEdecomp, das_gupta_n()/kitagawa2() vs DasGuptR, ltre_fixed()/
# lambda_sensitivity() vs popbio, and stepwise/Horiuchi vs DemoDecomp at 960 parameters.
# Run from the package root:  Rscript misc/bench_demography.R
# (The smaller stepwise/Horiuchi cases, incl. the scalar-func path, are in bench_stepwise_horiuchi.R.)
pkgload::load_all(".", quiet = TRUE)
timeit <- function(expr, reps = 5L, inner = 20L) {
  e <- substitute(expr); env <- parent.frame()
  stats::median(vapply(seq_len(reps), function(i)
    system.time(for (k in seq_len(inner)) eval(e, env))[["elapsed"]] / inner, numeric(1)))
}
out <- list(); add <- function(case, impl, s, d) out[[length(out) + 1]] <<- data.frame(case, impl, ms = 1000 * s, maxdiff = d)

## Arriaga vs LEdecomp (single-year ages, Denmark 2000 vs 2019)
d0 <- subset(dk_mortality, year == 2000); d1 <- subset(dk_mortality, year == 2019); age <- d0$age
ax0 <- LEdecomp::mx_to_ax(d0$mx, age = age, sex = "t"); ax1 <- LEdecomp::mx_to_ax(d1$mx, age = age, sex = "t")
ref <- LEdecomp::arriaga(d0$mx, d1$mx, age = age, sex1 = "t")
add("arriaga, 96 ages", "LEdecomp::arriaga", timeit(LEdecomp::arriaga(d0$mx, d1$mx, age = age, sex1 = "t"), inner = 200), 0)
add("arriaga, 96 ages", "ddec (ax supplied)", timeit(a <- arriaga_decomp(d0$mx, d1$mx, ax1 = ax0, ax2 = ax1), inner = 200), max(abs(a$total - ref)))
add("arriaga, 96 ages", "ddec (incl. mx_to_ax)", timeit(arriaga_decomp(d0$mx, d1$mx,
      ax1 = LEdecomp::mx_to_ax(d0$mx, age = age, sex = "t"), ax2 = LEdecomp::mx_to_ax(d1$mx, age = age, sex = "t")), inner = 200), NA)
add("arriaga, 96 ages", "ddec (ax = n/2)", timeit(arriaga_decomp(d0$mx, d1$mx), inner = 200), NA)

## Das Gupta, 4 factors (Example 2.3)
e <- new.env(); utils::data("dgeg2_3", package = "DasGuptR", envir = e); x <- e$dgeg2_3
fac <- c("birth_preg", "preg_actw", "actw_prop", "w_prop")
f1 <- as.list(x[x$pop == 1971, fac]); f2 <- as.list(x[x$pop == 1979, fac])
dg <- suppressMessages(DasGuptR::dgnpop(x, pop = "pop", factors = fac))
ref <- vapply(fac, function(k) dg$rate[dg$factor == k & dg$pop == 1979] - dg$rate[dg$factor == k & dg$pop == 1971], 1)
add("das gupta, 4 factors", "DasGuptR::dgnpop", timeit(suppressMessages(DasGuptR::dgnpop(x, pop = "pop", factors = fac))), 0)
add("das gupta, 4 factors", "ddec::das_gupta_n", timeit(o <- das_gupta_n(f1, f2), inner = 200), max(abs(o[fac] - ref)))

## Kitagawa, rate + composition (Example 5.1)
utils::data("dgeg5_1", package = "DasGuptR", envir = e); x <- e$dgeg5_1
a <- x[x$pop == 1970, ]; b <- x[x$pop == 1985, ]
dg <- suppressMessages(DasGuptR::dgnpop(x, pop = "pop", factors = "rate", id_vars = "age_group", crossclassified = "size"))
add("kitagawa, 2 factors", "DasGuptR::dgnpop", timeit(suppressMessages(DasGuptR::dgnpop(x, pop = "pop", factors = "rate",
      id_vars = "age_group", crossclassified = "size"))), 0)
add("kitagawa, 2 factors", "ddec::kitagawa2", timeit(k <- kitagawa2(a$rate, b$rate, a$size, b$size), inner = 500),
    abs(sum(k$rate) - (dg$rate[dg$factor == "rate" & dg$pop == 1985] - dg$rate[dg$factor == "rate" & dg$pop == 1970])))

## LTRE / sensitivity vs popbio (Hudsonia 6x6)
utils::data("hudsonia", package = "popbio", envir = e); h <- e$hudsonia
ref <- popbio::LTRE(h$A88, h$A85)
add("LTRE fixed, 6x6", "popbio::LTRE", timeit(popbio::LTRE(h$A88, h$A85), inner = 500), 0)
add("LTRE fixed, 6x6", "ddec::ltre_fixed", timeit(l <- ltre_fixed(h$A85, h$A88), inner = 500), max(abs(unclass(l)[seq_along(ref)] - unclass(ref)[seq_along(ref)])))
add("lambda sens., 6x6", "popbio::sensitivity", timeit(popbio::sensitivity(h$A85), inner = 500), 0)
add("lambda sens., 6x6", "ddec::lambda_sensitivity", timeit(s <- lambda_sensitivity(h$A85), inner = 500), max(abs(s - popbio::sensitivity(h$A85))))
set.seed(1); M1 <- matrix(runif(200^2, 0, 0.01), 200); M2 <- M1 * runif(200^2, 0.9, 1.1)
ref <- popbio::LTRE(M2, M1)
add("LTRE fixed, 200x200", "popbio::LTRE", timeit(popbio::LTRE(M2, M1), reps = 3, inner = 3), 0)
add("LTRE fixed, 200x200", "ddec::ltre_fixed", timeit(l <- ltre_fixed(M1, M2), reps = 3, inner = 3), max(abs(unclass(l)[seq_along(ref)] - unclass(ref)[seq_along(ref)])))

## Horiuchi scaling: 101 ages x 10 synthetic causes = 1010 parameters
mx0 <- d0$mx; mx1 <- d1$mx; nA <- length(mx0); C <- 10L
set.seed(2); w0 <- matrix(runif(nA * C), nA); w0 <- w0 / rowSums(w0); w1 <- w0 * runif(nA * C, .8, 1.2); w1 <- w1 / rowSums(w1)
P1 <- c(mx0 * w0); P2 <- c(mx1 * w1); id <- rep(seq_len(nA), C)
fs <- function(v) life_expectancy(rowsum(v, id, reorder = FALSE)); fv <- fs
add(sprintf("horiuchi N=20, %d pars", length(P1)), "DemoDecomp::horiuchi", timeit(r <- DemoDecomp::horiuchi(fs, P1, P2, N = 20), reps = 1, inner = 1), 0)
add(sprintf("horiuchi N=20, %d pars", length(P1)), "ddec, vectorized", timeit(hv <- horiuchi_decomp(fv, P1, P2, N = 20, vectorized = TRUE), reps = 3, inner = 3), max(abs(hv - r)))
add(sprintf("stepwise both, %d pars", length(P1)), "DemoDecomp::stepwise_replacement", timeit(r <- DemoDecomp::stepwise_replacement(fs, P1, P2, symmetrical = TRUE, direction = "both"), reps = 3, inner = 3), 0)
add(sprintf("stepwise both, %d pars", length(P1)), "ddec, vectorized", timeit(sv <- stepwise_decomp(fv, P1, P2, direction = "both", vectorized = TRUE), reps = 3, inner = 3), max(abs(sv - r)))

res <- do.call(rbind, out)
res$speedup <- ave(res$ms, res$case, FUN = function(s) s[1] / s)
print(res, digits = 3, row.names = FALSE)
