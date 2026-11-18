context("kitagawa2 and das_gupta_n")

r1 <- c(0.001, 0.01, 0.1); r2 <- c(0.0008, 0.008, 0.09)
w1 <- c(50, 35, 15);       w2 <- c(40, 35, 25)

test_that("kitagawa2() effects add up exactly to the difference in crude rates", {
  k <- kitagawa2(r1, r2, w1, w2)
  expect_equal(nrow(k), 3L)
  expect_equal(sum(k$rate) + sum(k$composition), attr(k, "R2") - attr(k, "R1"), tolerance = 1e-14)
  expect_equal(attr(k, "R1"), sum(w1 / sum(w1) * r1))
  # counts and shares give the same result
  expect_equal(kitagawa2(r1, r2, w1 / 100, w2 / 100), k)
  expect_error(kitagawa2(r1, r2[1:2], w1, w2), "same length")
})

test_that("kitagawa2() is the two-player Shapley value", {
  s <- shapley_decomp(function(p) sum(p$r * p$c), list(r = r1, c = w1 / sum(w1)), list(r = r2, c = w2 / sum(w2)))
  k <- kitagawa2(r1, r2, w1, w2)
  expect_equal(as.vector(s), c(sum(k$rate), sum(k$composition)))
  expect_equal(as.vector(das_gupta_n(list(r = r1, c = w1 / sum(w1)), list(r = r2, c = w2 / sum(w2)))),
               c(sum(k$rate), sum(k$composition)))
})

test_that("kitagawa2() adds up on the Danish data", {
  d0 <- subset(dk_mortality, year == 2000); d1 <- subset(dk_mortality, year == 2019)
  k <- kitagawa2(d0$mx, d1$mx, d0$pop, d1$pop, groups = d0$age)
  cdr <- function(d) sum(d$deaths) / sum(d$pop)
  expect_equal(attr(k, "R1"), cdr(d0), tolerance = 1e-12)
  expect_equal(sum(k$rate) + sum(k$composition), cdr(d1) - cdr(d0), tolerance = 1e-12)
  expect_lt(sum(k$rate), 0)          # mortality fell...
  expect_gt(sum(k$composition), 0)   # ... while the population aged
})

test_that("das_gupta_n() adds up and handles scalar factors", {
  f1 <- list(a = c(1, 2), b = 3); f2 <- list(a = c(2, 2), b = 4)
  d <- das_gupta_n(f1, f2)
  expect_equal(sum(d), attr(d, "R2") - attr(d, "R1"))
  expect_equal(attr(d, "R1"), 9)
  expect_error(das_gupta_n(list(a = 1), list(b = 1)), "identical names")
  expect_error(das_gupta_n(list(a = 1:3, b = 1:2), list(a = 1:3, b = 1:2)), "lengths")
})

test_that("das_gupta_n() reproduces Das Gupta (1993) Example 2.3 via DasGuptR", {
  skip_if_not_installed("DasGuptR")
  e <- new.env(); utils::data("dgeg2_3", package = "DasGuptR", envir = e)
  x <- e$dgeg2_3
  fac <- c("birth_preg", "preg_actw", "actw_prop", "w_prop")
  f1 <- as.list(x[x$pop == 1971, fac]); f2 <- as.list(x[x$pop == 1979, fac])
  ours <- das_gupta_n(f1, f2)
  dg <- suppressMessages(DasGuptR::dgnpop(x, pop = "pop", factors = fac))
  ref <- vapply(fac, function(k) dg$rate[dg$factor == k & dg$pop == 1979] -
                                 dg$rate[dg$factor == k & dg$pop == 1971], numeric(1))
  expect_equal(ours[fac], ref, tolerance = 1e-6)
})

test_that("kitagawa2() reproduces Das Gupta (1993) Example 5.1 via DasGuptR", {
  skip_if_not_installed("DasGuptR")
  e <- new.env(); utils::data("dgeg5_1", package = "DasGuptR", envir = e)
  x <- e$dgeg5_1
  a <- x[x$pop == 1970, ]; b <- x[x$pop == 1985, ]
  k <- kitagawa2(a$rate, b$rate, a$size, b$size)
  dg <- suppressMessages(DasGuptR::dgnpop(x, pop = "pop", factors = "rate",
                                          id_vars = "age_group", crossclassified = "size"))
  eff <- function(fct) dg$rate[dg$factor == fct & dg$pop == 1985] - dg$rate[dg$factor == fct & dg$pop == 1970]
  expect_equal(sum(k$rate), eff("rate"), tolerance = 1e-6)
  expect_equal(sum(k$composition), eff("age_group_struct"), tolerance = 1e-6)
})
