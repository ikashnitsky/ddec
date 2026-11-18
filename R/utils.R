# Internal helpers shared by the matrix-model and decomposition functions.

.check_square <- function(M, arg = deparse(substitute(M))) {
  if (!is.matrix(M) || !is.numeric(M)) stop("'", arg, "' must be a numeric matrix.")
  if (nrow(M) != ncol(M)) stop("'", arg, "' must be square, not ", nrow(M), " x ", ncol(M), ".")
  if (anyNA(M)) stop("'", arg, "' contains missing values.")
  invisible(M)
}

.spectral_radius <- function(M) max(Mod(eigen(M, only.values = TRUE)$values))

# (I - M)^-1: the single computation behind both the Leontief inverse and the
# fundamental matrix of an absorbing Markov chain. Both require rho(M) < 1, which is
# exactly the condition for the Neumann series I + M + M^2 + ... to converge.
.inverse_I_minus <- function(M, arg) {
  .check_square(M, arg)
  rho <- .spectral_radius(M)
  if (rho >= 1) stop("The spectral radius of '", arg, "' is ", signif(rho, 4),
                     " >= 1, so (I - ", arg, ")^-1 does not exist as a convergent series.")
  R <- solve(diag(nrow(M)) - M)
  dimnames(R) <- dimnames(M)
  R
}

# Dominant (right) eigenvector w and left eigenvector v of a non-negative matrix,
# scaled such that sum(w) = 1 and sum(v * w) = 1. One eigen() call: the left eigenvectors are
# the rows of W^-1, so v solves t(W) v = e_k (one LU, as in popbio::sensitivity()). Only for a
# defective matrix (singular W) do we fall back to a second eigen() on t(A).
.dominant_eigen <- function(A) {
  er <- eigen(A)
  k <- which.max(Re(er$values))
  lambda <- Re(er$values[k])
  W <- er$vectors
  w <- abs(Re(W[, k]))
  w <- w / sum(w)
  ek <- numeric(nrow(A)); ek[k] <- 1
  v <- tryCatch(solve(t(W), ek), error = function(e) NULL)
  if (is.null(v) || !all(is.finite(v))) {
    el <- eigen(t(A))
    v <- el$vectors[, which.max(Re(el$values))]
  }
  v <- abs(Re(v))
  v <- v / sum(v * w)
  list(lambda = lambda, w = w, v = v)
}

# Dominant eigenvalue only - no eigenvectors, so considerably cheaper than .dominant_eigen().
.dominant_lambda <- function(A) {
  ev <- eigen(A, only.values = TRUE)$values
  Re(ev[which.max(Re(ev))])
}
