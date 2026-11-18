#' Shapley (All-Orderings) Decomposition of a Change in Any Function
#'
#' Decomposes \eqn{f(x_2) - f(x_1)} into additive contributions of groups of inputs ("players") by
#' averaging the sequential-substitution effect of each player over all orderings in which the
#' players can be switched from their \code{x1} to their \code{x2} values. The result is unique,
#' order-independent and exactly additive. \code{sequential_decomp()} gives the (order-dependent)
#' effects for a single ordering, and \code{all_orderings()} tabulates them for every ordering.
#'
#' @param f a function taking a single argument shaped like \code{x1} (a list or an atomic
#'  vector/matrix) and returning a numeric scalar.
#' @param x1,x2 the inputs in the initial and final state. Either a (preferably named) list of
#'  numeric vectors/matrices, or a single numeric vector/matrix. They must have identical structure.
#' @param groups optional player definition. By default each element of a list \code{x1} is one
#'  player (and a non-list \code{x1} is a single player, which is rarely useful). To split
#'  inputs more finely, pass a list with the same structure as \code{x1} whose elements are
#'  character (or integer) vectors/matrices of the same dimensions, labelling the player each
#'  entry belongs to; for a non-list \code{x1}, a single such vector/matrix. Labels may be shared
#'  across list elements.
#' @param order character. The order in which players are switched in \code{sequential_decomp()};
#'  defaults to the order in which they first appear.
#'
#' @details
#' For a set of players \eqn{K}, the contribution of player \eqn{k} is
#' \deqn{\phi_k = \sum_{S \subseteq K \setminus \{k\}} \frac{|S|!\,(|K| - |S| - 1)!}{|K|!}
#'   \left[f(x^{S \cup \{k\}}) - f(x^{S})\right],}
#' where \eqn{x^S} takes the \code{x2} values for players in \eqn{S} and the \code{x1} values
#' otherwise. Computation uses this subset form, which needs \eqn{2^{|K|}} evaluations of \code{f}
#' (cached), so keep the number of players small (say, at most 15).
#'
#' This is the logic of Das Gupta's (1993) multi-factor standardisation (\code{\link{das_gupta_n}}),
#' of the "average of all \eqn{n!} polar decompositions" in structural decomposition analysis
#' (Dietzenbacher and Los 1998), and of the Shapley-Shorrocks decomposition (Shorrocks 2013).
#'
#' @return \code{shapley_decomp()} and \code{sequential_decomp()}: a named numeric vector of player
#'  contributions summing to \code{f(x2) - f(x1)}, with attributes \code{f1 = f(x1)} and
#'  \code{f2 = f(x2)}. \code{all_orderings()}: a \code{data.table} with one row per (ordering,
#'  player) and columns \code{ordering}, \code{player}, \code{effect}, \code{shapley}.
#' @references
#' Shapley, L. S. (1953). A value for n-person games. In H. W. Kuhn & A. W. Tucker (Eds.),
#' \emph{Contributions to the Theory of Games II} (pp. 307-317). Princeton University Press.
#'
#' Shorrocks, A. F. (2013). Decomposition procedures for distributional analysis: a unified
#' framework based on the Shapley value. \emph{Journal of Economic Inequality, 11}(1), 99-126.
#'
#' Dietzenbacher, E., & Los, B. (1998). Structural decomposition techniques: sense and
#' sensitivity. \emph{Economic Systems Research, 10}(4), 307-324.
#'
#' Das Gupta, P. (1993). \emph{Standardization and Decomposition of Rates: A User's Manual}. U.S.
#' Bureau of the Census, Current Population Reports P23-186.
#' @seealso \code{\link{das_gupta_n}}, \code{\link{kitagawa2}}
#' @export
#' @examples
#' # A product of three factors
#' f <- function(p) p$a * p$b * p$c
#' x1 <- list(a = 1, b = 2, c = 3)
#' x2 <- list(a = 2, b = 3, c = 5)
#' s <- shapley_decomp(f, x1, x2)
#' s; sum(s) == f(x2) - f(x1)
#'
#' # Sequential substitution depends on the ordering, Shapley does not
#' sequential_decomp(f, x1, x2, order = c("a", "b", "c"))
#' sequential_decomp(f, x1, x2, order = c("c", "b", "a"))
#' all_orderings(f, x1, x2)
shapley_decomp <- function(f, x1, x2, groups = NULL) {
  g <- .shapley_game(f, x1, x2, groups)
  K <- length(g$players)
  w <- factorial(0:(K - 1L)) * factorial((K - 1L):0) / factorial(K)  # weight by |S|
  phi <- vapply(seq_len(K), function(k) {
    bit <- bitwShiftL(1L, k - 1L)
    S <- which(bitwAnd(g$masks, bit) == 0L)        # subsets without k
    sum(w[g$size[S] + 1L] * (g$value[g$masks[S] + bit + 1L] - g$value[g$masks[S] + 1L]))
  }, numeric(1))
  structure(setNames(phi, g$players), f1 = g$value[1L], f2 = g$value[length(g$value)])
}

#' @rdname shapley_decomp
#' @export
sequential_decomp <- function(f, x1, x2, groups = NULL, order = NULL) {
  g <- .shapley_game(f, x1, x2, groups)
  .sequential(g, order)
}

#' @rdname shapley_decomp
#' @export
all_orderings <- function(f, x1, x2, groups = NULL) {
  g <- .shapley_game(f, x1, x2, groups)
  K <- length(g$players)
  if (K > 8L) stop("all_orderings() enumerates ", K, "! orderings; use at most 8 players.")
  perms <- .permutations(K)
  sh <- shapley_decomp(f, x1, x2, groups)
  res <- lapply(seq_len(nrow(perms)), function(r) {
    ord <- g$players[perms[r, ]]
    e <- .sequential(g, ord)
    data.table(ordering = paste(ord, collapse = " > "), player = g$players,
               effect = unname(e[g$players]), shapley = unname(sh))
  })
  rbindlist(res)
}

# --- internals ---------------------------------------------------------------

# Build the cooperative game: players, and f evaluated on all 2^K subsets (bitmasks).
.shapley_game <- function(f, x1, x2, groups) {
  if (!is.function(f)) stop("'f' must be a function.")
  wrapped <- !is.list(x1)
  if (wrapped) {
    if (is.list(x2)) stop("'x1' and 'x2' must have the same structure.")
    x1 <- list(x1); x2 <- list(x2)
    if (!is.null(groups)) groups <- list(groups)
  }
  if (length(x1) != length(x2) || !identical(lengths(x1), lengths(x2)))
    stop("'x1' and 'x2' must have the same structure.")
  if (is.null(groups)) {
    nm <- names(x1)
    if (is.null(nm) || any(nm == "")) nm <- paste0("x", seq_along(x1))
    groups <- lapply(seq_along(x1), function(j) rep(nm[j], length(x1[[j]])))
  } else {
    if (!is.list(groups) || length(groups) != length(x1) || !identical(lengths(groups), lengths(x1)))
      stop("'groups' must have the same structure as 'x1'.")
    groups <- lapply(groups, function(z) as.character(as.vector(z)))
  }
  players <- unique(unlist(groups, use.names = FALSE))
  K <- length(players)
  if (K > 20L) stop(K, " players means 2^", K, " evaluations of f; group the inputs more coarsely.")
  idx <- lapply(groups, match, players)
  fx <- function(x) if (wrapped) f(x[[1L]]) else f(x)
  masks <- 0:(2^K - 1)
  value <- vapply(masks, function(m) {
    inS <- bitwAnd(m, bitwShiftL(1L, 0:(K - 1L))) != 0L
    x <- x1
    for (j in seq_along(x)) {
      sel <- inS[idx[[j]]]
      if (any(sel)) x[[j]][sel] <- x2[[j]][sel]
    }
    r <- fx(x)
    if (!is.numeric(r) || length(r) != 1L) stop("'f' must return a numeric scalar.")
    r
  }, numeric(1))
  size <- vapply(masks, function(m) sum(bitwAnd(m, bitwShiftL(1L, 0:(K - 1L))) != 0L), integer(1))
  list(players = players, value = value, masks = masks, size = size)
}

.sequential <- function(g, order) {
  if (is.null(order)) order <- g$players
  if (!setequal(order, g$players) || length(order) != length(g$players))
    stop("'order' must be a permutation of the players: ", paste(g$players, collapse = ", "))
  bits <- bitwShiftL(1L, match(order, g$players) - 1L)
  cum <- c(0L, cumsum(bits))
  eff <- g$value[cum[-1L] + 1L] - g$value[cum[-length(cum)] + 1L]
  names(eff) <- order
  structure(eff[g$players], f1 = g$value[1L], f2 = g$value[length(g$value)])
}

.permutations <- function(n) {
  if (n == 1L) return(matrix(1L))
  sub <- .permutations(n - 1L)
  do.call(rbind, lapply(seq_len(n), function(i) cbind(i, matrix(setdiff(seq_len(n), i)[sub], ncol = n - 1L))))
}
