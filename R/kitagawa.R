#' Kitagawa Two-Factor Decomposition of a Difference in Crude Rates
#'
#' Splits the difference between two crude rates \eqn{R = \sum_i c_i r_i} (e.g. crude death rates,
#' with \eqn{r_i} age-specific rates and \eqn{c_i} the population share of age group \eqn{i}) into a
#' \emph{rate effect} and a \emph{composition effect}.
#'
#' @param rates1,rates2 numeric vectors of group-specific rates in populations 1 and 2.
#' @param weights1,weights2 numeric vectors of group sizes or shares (e.g. population by age) in
#'  populations 1 and 2. They are normalised to shares internally, so counts are fine.
#' @param groups optional labels for the groups (e.g. ages), used as the \code{group} column.
#'
#' @details
#' With \eqn{\Delta r_i = r_{2i} - r_{1i}} and \eqn{\Delta c_i = c_{2i} - c_{1i}},
#' \deqn{R_2 - R_1 = \underbrace{\sum_i \tfrac{c_{1i} + c_{2i}}{2}\,\Delta r_i}_{\text{rate}} +
#'   \underbrace{\sum_i \tfrac{r_{1i} + r_{2i}}{2}\,\Delta c_i}_{\text{composition}}}
#' exactly (Kitagawa 1955). The midpoint weights are what makes the decomposition symmetric: they are
#' the average of the two possible sequential substitutions, i.e. the two-player Shapley value
#' (see \code{\link{shapley_decomp}}). In structural decomposition analysis of input-output
#' tables, the same formula is the "midpoint" or "polar average" decomposition into a technology
#' and a final-demand-structure effect.
#'
#' @return A \code{data.table} with one row per group and columns \code{group}, \code{rate} and
#'  \code{composition} (the group contributions to each effect). The column sums are the two
#'  effects, which add up to \code{attr(, "R2") - attr(, "R1")}, the difference in crude rates.
#' @references Kitagawa, E. M. (1955). Components of a difference between two rates.
#'  \emph{Journal of the American Statistical Association, 50}(272), 1168-1194.
#' @seealso \code{\link{das_gupta_n}}, \code{\link{shapley_decomp}}
#' @export
#' @examples
#' # Crude death rates in two populations with different age structures
#' k <- kitagawa2(rates1 = c(0.001, 0.01, 0.1), rates2 = c(0.0008, 0.008, 0.09),
#'                weights1 = c(50, 35, 15), weights2 = c(40, 35, 25))
#' k
#' colSums(k[, .(rate, composition)])
#' attr(k, "R2") - attr(k, "R1")
kitagawa2 <- function(rates1, rates2, weights1, weights2, groups = NULL) {
  n <- length(rates1)
  if (length(rates2) != n || length(weights1) != n || length(weights2) != n)
    stop("'rates1', 'rates2', 'weights1' and 'weights2' must have the same length.")
  if (any(weights1 < 0) || any(weights2 < 0)) stop("Weights must be non-negative.")
  c1 <- weights1 / sum(weights1)
  c2 <- weights2 / sum(weights2)
  if (is.null(groups)) groups <- if (!is.null(names(rates1))) names(rates1) else seq_len(n)
  res <- data.table(group = groups,
                    rate = (c1 + c2) / 2 * (rates2 - rates1),
                    composition = (rates1 + rates2) / 2 * (c2 - c1))
  setattr(res, "R1", sum(c1 * rates1))
  setattr(res, "R2", sum(c2 * rates2))
  res
}

#' Das Gupta's N-Factor Decomposition
#'
#' Decomposes the difference between two rates that are functions of \eqn{K} factors into \eqn{K}
#' additive factor effects, following Das Gupta (1993). By default the rate is the sum, over
#' cells (e.g. age groups), of the product of the factors - the case Das Gupta treats with
#' closed-form formulas - but any rate function may be supplied.
#'
#' @param factors1,factors2 named lists of numeric vectors, one element per factor, giving the factor
#'  values in populations 1 and 2. All vectors within a list are recycled to a common length (the
#'  number of cells); a scalar factor applies to all cells.
#' @param ratefun the rate as a function of a list shaped like \code{factors1}. The default,
#'  \code{NULL}, uses \eqn{R = \sum_i \prod_k F_{ki}}.
#'
#' @details
#' For multiplicative factors, Das Gupta's effect of factor \eqn{\alpha} with two further factors
#' \eqn{\beta, \gamma} is
#' \eqn{(\alpha_2 - \alpha_1)\left[\tfrac{\beta_1\gamma_1 + \beta_2\gamma_2}{3} +
#' \tfrac{\beta_1\gamma_2 + \beta_2\gamma_1}{6}\right]}, and in general it weights the effect of
#' switching \eqn{\alpha} with the other factors fixed at a mix of the two populations by the
#' probability of that mix arising in a random ordering of the factors. That is the Shapley value,
#' so this function is a thin wrapper around \code{\link{shapley_decomp}}; with two factors it
#' reduces to \code{\link{kitagawa2}}.
#'
#' @return A named numeric vector of factor effects summing to \code{R2 - R1}, with attributes
#'  \code{R1} and \code{R2} (the rates in the two populations).
#' @references Das Gupta, P. (1993). \emph{Standardization and Decomposition of Rates: A User's
#'  Manual}. U.S. Bureau of the Census, Current Population Reports P23-186.
#' @seealso \code{\link{kitagawa2}}, \code{\link{shapley_decomp}}
#' @export
#' @examples
#' # Das Gupta (1993), Example 2.3: birth rate as the product of four factors (1971 vs 1979)
#' f71 <- list(birth_preg = 25.3, preg_actw = 0.214, actw_prop = 0.279, w_prop = 0.949)
#' f79 <- list(birth_preg = 32.7, preg_actw = 0.290, actw_prop = 0.473, w_prop = 0.986)
#' das_gupta_n(f71, f79)
das_gupta_n <- function(factors1, factors2, ratefun = NULL) {
  if (!is.list(factors1) || !is.list(factors2) || is.null(names(factors1)) ||
      !identical(names(factors1), names(factors2)))
    stop("'factors1' and 'factors2' must be lists with identical names.")
  n <- max(lengths(factors1), lengths(factors2))
  rec <- function(fl) lapply(fl, function(z) if (length(z) == n) z else if (length(z) == 1L) rep(z, n)
                             else stop("Factor lengths must be 1 or ", n, "."))
  factors1 <- rec(factors1)
  factors2 <- rec(factors2)
  if (is.null(ratefun)) ratefun <- function(fl) sum(Reduce(`*`, fl))
  s <- shapley_decomp(ratefun, factors1, factors2)
  structure(as.vector(s), names = names(s), R1 = attr(s, "f1"), R2 = attr(s, "f2"))
}
