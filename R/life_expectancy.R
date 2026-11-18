#' Life Expectancy at Birth, Vectorised over Sets of Death Rates
#'
#' Computes \eqn{e_0} from age-specific death rates with the same formulas as
#' \code{\link{life_table}}, for a single schedule (vector) or many schedules at once (matrix with
#' one schedule per column). The matrix form is what makes \code{\link{stepwise_decomp}} and
#' \code{\link{horiuchi_decomp}} fast: pass \code{func = life_expectancy, vectorized = TRUE}.
#'
#' @param mx numeric vector of death rates by age (the last element is the open interval), or a
#'  matrix with ages in rows and one schedule per column.
#' @param nx numeric. Width of the age intervals (recycled to the number of ages).
#' @param ax optional average time lived in the interval by those dying, as a vector (one value
#'  per age, used for every column) or a matrix of the same dimensions as \code{mx}. Defaults to
#'  \code{nx / 2} with the open interval closed out at \code{1 / mx}, as in \code{\link{life_table}}.
#' @return A numeric vector with one \eqn{e_0} per column of \code{mx} (length 1 for a vector).
#' @details Uses \code{matrixStats::colCumprods()} and \code{colSums2()}, so the cost of one call
#'  on a matrix of \eqn{k} schedules is close to that of \eqn{k} vector operations, with no
#'  per-schedule R function-call overhead.
#' @seealso \code{\link{life_table}}, \code{\link{stepwise_decomp}}, \code{\link{horiuchi_decomp}}
#' @export
#' @examples
#' mx <- c(0.01, 0.002, 0.005, 0.02, 0.1)
#' life_expectancy(mx)
#' life_table(mx)$ex[1]
#' life_expectancy(cbind(mx, mx * 0.9))
life_expectancy <- function(mx, nx = 1, ax = NULL) {
  M <- if (is.matrix(mx)) mx else matrix(mx, ncol = 1L)
  n <- nrow(M)
  if (n < 1L || anyNA(M) || any(M < 0)) stop("'mx' must be non-negative and non-missing.")
  if (any(M[n, ] <= 0)) stop("The death rate of the open age interval must be positive.")
  nx <- rep_len(nx, n)
  if (is.null(ax)) {
    ax <- matrix(nx / 2, n, ncol(M))
    ax[n, ] <- 1 / M[n, ]
  } else if (is.matrix(ax)) {
    if (!identical(dim(ax), dim(M))) stop("A matrix 'ax' must have the dimensions of 'mx'.")
  } else if (length(ax) == n) {
    ax <- matrix(ax, n, ncol(M))
  } else stop("'ax' must have one value per age, or the dimensions of 'mx'.")
  qx <- nx * M / (1 + (nx - ax) * M)
  qx[n, ] <- 1
  qx[qx > 1] <- 1
  # survivorship l_x (radix 1): l_0 = 1, l_x = prod_{y < x} (1 - q_y)
  lx <- if (n > 1L) rbind(1, colCumprods(1 - qx[-n, , drop = FALSE])) else matrix(1, 1L, ncol(M))
  Lx <- nx * lx - (nx - ax) * (lx * qx)
  Lx[n, ] <- lx[n, ] * ax[n, ]
  colSums2(Lx)
}
