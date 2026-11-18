#' Period Life Table from Death Rates
#'
#' Builds a period life table from age-specific death rates with the usual constant-\eqn{a_x}
#' assumptions. Used by \code{\link{arriaga_decomp}}.
#'
#' @param mx numeric vector of age-specific death rates; the last element refers to the open age
#'  interval.
#' @param nx numeric. Width of each age interval (recycled); the last value is ignored.
#' @param ax optional numeric vector of the average time lived in the interval by those dying in
#'  it. Defaults to \code{nx / 2}, with the open interval closed out at \code{1 / mx}. Supply it
#'  explicitly to use, e.g., an Andreev-Kingkade infant \eqn{a_0}.
#' @param age optional numeric vector of starting ages, used only for the \code{age} column.
#'  Defaults to \code{c(0, cumsum(nx))[seq_along(mx)]}.
#' @param radix numeric. \eqn{l_0}.
#' @return A \code{data.table} with columns \code{age}, \code{nx}, \code{mx}, \code{ax}, \code{qx},
#'  \code{lx}, \code{dx}, \code{Lx}, \code{Tx}, \code{ex}.
#' @references Preston, S. H., Heuveline, P., & Guillot, M. (2001). \emph{Demography: Measuring and
#'  Modeling Population Processes}. Blackwell.
#' @seealso \code{\link{arriaga_decomp}}
#' @export
#' @examples
#' lt <- life_table(mx = c(0.01, 0.002, 0.005, 0.02, 0.1), nx = c(1, 4, 20, 25, Inf))
#' lt
life_table <- function(mx, nx = 1, ax = NULL, age = NULL, radix = 1) {
  n <- length(mx)
  if (n < 1L || anyNA(mx) || any(mx < 0)) stop("'mx' must be non-negative and non-missing.")
  if (mx[n] <= 0) stop("The death rate of the open age interval must be positive.")
  nx <- rep_len(nx, n)
  if (is.null(age)) age <- c(0, cumsum(nx[-n]))
  if (is.null(ax)) {
    ax <- nx / 2
    ax[n] <- 1 / mx[n]
  } else if (length(ax) != n) stop("length(ax) must equal length(mx).")
  qx <- nx * mx / (1 + (nx - ax) * mx)
  qx[n] <- 1
  qx <- pmin(qx, 1)
  lx <- radix * cumprod(c(1, 1 - qx[-n]))
  dx <- lx * qx
  Lx <- nx * lx - (nx - ax) * dx
  Lx[n] <- lx[n] * ax[n]
  Tx <- rev(cumsum(rev(Lx)))
  data.table(age = age, nx = nx, mx = mx, ax = ax, qx = qx, lx = lx, dx = dx,
             Lx = Lx, Tx = Tx, ex = Tx / lx)
}

#' Arriaga Decomposition of a Difference in Life Expectancy
#'
#' Decomposes the difference in life expectancy at birth between two life tables into
#' age-specific contributions, each split into a direct, an indirect and an interaction effect
#' (Arriaga 1984).
#'
#' @param mx1,mx2 numeric vectors of age-specific death rates in populations (or periods) 1 and 2.
#' @param nx numeric. Width of the age intervals, see \code{\link{life_table}}.
#' @param ax1,ax2 optional \eqn{a_x} vectors for the two life tables, see \code{\link{life_table}}.
#' @param age optional starting ages, see \code{\link{life_table}}.
#'
#' @details
#' With \eqn{l_0 = 1}, the total contribution of age group \eqn{[x, x+n)} is
#' \deqn{\Delta_x = \underbrace{l^1_x \left(\frac{L^2_x}{l^2_x} - \frac{L^1_x}{l^1_x}\right)}_{\text{direct}}
#' + \underbrace{T^2_{x+n}\left(\frac{l^1_x}{l^2_x} - \frac{l^1_{x+n}}{l^2_{x+n}}\right)}_{\text{indirect + interaction}},}
#' and for the open interval only the direct effect \eqn{l^1_x (T^2_x / l^2_x - T^1_x / l^1_x)} is
#' present. The indirect effect is the additional years lived beyond \eqn{x+n} by the extra
#' survivors to \eqn{x+n}, at the \emph{old} mortality above \eqn{x+n}:
#' \eqn{T^1_{x+n}\left(\frac{l^1_x\, l^2_{x+n}}{l^2_x\, l^1_{x+n}} - 1\right)}; the interaction
#' effect is the remainder. The contributions sum exactly to \eqn{e^2_0 - e^1_0}.
#'
#' Arriaga's method is a sequential (one-directional) decomposition: swapping the two populations
#' changes the age pattern of contributions, but not their sum.
#'
#' @return A \code{data.table} with columns \code{age}, \code{direct}, \code{indirect},
#'  \code{interaction} and \code{total}, with attributes \code{e01} and \code{e02}.
#' @references Arriaga, E. E. (1984). Measuring and explaining the change in life expectancies.
#'  \emph{Demography, 21}(1), 83-96.
#'
#' Preston, S. H., Heuveline, P., & Guillot, M. (2001). \emph{Demography: Measuring and Modeling
#' Population Processes}. Blackwell.
#' @seealso \code{\link{life_table}}
#' @export
#' @examples
#' mx1 <- c(0.010, 0.002, 0.005, 0.020, 0.10)
#' mx2 <- c(0.005, 0.001, 0.004, 0.015, 0.09)
#' a <- arriaga_decomp(mx1, mx2, nx = c(1, 4, 20, 25, Inf))
#' a
#' sum(a$total); attr(a, "e02") - attr(a, "e01")
arriaga_decomp <- function(mx1, mx2, nx = 1, ax1 = NULL, ax2 = NULL, age = NULL) {
  if (length(mx1) != length(mx2)) stop("'mx1' and 'mx2' must have the same length.")
  t1 <- life_table(mx1, nx = nx, ax = ax1, age = age)
  t2 <- life_table(mx2, nx = nx, ax = ax2, age = age)
  n <- length(mx1)
  l1 <- t1$lx; l2 <- t2$lx
  nxt <- function(z, fill) c(z[-1L], fill)
  direct <- l1 * (t2$Lx / l2 - t1$Lx / l1)
  other <- nxt(t2$Tx, 0) * (l1 / l2 - nxt(l1, 0) / nxt(l2, 1))
  indirect <- nxt(t1$Tx, 0) * (l1 * nxt(l2, 1) / (l2 * nxt(l1, 1)) - 1)
  indirect[n] <- 0
  res <- data.table(age = t1$age, direct = direct, indirect = indirect,
                    interaction = other - indirect, total = direct + other)
  setattr(res, "e01", t1$ex[1L])
  setattr(res, "e02", t2$ex[1L])
  res
}
