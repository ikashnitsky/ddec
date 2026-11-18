context("sensitivities and ltre_fixed")

L1 <- matrix(c(0,   1.2, 0.8,
               0.6, 0,   0,
               0,   0.8, 0.1), 3, byrow = TRUE)
L2 <- matrix(c(0,   1.4, 0.9,
               0.7, 0,   0,
               0,   0.7, 0.1), 3, byrow = TRUE)
lam <- function(M) max(Re(eigen(M)$values))

test_that("lambda_sensitivity() equals numerical derivatives", {
  expect_equal(lambda_sensitivity(L1), numeric_sensitivity(L1, lam), tolerance = 1e-6)
  S0 <- lambda_sensitivity(L1, zero = TRUE)
  expect_true(all(S0[L1 == 0] == 0))
})

test_that("leontief_sensitivity() equals numerical derivatives of v'(I - A)^-1 e", {
  A <- matrix(c(0.2, 0.1, 0.05, 0.3, 0.4, 0.1, 0.1, 0.2, 0.3), 3, byrow = TRUE)
  v <- 1 - colSums(A); e <- c(2, 0, 1)
  stat <- function(M) sum(v * solve(diag(3) - M, e))
  expect_equal(leontief_sensitivity(A, v, e), numeric_sensitivity(A, stat), tolerance = 1e-6)
  expect_error(leontief_sensitivity(A, v, 1:2), "length")
})

test_that("ltre_fixed() approximates the change in lambda to third order", {
  C <- ltre_fixed(L1, L2)
  expect_equal(dim(C), dim(L1))
  expect_equal(attr(C, "exact"), lam(L2) - lam(L1))
  expect_lt(abs(attr(C, "error")), 1e-3 * abs(attr(C, "exact")))
  # halving the change cuts the error by about 2^3
  Ch <- ltre_fixed(L1, (L1 + L2) / 2)
  expect_lt(abs(attr(Ch, "error")), abs(attr(C, "error")) / 4)
  # a generic stat gives the same answer through numerical sensitivities
  expect_equal(unclass(ltre_fixed(L1, L2, stat = lam))[1:9], unclass(C)[1:9], tolerance = 1e-6)
  expect_error(ltre_fixed(L1, L2[1:2, 1:2]), "same dimensions")
  expect_error(ltre_fixed(L1, L2, stat = "r"), "lambda")
})

test_that("ltre_fixed() is exact for a quadratic stat", {
  q <- function(M) sum(M)^2 + M[1, 2] * M[2, 1]
  C <- ltre_fixed(L1, L2, stat = q)
  expect_lt(abs(attr(C, "error")), 1e-8)
})

test_that("ltre_fixed() agrees with popbio::LTRE() on the Hudsonia matrices", {
  skip_if_not_installed("popbio")
  e <- new.env(); utils::data("hudsonia", package = "popbio", envir = e)
  h <- e$hudsonia
  ref <- popbio::LTRE(h$A88, h$A85)
  ours <- ltre_fixed(h$A85, h$A88)
  expect_equal(unclass(ours)[seq_along(ref)], unclass(ref)[seq_along(ref)], tolerance = 1e-6)
  expect_equal(lambda_sensitivity(h$A85), popbio::sensitivity(h$A85), tolerance = 1e-6)
})

test_that("ltre_fixed() with leontief_sensitivity() decomposes a change in VA in exports", {
  m1 <- load_icio(icio_synth[["2010"]]); m2 <- load_icio(icio_synth[["2020"]])
  v <- m1$Vc; e <- m1$E
  stat <- function(M) sum(v * solve(diag(nrow(M)) - M, e))
  C <- ltre_fixed(m1$A, m2$A, stat = stat, sensitivity = function(M) leontief_sensitivity(M, v, e))
  expect_equal(attr(C, "exact"), stat(m2$A) - stat(m1$A))
  expect_lt(abs(attr(C, "error")), 0.01 * abs(attr(C, "exact")))
})
