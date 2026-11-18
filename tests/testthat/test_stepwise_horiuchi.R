context("life_expectancy, stepwise_decomp and horiuchi_decomp")

d0 <- subset(dk_mortality, year == 2000)
d1 <- subset(dk_mortality, year == 2019)
p1 <- d0$mx; p2 <- d1$mx
e0_scalar <- function(m) life_table(m)$ex[1]

test_that("life_expectancy() equals life_table() and is vectorised over columns", {
  expect_equal(life_expectancy(p1), life_table(p1)$ex[1], tolerance = 1e-12)
  M <- cbind(p1, p2, p1 * 0.5)
  expect_equal(life_expectancy(M), apply(M, 2, e0_scalar), tolerance = 1e-12)
  nx <- c(1, 4, 20, 25, 1); m <- c(0.01, 0.002, 0.005, 0.02, 0.1); ax <- c(0.1, 1.5, 10, 12, 10)
  expect_equal(life_expectancy(m, nx = nx, ax = ax), life_table(m, nx = nx, ax = ax)$ex[1])
  expect_equal(unname(life_expectancy(cbind(m, m), nx = nx, ax = cbind(ax, ax))), rep(life_table(m, nx = nx, ax = ax)$ex[1], 2))
  expect_equal(life_expectancy(0.05), 20)
  expect_error(life_expectancy(c(0.1, 0)), "open age")
  expect_error(life_expectancy(m, ax = 1:2), "ax")
})

test_that("stepwise_decomp() adds up exactly in every direction", {
  for (dir in c("up", "down", "both")) for (sym in c(TRUE, FALSE)) {
    s <- stepwise_decomp(life_expectancy, p1, p2, symmetrical = sym, direction = dir, vectorized = TRUE)
    expect_equal(sum(s), attr(s, "f2") - attr(s, "f1"), tolerance = 1e-10)
    expect_equal(length(s), length(p1))
  }
})

test_that("stepwise_decomp(): vectorised and scalar paths agree", {
  a <- stepwise_decomp(e0_scalar, p1, p2, direction = "both")
  b <- stepwise_decomp(life_expectancy, p1, p2, direction = "both", vectorized = TRUE)
  expect_equal(as.vector(a), as.vector(b), tolerance = 1e-10)
})

test_that("stepwise_decomp() reproduces Arriaga (oldest ages replaced first)", {
  s <- stepwise_decomp(life_expectancy, p1, p2, symmetrical = FALSE, direction = "down", vectorized = TRUE)
  expect_equal(as.vector(s), arriaga_decomp(p1, p2)$total, tolerance = 1e-10)
  u <- stepwise_decomp(life_expectancy, p1, p2, symmetrical = FALSE, direction = "up", vectorized = TRUE)
  expect_equal(as.vector(u), -arriaga_decomp(p2, p1)$total, tolerance = 1e-10)
})

test_that("stepwise_decomp() handles names, a single parameter and bad input", {
  x1 <- c(a = 1, b = 2, c = 3); x2 <- c(a = 2, b = 3, c = 5)
  s <- stepwise_decomp(prod, x1, x2)
  expect_equal(names(s), c("a", "b", "c"))
  expect_equal(sum(s), 30 - 6)
  expect_equal(as.vector(stepwise_decomp(function(x) x^2, 2, 3)), 5)
  expect_error(stepwise_decomp(prod, x1, x2[1:2]), "same positive length")
  expect_error(stepwise_decomp(prod, x1, x2, direction = "sideways"), "should be one of")
  expect_error(stepwise_decomp(function(M) 1, x1, x2, vectorized = TRUE), "one numeric value per column")
  expect_error(stepwise_decomp(function(x) x, x1, x2), "scalar")
})

test_that("stepwise_decomp() agrees with DemoDecomp::stepwise_replacement()", {
  skip_if_not_installed("DemoDecomp")
  for (dir in c("up", "down", "both")) for (sym in c(TRUE, FALSE)) {
    ref <- DemoDecomp::stepwise_replacement(e0_scalar, p1, p2, symmetrical = sym, direction = dir)
    expect_equal(as.vector(stepwise_decomp(e0_scalar, p1, p2, symmetrical = sym, direction = dir)),
                 as.vector(ref), tolerance = 1e-10)
    expect_equal(as.vector(stepwise_decomp(life_expectancy, p1, p2, symmetrical = sym, direction = dir,
                                           vectorized = TRUE)), as.vector(ref), tolerance = 1e-10)
  }
})

test_that("horiuchi_decomp() adds up to a small residual that shrinks with N", {
  h10 <- horiuchi_decomp(life_expectancy, p1, p2, N = 10, vectorized = TRUE)
  h40 <- horiuchi_decomp(life_expectancy, p1, p2, N = 40, vectorized = TRUE)
  expect_equal(attr(h10, "residual"), sum(h10) - (attr(h10, "f2") - attr(h10, "f1")))
  expect_lt(abs(attr(h10, "residual")), 1e-3)
  expect_lt(abs(attr(h40, "residual")), abs(attr(h10, "residual")) / 10)   # ~ 1/N^2
})

test_that("horiuchi_decomp() is exact for a linear function and order-free", {
  lin <- function(x) sum(c(2, 3, 5) * x)
  h <- horiuchi_decomp(lin, c(1, 1, 1), c(2, 3, 4), N = 3)
  expect_equal(as.vector(h), c(2, 6, 15))
  # permuting the parameters permutes the contributions
  f <- function(x) prod(x)
  a <- horiuchi_decomp(f, c(1, 2, 3), c(2, 3, 5), N = 50)
  b <- horiuchi_decomp(function(x) prod(x), c(3, 1, 2), c(5, 2, 3), N = 50)
  expect_equal(as.vector(a), as.vector(b[c(2, 3, 1)]), tolerance = 1e-12)
})

test_that("horiuchi_decomp(): vectorised, blocked and scalar paths agree", {
  a <- horiuchi_decomp(e0_scalar, p1, p2, N = 5)
  b <- horiuchi_decomp(life_expectancy, p1, p2, N = 5, vectorized = TRUE)
  c <- horiuchi_decomp(life_expectancy, p1, p2, N = 5, vectorized = TRUE, max_elements = 1)  # one step per block
  expect_equal(as.vector(a), as.vector(b), tolerance = 1e-10)
  expect_equal(as.vector(b), as.vector(c), tolerance = 1e-12)
})

test_that("horiuchi_decomp() components group parameters", {
  grp <- cut(d0$age, c(0, 15, 45, 65, 80, Inf), right = FALSE)
  g <- horiuchi_decomp(life_expectancy, p1, p2, N = 20, components = grp, vectorized = TRUE)
  expect_equal(names(g), levels(grp))
  expect_lt(abs(attr(g, "residual")), 1e-3)
  gs <- horiuchi_decomp(e0_scalar, p1, p2, N = 4, components = grp)
  gv <- horiuchi_decomp(life_expectancy, p1, p2, N = 4, components = grp, vectorized = TRUE)
  expect_equal(as.vector(gs), as.vector(gv), tolerance = 1e-10)
  # one label per parameter = ungrouped
  u <- horiuchi_decomp(life_expectancy, p1, p2, N = 4, components = seq_along(p1), vectorized = TRUE)
  expect_equal(as.vector(u), as.vector(horiuchi_decomp(life_expectancy, p1, p2, N = 4, vectorized = TRUE)))
  # grouped contributions are close to the sums of ungrouped ones
  ug <- tapply(as.vector(horiuchi_decomp(life_expectancy, p1, p2, N = 20, vectorized = TRUE)), grp, sum)
  expect_equal(as.vector(g), as.vector(ug), tolerance = 1e-3)
  expect_error(horiuchi_decomp(prod, 1:3, 2:4, components = 1:2), "one non-missing label")
  expect_error(horiuchi_decomp(prod, 1:3, 2:4, N = 0), "positive integer")
})

test_that("horiuchi_decomp() agrees with DemoDecomp::horiuchi()", {
  skip_if_not_installed("DemoDecomp")
  ref <- DemoDecomp::horiuchi(e0_scalar, p1, p2, N = 10)
  expect_equal(as.vector(horiuchi_decomp(e0_scalar, p1, p2, N = 10)), as.vector(ref), tolerance = 1e-10)
  expect_equal(as.vector(horiuchi_decomp(life_expectancy, p1, p2, N = 10, vectorized = TRUE)),
               as.vector(ref), tolerance = 1e-10)
  if ("components" %in% names(formals(DemoDecomp::horiuchi))) {
    grp <- cut(d0$age, c(0, 15, 45, 65, 80, Inf), right = FALSE)
    refg <- DemoDecomp::horiuchi(e0_scalar, p1, p2, N = 10, components = grp)
    expect_equal(as.vector(horiuchi_decomp(life_expectancy, p1, p2, N = 10, components = grp,
                                           vectorized = TRUE)), as.vector(refg), tolerance = 1e-10)
  }
})
