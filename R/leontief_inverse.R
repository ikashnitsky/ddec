#' Leontief Inverse and Value-Added Multipliers
#'
#' \code{leontief_inverse()} computes \eqn{B = (I - A)^{-1}} for an input coefficient matrix
#' \eqn{A}; \code{value_added_multipliers()} pre-multiplies it with value-added coefficients,
#' giving \eqn{v' B}.
#'
#' @param A numeric square matrix of input coefficients: \code{A[i, j]} is the input from sector
#'  \code{i} required per unit of output of sector \code{j} (column convention, as in
#'  \code{\link{load_icio}}). Its spectral radius must be below 1.
#' @param v numeric vector of value-added coefficients (value added per unit of output), of length
#'  \code{nrow(A)}. If \code{NULL}, it defaults to \code{1 - colSums(A)}, i.e. everything that is
#'  not an intermediate input is value added.
#' @param y optional numeric vector or matrix of final demand (or exports) with \code{nrow(A)} rows.
#'  If supplied, the function returns \eqn{\mathrm{diag}(v) B y}, the value added generated in
#'  each sector (rows) to satisfy \code{y} (columns).
#'
#' @details
#' \code{B[i, j]} is the gross output of sector \code{i} needed, directly and indirectly, to
#' deliver one unit of final demand for sector \code{j}. The column sums of \code{B} are the output
#' multipliers. Since \eqn{B = I + A + A^2 + \dots}, entry \code{B[i, j]} sums the requirements of
#' \code{i} over all production rounds, exactly as entry \code{N[i, j]} of the fundamental matrix
#' of an absorbing Markov chain sums the expected visits to state \code{i} over all time steps,
#' starting from \code{j} (see \code{\link{fundamental_matrix}}).
#'
#' With the default \code{v}, \eqn{v' B = 1'}: every unit of final demand is fully accounted for by
#' value added somewhere in the system. This is the identity that makes Leontief-based
#' decompositions of exports add up.
#'
#' @return \code{leontief_inverse()}: the matrix \eqn{B}, with the dimnames of \code{A}.
#'  \code{value_added_multipliers()}: the vector \eqn{v' B} if \code{y} is \code{NULL}, otherwise the
#'  matrix \eqn{\mathrm{diag}(v) B y}.
#' @references Leontief, W. (1986). \emph{Input-Output Economics} (2nd ed.). Oxford University Press.
#' @seealso \code{\link{fundamental_matrix}}, \code{\link{leontief_sensitivity}}, \code{\link{load_icio}}
#' @export
#' @examples
#' A <- matrix(c(0.2, 0.1,
#'               0.3, 0.4), 2, byrow = TRUE)
#' B <- leontief_inverse(A)
#' colSums(B)                     # output multipliers
#' value_added_multipliers(A)     # all ones: VA exhausts final demand
#' value_added_multipliers(A, y = c(10, 5))
leontief_inverse <- function(A) .inverse_I_minus(A, "A")

#' @rdname leontief_inverse
#' @export
value_added_multipliers <- function(A, v = NULL, y = NULL) {
  B <- leontief_inverse(A)
  if (is.null(v)) v <- 1 - colSums(A)
  if (length(v) != nrow(A)) stop("length(v) = ", length(v), " does not match nrow(A) = ", nrow(A))
  if (is.null(y)) return(setNames(drop(v %*% B), colnames(A)))
  y <- as.matrix(y)
  if (nrow(y) != nrow(A)) stop("nrow(y) = ", nrow(y), " does not match nrow(A) = ", nrow(A))
  v * (B %*% y)
}
