#' Simulate a Small, Internally Consistent ICIO Table
#'
#' Generates a synthetic inter-country input-output table of class \code{'iot'} that can be passed
#' to \code{\link{load_icio}}. Intended for examples, tests and teaching; the numbers carry no
#' empirical meaning.
#'
#' @param G,N integers. Number of countries and industries.
#' @param va_share numeric in (0, 1). Average value-added share of gross output, i.e. one minus the
#'  column sums of the input coefficient matrix \eqn{A}.
#' @param foreign_share numeric in [0, 1). Share of intermediate inputs sourced from abroad.
#' @param home_bias numeric in [0, 1). Share of each industry's final demand absorbed at home.
#' @param demand_growth numeric vector of length 1 or \code{G}: multiplies final demand by
#'  destination country, e.g. to build a later period from the same draws.
#' @param seed integer. Random seed; the same seed gives the same underlying draws, so tables
#'  differing only in the other arguments are comparable.
#'
#' @details
#' Input coefficients are drawn as uniform random numbers, rescaled so that domestic blocks take
#' \code{(1 - foreign_share)} and foreign blocks \code{foreign_share} of each column's input
#' requirement \code{1 - va_share}. Final demand is drawn and split by destination with the given
#' home bias. Gross output then follows as \eqn{x = (I - A)^{-1} Y 1}, and \code{inter} as
#' \eqn{A\, \mathrm{diag}(x)}, so the table balances exactly.
#'
#' @return A list of class \code{'iot'} with elements \code{inter} (GN x GN), \code{final}
#'  (GN x G), \code{countries}, \code{industries} and \code{output}.
#' @seealso \code{\link{load_icio}}, \code{\link{icio_synth}}
#' @export
#' @examples
#' t1 <- simulate_icio(G = 3, N = 2)
#' m <- load_icio(t1)
#' bm(m)
simulate_icio <- function(G = 3L, N = 2L, va_share = 0.5, foreign_share = 0.25,
                          home_bias = 0.6, demand_growth = 1, seed = 1L) {
  if (va_share <= 0 || va_share >= 1) stop("'va_share' must be in (0, 1).")
  if (foreign_share < 0 || foreign_share >= 1) stop("'foreign_share' must be in [0, 1).")
  if (G < 2L) stop("At least two countries are needed for trade.")
  demand_growth <- rep_len(demand_growth, G)
  old <- if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv())
  on.exit(if (is.null(old)) rm(".Random.seed", envir = globalenv()) else
    assign(".Random.seed", old, envir = globalenv()))
  set.seed(seed)
  GN <- G * N
  countries <- paste0("C", seq_len(G))
  industries <- paste0("I", seq_len(N))
  nam <- as.vector(t(outer(countries, industries, paste, sep = ".")))
  ctry <- rep(seq_len(G), each = N)
  raw <- matrix(stats::runif(GN * GN, 0.2, 1), GN, GN)
  dom <- outer(ctry, ctry, "==")
  # Rescale each column so that domestic and foreign blocks get their target shares
  colscale <- function(M, mask, total) {
    M[!mask] <- 0
    sweep(M, 2L, colSums(M), "/") * total
  }
  A <- colscale(raw, dom, (1 - va_share) * (1 - foreign_share)) +
       colscale(raw, !dom, (1 - va_share) * foreign_share)
  fd_total <- stats::runif(GN, 50, 150)
  share <- matrix((1 - home_bias) / (G - 1), GN, G)
  share[cbind(seq_len(GN), ctry)] <- home_bias
  final <- sweep(fd_total * share, 2L, demand_growth, "*")
  output <- drop(solve(diag(GN) - A, rowSums(final)))
  inter <- sweep(A, 2L, output, "*")
  dimnames(inter) <- list(nam, nam)
  dimnames(final) <- list(nam, countries)
  names(output) <- nam
  structure(list(inter = inter, final = final, countries = countries,
                 industries = industries, output = output), class = "iot")
}
