#' Fundamental Matrix of an Absorbing Markov Chain
#'
#' \code{fundamental_matrix()} computes \eqn{N = (I - U)^{-1}} for the transient block \eqn{U} of an
#' absorbing Markov chain; \code{expected_time_in_state()} turns it into expected occupation times
#' (e.g. state-specific and total life expectancy in a multistate life table).
#'
#' @param U numeric square matrix of transition probabilities among the transient (living) states,
#'  in the \emph{column} convention of Caswell (2001): \code{U[i, j]} is the probability of moving
#'  from state \code{j} to state \code{i} in one time step. Column sums are at most 1; the shortfall
#'  \code{1 - colSums(U)} is the probability of absorption (death).
#' @param start optional numeric vector of length \code{nrow(U)}: the initial distribution over
#'  transient states. If \code{NULL}, the expected times are returned for every starting state.
#' @param correction numeric. Subtracted from the total expected time. The default \code{0} counts
#'  the starting time step as a full step (\eqn{1' N}). Use \code{0.5} to approximate life
#'  expectancy with deaths spread uniformly over the last time step, as in a life table with
#'  \eqn{a_x = 1/2}.
#'
#' @details
#' \code{N[i, j]} is the expected number of time steps spent in state \code{i} before absorption,
#' starting from state \code{j}. Because \eqn{N = I + U + U^2 + \dots}, it is computed by exactly the
#' same operation as the Leontief inverse \eqn{B = (I - A)^{-1}} (\code{\link{leontief_inverse}}),
#' and the column sums play the same role: total expected time to absorption here, output
#' multipliers there. This is the isomorphism exploited throughout \code{ddec}.
#'
#' @return \code{fundamental_matrix()}: the matrix \eqn{N} with the dimnames of \code{U}.
#'  \code{expected_time_in_state()}: if \code{start} is \code{NULL}, a matrix with the expected time
#'  in each state (rows) by starting state (columns), plus a final row \code{total}; otherwise a
#'  named vector of expected times in each state plus \code{total}, for the given initial
#'  distribution.
#' @references
#' Caswell, H. (2001). \emph{Matrix Population Models: Construction, Analysis, and Interpretation}
#' (2nd ed.). Sinauer Associates.
#'
#' Kemeny, J. G., & Snell, J. L. (1960). \emph{Finite Markov Chains}. Van Nostrand.
#' @seealso \code{\link{leontief_inverse}}
#' @export
#' @examples
#' # Healthy (H), disabled (D); death is absorbing
#' U <- matrix(c(0.90, 0.10,
#'               0.05, 0.80), 2, byrow = TRUE,
#'             dimnames = list(c("H", "D"), c("H", "D")))
#' fundamental_matrix(U)
#' expected_time_in_state(U)                  # by starting state
#' expected_time_in_state(U, start = c(1, 0)) # starting healthy
fundamental_matrix <- function(U) {
  .check_square(U, "U")
  if (any(U < 0) || any(colSums(U) > 1 + 1e-12))
    stop("'U' must contain probabilities with column sums <= 1 (column convention: U[i, j] = P(j -> i)).")
  .inverse_I_minus(U, "U")
}

#' @rdname fundamental_matrix
#' @export
expected_time_in_state <- function(U, start = NULL, correction = 0) {
  N <- fundamental_matrix(U)
  if (is.null(start)) {
    res <- rbind(N, total = colSums(N) - correction)
    return(res)
  }
  if (length(start) != nrow(U)) stop("length(start) = ", length(start), " does not match nrow(U) = ", nrow(U))
  if (abs(sum(start) - 1) > 1e-8) stop("'start' must be a probability distribution summing to 1.")
  e <- drop(N %*% start)
  names(e) <- rownames(U)
  c(e, total = sum(e) - correction)
}
