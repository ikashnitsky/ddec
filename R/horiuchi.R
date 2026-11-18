#' Horiuchi (Pseudo-Continuous) Decomposition
#'
#' Decomposes \code{func(pars2) - func(pars1)} into contributions of each parameter (or group of
#' parameters) by letting all parameters change gradually and simultaneously along a straight
#' line from \code{pars1} to \code{pars2}, and integrating the partial effects numerically
#' (Horiuchi, Wilmoth and Pletcher 2008). A re-implementation of \code{DemoDecomp::horiuchi()}
#' (including its \code{components} grouping) with identical results, built for speed: the
#' \eqn{2 \times N \times} (number of components) parameter sets are assembled as matrix columns,
#' and a \code{vectorized} \code{func} is called once per block of steps instead of once per set.
#'
#' @inheritParams stepwise_decomp
#' @param N integer. Number of intervals for the numerical integration. Larger \code{N} gives a
#'  smaller residual (it shrinks with \eqn{1/N^2}); 20 is usually plenty.
#' @param components optional vector with one label per parameter. Parameters sharing a label are
#'  perturbed together and receive one joint contribution (e.g. all ages of one cause of death).
#' @param max_elements numeric. With \code{vectorized = TRUE}, the largest matrix (in elements)
#'  passed to \code{func} in one call; steps are processed in blocks below this size.
#'
#' @details
#' Along the path \eqn{p(t) = p_1 + t (p_2 - p_1)}, the contribution of component \eqn{c} is
#' \eqn{\int_0^1 \partial f/\partial p_c \cdot (p_{2c} - p_{1c})\, dt}, approximated with \code{N}
#' midpoints and central differences of half a step on either side. Unlike stepwise replacement,
#' the result does not depend on any ordering of the parameters. Because the integral is
#' approximated, contributions add up to \eqn{f(p_2) - f(p_1)} only up to a small residual. In
#' contrast with \code{\link{ltre_fixed}}, which evaluates the derivative only at the midpoint,
#' the derivative is averaged along the whole path.
#'
#' @return A named numeric vector of contributions (one per parameter, or per unique label of
#'  \code{components}), with attributes \code{f1}, \code{f2} and \code{residual}
#'  (\code{sum(contributions) - (f2 - f1)}).
#' @references
#' Horiuchi, S., Wilmoth, J. R., & Pletcher, S. D. (2008). A decomposition method based on a model
#' of continuous change. \emph{Demography, 45}(4), 785-801. \doi{10.1353/dem.0.0033}
#'
#' Riffe, T. DemoDecomp: Decompose Demographic Functions. R package.
#' \url{https://github.com/timriffe/DemoDecomp}
#' @seealso \code{\link{stepwise_decomp}}, \code{\link{ltre_fixed}}, \code{\link{shapley_decomp}}
#' @export
#' @examples
#' d0 <- subset(dk_mortality, year == 2000)
#' d1 <- subset(dk_mortality, year == 2019)
#' h <- horiuchi_decomp(life_expectancy, d0$mx, d1$mx, N = 20, vectorized = TRUE)
#' sum(h); attr(h, "residual")
#' # contributions of broad age groups
#' grp <- cut(d0$age, c(0, 15, 45, 65, 80, Inf), right = FALSE)
#' horiuchi_decomp(life_expectancy, d0$mx, d1$mx, components = grp, vectorized = TRUE)
horiuchi_decomp <- function(func, pars1, pars2, N = 20L, ..., components = NULL,
                            vectorized = FALSE, max_elements = 1e7) {
  if (!is.function(func)) stop("'func' must be a function.")
  nn <- length(pars1)
  if (nn == 0L || length(pars2) != nn) stop("'pars1' and 'pars2' must have the same positive length.")
  if (!is.numeric(pars1) || !is.numeric(pars2)) stop("'pars1' and 'pars2' must be numeric.")
  if (length(N) != 1L || !is.numeric(N) || !is.finite(N) || N < 1 || N != floor(N))
    stop("'N' must be a positive integer.")
  grouped <- !is.null(components)
  if (grouped) {
    if (length(components) != nn || anyNA(components))
      stop("'components' must have one non-missing label per parameter.")
    labs <- unique(as.vector(if (is.factor(components)) as.character(components) else components))
    cid <- match(as.vector(if (is.factor(components)) as.character(components) else components), labs)
  } else {
    labs <- names(pars1)
    cid <- seq_len(nn)
  }
  n <- if (grouped) length(labs) else nn
  p1 <- as.vector(pars1); p2 <- as.vector(pars2)
  d <- p2 - p1
  # Midpoints of the N steps along the path (nn x N), and the half-step perturbation of each
  # component (nn x n, one column per component).
  X <- p1 + outer(d, (seq_len(N) - 0.5) / N)
  D <- matrix(0, nn, n)
  D[cbind(seq_len(nn), cid)] <- d / (2 * N)   # used by the scalar path

  if (vectorized) {
    per_step <- 2 * nn * n
    block <- max(1L, min(N, floor(max_elements / per_step)))
    cc <- numeric(n)
    # Each column differs from its step's midpoint only in the entries of one component, so
    # copy the midpoints once and add the half steps at those entries only (no dense D copy).
    nz <- seq_len(nn) + (cid - 1L) * nn            # linear index of entry r in its column
    hd <- d / (2 * N)
    for (start in seq(1L, N, by = block)) {
      js <- start:min(N, start + block - 1L)
      nb <- length(js)
      P <- X[, rep(rep(js, each = n), 2L), drop = FALSE]  # [plus block | minus block]
      off <- rep((seq_len(nb) - 1L) * nn * n, each = nn)
      ip <- nz + off
      im <- ip + nb * nn * n
      P[ip] <- P[ip] + hd
      P[im] <- P[im] - hd
      v <- .eval_columns(func, P, TRUE, ...)
      h <- nb * n
      cc <- cc + rowSums2(matrix(v[seq_len(h)] - v[h + seq_len(h)], n))
    }
  } else {
    cc <- numeric(n)
    for (j in seq_len(N)) {
      xj <- X[, j]
      for (i in seq_len(n)) {
        cc[i] <- cc[i] + func(xj + D[, i], ...) - func(xj - D[, i], ...)
      }
    }
  }
  f12 <- .eval_columns(func, cbind(p1, p2), vectorized, ...)
  structure(setNames(cc, labs), f1 = f12[1L], f2 = f12[2L],
            residual = sum(cc) - (f12[2L] - f12[1L]))
}
