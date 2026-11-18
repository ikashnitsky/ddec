context("shapley_decomp, sequential_decomp, all_orderings")

f <- function(p) p$a * p$b * p$c
x1 <- list(a = 1, b = 2, c = 3)
x2 <- list(a = 2, b = 3, c = 5)

test_that("Shapley contributions add up exactly", {
  s <- shapley_decomp(f, x1, x2)
  expect_equal(sum(s), f(x2) - f(x1))
  expect_equal(attr(s, "f1"), f(x1))
  expect_equal(attr(s, "f2"), f(x2))
  expect_equal(names(s), c("a", "b", "c"))
})

test_that("Shapley matches the closed form for a product of three factors", {
  # Das Gupta (1993, eq. 3.6): alpha effect of R = alpha * beta * gamma
  a1 <- 1; a2 <- 2; b1 <- 2; b2 <- 3; c1 <- 3; c2 <- 5
  alpha <- (a2 - a1) * ((b1 * c1 + b2 * c2) / 3 + (b1 * c2 + b2 * c1) / 6)
  expect_equal(unname(shapley_decomp(f, x1, x2)["a"]), alpha)
})

test_that("Shapley is independent of the order in which players are listed", {
  s <- shapley_decomp(f, x1, x2)
  r <- shapley_decomp(f, x1[c(3, 1, 2)], x2[c(3, 1, 2)])
  expect_equal(as.vector(r[names(s)]), as.vector(s))
})

test_that("Shapley is the average of sequential effects over all orderings", {
  ao <- all_orderings(f, x1, x2)
  expect_equal(nrow(ao), 6L * 3L)
  m <- ao[, .(avg = mean(effect)), by = player]
  expect_equal(m$avg, unname(shapley_decomp(f, x1, x2)[m$player]))
  # each ordering adds up, but the effects differ across orderings
  expect_true(all(abs(ao[, sum(effect), by = ordering]$V1 - (f(x2) - f(x1))) < 1e-12))
  expect_gt(ao[, diff(range(effect)), by = player][, max(V1)], 0)
})

test_that("sequential_decomp() is order-dependent but always adds up", {
  s1 <- sequential_decomp(f, x1, x2, order = c("a", "b", "c"))
  s2 <- sequential_decomp(f, x1, x2, order = c("c", "b", "a"))
  expect_equal(sum(s1), sum(s2))
  expect_false(isTRUE(all.equal(s1, s2)))
  expect_equal(unname(s1["a"]), (2 - 1) * 2 * 3)  # 'a' switched first: others at x1
  expect_error(sequential_decomp(f, x1, x2, order = c("a", "b")), "permutation")
})

test_that("groups split a single parameter into several players", {
  g <- function(x) sum(x[1:2]) * prod(x[3:4])
  y1 <- c(1, 2, 3, 4); y2 <- c(2, 2, 5, 1)
  s <- shapley_decomp(g, y1, y2, groups = c("p", "p", "q", "r"))
  expect_equal(names(s), c("p", "q", "r"))
  expect_equal(sum(s), g(y2) - g(y1))
  # groups spanning several list elements
  h <- function(p) sum(p$u) * sum(p$w)
  s2 <- shapley_decomp(h, list(u = 1:2, w = 3:4), list(u = c(2, 2), w = c(3, 6)),
                       groups = list(u = c("A", "B"), w = c("A", "B")))
  expect_equal(sum(s2), 4 * 9 - 3 * 7)
  expect_error(shapley_decomp(g, y1, y2, groups = c("p", "q")), "structure")
})

test_that("a linear function gets its exact linear contributions", {
  lin <- function(p) 2 * p$a + 3 * p$b
  s <- shapley_decomp(lin, list(a = 1, b = 1), list(a = 4, b = 2))
  expect_equal(as.vector(s), c(6, 3))
})

test_that("bad input is rejected", {
  expect_error(shapley_decomp(1, x1, x2), "function")
  expect_error(shapley_decomp(f, x1, x2[1:2]), "structure")
  expect_error(shapley_decomp(function(p) c(1, 2), x1, x2), "scalar")
})
