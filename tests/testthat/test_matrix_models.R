context("matrix models: Leontief inverse and fundamental matrix")

A <- matrix(c(0.2, 0.1, 0.05,
              0.3, 0.4, 0.10,
              0.1, 0.2, 0.30), 3, byrow = TRUE)

test_that("leontief_inverse() is (I - A)^-1 and the Neumann series", {
  B <- leontief_inverse(A)
  expect_equal(B, solve(diag(3) - A))
  S <- diag(3); P <- diag(3)
  for (k in 1:200) { P <- P %*% A; S <- S + P }
  expect_equal(B, S, tolerance = 1e-10)
})

test_that("leontief_inverse() reproduces the B of load_icio()", {
  m <- load_icio(leather)
  expect_equal(unname(leontief_inverse(m$A)), unname(m$B), tolerance = 1e-10)
})

test_that("value_added_multipliers() exhaust final demand with the residual VA", {
  expect_equal(unname(value_added_multipliers(A)), rep(1, 3))
  y <- c(10, 5, 2)
  VAy <- value_added_multipliers(A, y = y)
  expect_equal(sum(VAy), sum(y))
  v <- c(0.3, 0.2, 0.4)
  expect_equal(unname(value_added_multipliers(A, v = v)), drop(v %*% solve(diag(3) - A)))
})

test_that("non-convergent systems and bad input are rejected", {
  expect_error(leontief_inverse(A * 3), "spectral radius")
  expect_error(leontief_inverse(matrix(1:6 / 10, 2)), "square")
  expect_error(value_added_multipliers(A, v = 1:2), "length")
  expect_error(fundamental_matrix(matrix(c(0.9, 0.3, 0.1, 0.8), 2)), "column sums")
})

U <- matrix(c(0.90, 0.10,
              0.05, 0.80), 2, byrow = TRUE, dimnames = list(c("H", "D"), c("H", "D")))

test_that("fundamental_matrix() and leontief_inverse() are the same operation", {
  expect_equal(fundamental_matrix(U), leontief_inverse(U))
})

test_that("expected_time_in_state() returns colSums(N) and weighted versions", {
  N <- fundamental_matrix(U)
  e <- expected_time_in_state(U)
  expect_equal(unname(e["total", ]), unname(colSums(N)))
  e1 <- expected_time_in_state(U, start = c(0.7, 0.3))
  expect_equal(unname(e1["total"]), sum(colSums(N) * c(0.7, 0.3)))
  expect_equal(unname(e1[1:2]), unname(drop(N %*% c(0.7, 0.3))))
  expect_error(expected_time_in_state(U, start = c(1, 1)), "probability")
})

test_that("a life table is an absorbing Markov chain: e0 = 1'N e1 - 1/2", {
  mx <- c(0.005, 0.001, 0.002, 0.004, 0.01, 0.03, 0.08, 0.2, 0.5)
  n <- length(mx)
  lt <- life_table(mx, ax = rep(0.5, n))   # a_x = 1/2 throughout, incl. the last age
  Umat <- matrix(0, n, n)
  Umat[cbind(2:n, 1:(n - 1))] <- 1 - lt$qx[-n]   # survival on the subdiagonal
  e <- expected_time_in_state(Umat, start = c(1, rep(0, n - 1)), correction = 0.5)
  expect_equal(unname(e["total"]), lt$ex[1], tolerance = 1e-12)
})

test_that("fundamental_matrix() agrees with popbio::fundamental.matrix()", {
  skip_if_not_installed("popbio")
  # stage-classified projection matrix: fertility in row 1, substochastic transitions below
  Tm <- matrix(c(0.2, 0,   0,
                 0.5, 0.4, 0,
                 0,   0.4, 0.8), 3, byrow = TRUE)
  Fm <- matrix(0, 3, 3); Fm[1, 2:3] <- c(1.5, 3)
  pb <- popbio::fundamental.matrix(Tm + Fm)
  expect_equal(unname(fundamental_matrix(Tm)), unname(pb$N), tolerance = 1e-6)
  expect_equal(unname(expected_time_in_state(Tm)["total", ]), unname(c(pb$meaneta)), tolerance = 1e-6)
})
