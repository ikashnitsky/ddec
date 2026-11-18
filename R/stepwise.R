#' Stepwise Replacement Decomposition
#'
#' Decomposes \code{func(pars2) - func(pars1)} into contributions of each parameter by replacing
#' the parameters of population 1 with those of population 2 one at a time, in order (Andreev,
#' Shkolnikov and Begun 2002). A re-implementation of \code{DemoDecomp::stepwise_replacement()}
#' with identical results, built for speed: all parameter sets are assembled as columns of one
#' matrix, the two end points are evaluated once rather than once per direction, and a
#' \code{vectorized} \code{func} is called a single time.
#'
#' @param func a function of a parameter vector returning a numeric scalar, e.g.
#'  \code{\link{life_expectancy}}. If \code{vectorized = TRUE}, it must instead take a matrix with
#'  one parameter set per column and return one value per column.
#' @param pars1,pars2 numeric vectors of parameters (e.g. death rates by age) in the initial and
#'  final state, of equal length.
#' @param symmetrical logical. Also replace in the opposite direction (from \code{pars2} to
#'  \code{pars1}) and average the two, which removes the dependence on which population is the
#'  reference.
#' @param direction character. Order of replacement: \code{"up"} (first to last parameter, e.g.
#'  young to old ages), \code{"down"} (last to first), or \code{"both"} (the average of the two).
#' @param \dots further arguments passed to \code{func}.
#' @param vectorized logical. Is \code{func} vectorised over the columns of a matrix?
#'
#' @details
#' Going "up", the contribution of parameter \eqn{i} is
#' \eqn{f(p_2^{(1..i)}, p_1^{(i+1..n)}) - f(p_2^{(1..i-1)}, p_1^{(i..n)})}. Every single sequence
#' adds up exactly to \eqn{f(p_2) - f(p_1)}, so the average over the requested sequences does too.
#' With \code{func} = life expectancy and \code{symmetrical = FALSE}, \code{direction = "down"}
#' (replacing the oldest ages first) reproduces Arriaga's (1984) decomposition
#' (\code{\link{arriaga_decomp}}) exactly, and \code{direction = "up"} reproduces Arriaga with the
#' two populations swapped (\code{-arriaga_decomp(pars2, pars1)$total}). Stepwise replacement is the
#' sequential decomposition of \code{\link{sequential_decomp}} with one player per parameter, in a
#' fixed (age) order instead of an arbitrary one.
#'
#' Cost: \eqn{n - 1} interior evaluations per sequence plus 2 end points (DemoDecomp: \eqn{n + 1}
#' per sequence). With \code{vectorized = TRUE} they are made in one call.
#'
#' @return A named numeric vector of contributions (names from \code{pars1}), with attributes
#'  \code{f1} and \code{f2}.
#' @references
#' Andreev, E. M., Shkolnikov, V. M., & Begun, A. Z. (2002). Algorithm for decomposition of
#' differences between aggregate demographic measures and its application to life expectancies,
#' healthy life expectancies, parity-progression ratios and total fertility rates.
#' \emph{Demographic Research, 7}(14), 499-522. \doi{10.4054/DemRes.2002.7.14}
#'
#' Riffe, T. DemoDecomp: Decompose Demographic Functions. R package.
#' \url{https://github.com/timriffe/DemoDecomp}
#' @seealso \code{\link{horiuchi_decomp}}, \code{\link{arriaga_decomp}}, \code{\link{shapley_decomp}}
#' @export
#' @examples
#' d0 <- subset(dk_mortality, year == 2000)
#' d1 <- subset(dk_mortality, year == 2019)
#' s <- stepwise_decomp(life_expectancy, d0$mx, d1$mx, vectorized = TRUE)
#' sum(s); attr(s, "f2") - attr(s, "f1")
#' # one-directional, replacing the oldest ages first = Arriaga
#' a <- stepwise_decomp(life_expectancy, d0$mx, d1$mx, symmetrical = FALSE, direction = "down",
#'                      vectorized = TRUE)
#' all.equal(unname(a), arriaga_decomp(d0$mx, d1$mx)$total)
stepwise_decomp <- function(func, pars1, pars2, symmetrical = TRUE, direction = "up", ...,
                            vectorized = FALSE) {
  if (!is.function(func)) stop("'func' must be a function.")
  direction <- match.arg(tolower(direction), c("up", "down", "both"))
  n <- length(pars1)
  if (n == 0L || length(pars2) != n) stop("'pars1' and 'pars2' must have the same positive length.")
  if (!is.numeric(pars1) || !is.numeric(pars2)) stop("'pars1' and 'pars2' must be numeric.")
  p1 <- as.vector(pars1); p2 <- as.vector(pars2)

  # Interior columns k = 1..n-1 of a replacement sequence from a to b. Going up, column k has the
  # first k parameters from b; going down, the last k.
  interior <- function(a, b, up) {
    if (n == 1L) return(matrix(numeric(0), 1L, 0L))
    k <- seq_len(n - 1L)
    sel <- if (up) outer(seq_len(n), k, "<=") else outer(seq_len(n), n - k, ">")
    M <- matrix(a, n, n - 1L)
    M[sel] <- matrix(b, n, n - 1L)[sel]
    M
  }
  seqs <- list()
  if (direction %in% c("up", "both")) {
    seqs$up12 <- list(M = interior(p1, p2, TRUE), from = 1L, up = TRUE)
    if (symmetrical) seqs$up21 <- list(M = interior(p2, p1, TRUE), from = 2L, up = TRUE)
  }
  if (direction %in% c("down", "both")) {
    seqs$dn12 <- list(M = interior(p1, p2, FALSE), from = 1L, up = FALSE)
    if (symmetrical) seqs$dn21 <- list(M = interior(p2, p1, FALSE), from = 2L, up = FALSE)
  }
  nint <- n - 1L
  all_M <- do.call(cbind, c(list(cbind(p1, p2)), lapply(seqs, `[[`, "M")))
  vals <- .eval_columns(func, all_M, vectorized, ...)
  f1 <- vals[1L]; f2 <- vals[2L]
  dec <- vapply(seq_along(seqs), function(s) {
    v <- vals[2L + (s - 1L) * nint + seq_len(nint)]
    sq <- seqs[[s]]
    path <- if (sq$from == 1L) c(f1, v, f2) else c(f2, v, f1)
    e <- diff(path)
    if (sq$from == 2L) e <- -e
    if (sq$up) e else rev(e)
  }, numeric(n))
  out <- if (is.matrix(dec)) rowMeans2(dec) else mean(dec)
  structure(setNames(out, names(pars1)), f1 = f1, f2 = f2)
}

# Evaluate func on every column of M: once on the whole matrix if vectorised, else per column.
.eval_columns <- function(func, M, vectorized, ...) {
  if (vectorized) {
    v <- func(M, ...)
    if (!is.numeric(v) || length(v) != ncol(M))
      stop("With vectorized = TRUE, 'func' must return one numeric value per column (got ",
           length(v), " for ", ncol(M), " columns).")
    return(as.vector(v))
  }
  vapply(seq_len(ncol(M)), function(j) {
    r <- func(M[, j], ...)
    if (!is.numeric(r) || length(r) != 1L) stop("'func' must return a numeric scalar.")
    r
  }, numeric(1), USE.NAMES = FALSE)
}
