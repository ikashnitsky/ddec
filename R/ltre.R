#' Sensitivities of Matrix-Model Outputs to Matrix Entries
#'
#' Derivatives of a scalar output of a matrix model with respect to every entry of the matrix:
#' the dominant eigenvalue \eqn{\lambda} of a projection matrix (\code{lambda_sensitivity()}), the
#' value added embodied in a final-demand or export vector \eqn{v'(I - A)^{-1} e}
#' (\code{leontief_sensitivity()}), or any function, numerically (\code{numeric_sensitivity()}).
#'
#' @param A numeric square matrix: a population projection matrix (\code{lambda_sensitivity()}),
#'  an input coefficient matrix (\code{leontief_sensitivity()}), or any matrix argument of
#'  \code{stat} (\code{numeric_sensitivity()}).
#' @param v numeric vector of value-added coefficients (length \code{nrow(A)}).
#' @param e numeric vector of final demand or exports (length \code{nrow(A)}).
#' @param stat a function of a matrix returning a numeric scalar.
#' @param h numeric. Step size for central differences.
#' @param zero logical. Set sensitivities of structurally zero entries (\code{A == 0}) to 0?
#'
#' @details
#' Both analytic sensitivities are \emph{outer products of a left and a right vector}:
#' \itemize{
#'  \item \eqn{\partial\lambda / \partial a_{ij} = v_i w_j / \langle v, w\rangle}, with \eqn{w} and
#'   \eqn{v} the right (stable structure) and left (reproductive value) eigenvectors (Caswell 2001);
#'  \item \eqn{\partial\, v'(I-A)^{-1}e / \partial a_{ij} = (v'B)_i\, (Be)_j}, with
#'   \eqn{B = (I-A)^{-1}}: the value-added multiplier of the supplying sector \eqn{i} times the
#'   gross output of the using sector \eqn{j} - since \eqn{\partial B = B\, \partial A\, B}.
#' }
#' The reproductive value plays the role of the value-added multiplier (what a unit in state
#' \eqn{i} is worth downstream), and the stable structure the role of gross output (how much of
#' the system passes through \eqn{j}).
#'
#' @return A matrix of the same dimensions as \code{A}.
#' @references Caswell, H. (2001). \emph{Matrix Population Models: Construction, Analysis, and
#'  Interpretation} (2nd ed.). Sinauer Associates.
#' @seealso \code{\link{ltre_fixed}}
#' @export
#' @examples
#' L <- matrix(c(0,   1.2, 0.8,
#'               0.6, 0,   0,
#'               0,   0.8, 0), 3, byrow = TRUE)
#' lambda_sensitivity(L)
#' numeric_sensitivity(L, function(M) max(Re(eigen(M)$values)))
#'
#' A <- matrix(c(0.2, 0.1, 0.3, 0.4), 2, byrow = TRUE)
#' leontief_sensitivity(A, v = 1 - colSums(A), e = c(1, 0))
lambda_sensitivity <- function(A, zero = FALSE) {
  .check_square(A, "A")
  d <- .dominant_eigen(A)
  S <- outer(d$v, d$w)
  if (zero) S[A == 0] <- 0
  dimnames(S) <- dimnames(A)
  S
}

#' @rdname lambda_sensitivity
#' @export
leontief_sensitivity <- function(A, v, e, zero = FALSE) {
  B <- leontief_inverse(A)
  if (length(v) != nrow(A) || length(e) != nrow(A)) stop("'v' and 'e' must have length nrow(A).")
  S <- outer(drop(v %*% B), drop(B %*% e))
  if (zero) S[A == 0] <- 0
  dimnames(S) <- dimnames(A)
  S
}

#' @rdname lambda_sensitivity
#' @export
numeric_sensitivity <- function(A, stat, h = 1e-6, zero = FALSE) {
  if (!is.matrix(A)) stop("'A' must be a matrix.")
  S <- A
  for (k in seq_along(A)) {
    if (zero && A[k] == 0) { S[k] <- 0; next }
    Ap <- Am <- A
    Ap[k] <- A[k] + h
    Am[k] <- A[k] - h
    S[k] <- (stat(Ap) - stat(Am)) / (2 * h)
  }
  S
}

#' Fixed-Design Life Table Response Experiment (LTRE)
#'
#' First-order decomposition of the difference in a scalar output of a matrix model between two
#' matrices into contributions of each matrix entry: the sensitivity, evaluated at the midpoint
#' matrix, times the change in the entry (Caswell 1989).
#'
#' @param A1,A2 numeric matrices of the same dimensions (e.g. projection matrices in a reference and
#'  a treatment condition, or input coefficient matrices in two years).
#' @param stat the output. Either \code{"lambda"} (dominant eigenvalue, analytic sensitivities via
#'  \code{\link{lambda_sensitivity}}) or a function of a matrix returning a numeric scalar
#'  (sensitivities via \code{\link{numeric_sensitivity}}, unless \code{sensitivity} is given).
#' @param sensitivity optional function of a matrix returning its sensitivity matrix, e.g.
#'  \code{function(A) leontief_sensitivity(A, v, e)}. Overrides the default for \code{stat}.
#'
#' @details
#' \deqn{\Delta\theta \approx \sum_{ij} (a^{(2)}_{ij} - a^{(1)}_{ij})
#'   \left.\frac{\partial\theta}{\partial a_{ij}}\right|_{(A_1 + A_2)/2}.}
#' The approximation is exact for functions that are quadratic in the entries (the midpoint rule),
#' and otherwise has an error of third order in the change. Because the same "sensitivity times
#' change" logic underlies the first-order (differential) variant of structural decomposition
#' analysis, applying \code{ltre_fixed()} with \code{\link{leontief_sensitivity}} attributes a
#' change in value added embodied in exports to changes in individual input coefficients.
#' Compare with the exact, order-independent \code{\link{shapley_decomp}}.
#'
#' @return A matrix of contributions with the dimensions of \code{A1}, with attributes
#'  \code{exact} (\code{stat(A2) - stat(A1)}) and \code{error} (\code{sum(contributions) - exact}).
#' @references Caswell, H. (1989). Analysis of life table response experiments I. Decomposition of
#'  effects on population growth rate. \emph{Ecological Modelling, 46}(3-4), 221-237.
#' @seealso \code{\link{lambda_sensitivity}}, \code{\link{shapley_decomp}}
#' @export
#' @examples
#' L1 <- matrix(c(0, 1.2, 0.8, 0.6, 0, 0, 0, 0.8, 0), 3, byrow = TRUE)
#' L2 <- matrix(c(0, 1.4, 0.9, 0.7, 0, 0, 0, 0.7, 0), 3, byrow = TRUE)
#' C <- ltre_fixed(L1, L2)
#' C
#' sum(C); attr(C, "exact")
ltre_fixed <- function(A1, A2, stat = "lambda", sensitivity = NULL) {
  if (!is.matrix(A1) || !is.matrix(A2) || !identical(dim(A1), dim(A2)))
    stop("'A1' and 'A2' must be matrices of the same dimensions.")
  if (identical(stat, "lambda")) {
    statfun <- function(M) .dominant_eigen(M)$lambda
    if (is.null(sensitivity)) sensitivity <- lambda_sensitivity
  } else if (is.function(stat)) {
    statfun <- stat
    if (is.null(sensitivity)) sensitivity <- function(M) numeric_sensitivity(M, stat)
  } else stop("'stat' must be \"lambda\" or a function.")
  S <- sensitivity((A1 + A2) / 2)
  C <- (A2 - A1) * S
  dimnames(C) <- dimnames(A1)
  exact <- statfun(A2) - statfun(A1)
  attr(C, "exact") <- exact
  attr(C, "error") <- sum(C) - exact
  C
}
