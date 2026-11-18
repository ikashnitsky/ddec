#' Harmonised Components of Gross Exports Across GVC Decompositions
#'
#' Runs the Leontief, KWW, WWZ and Borin-Mancini decompositions on the same 'icio' object and
#' returns their terms in one long \code{data.table}, each term mapped to a common
#' domestic/foreign content and value-added category, so the methods can be compared side by side.
#'
#' @param x an 'icio' object from \code{\link{load_icio}}.
#' @param methods character. Any of \code{"leontief"}, \code{"kww"}, \code{"wwz"} and
#'  \code{"bm"} (exporter perspective, source approach). Methods that do not support the requested
#'  \code{level} are dropped with a message.
#' @param level character. \code{"country"} (all four methods), \code{"sector"} (exporting
#'  country-industry: Leontief, WWZ, BM) or \code{"bilateral"} (exporting country-industry by
#'  importing country: WWZ, BM).
#'
#' @details
#' Every method's terms add up to gross exports. The mapping to common categories is:
#' \tabular{lllll}{
#'  \strong{category} \tab \strong{content} \tab \strong{bm} \tab \strong{kww} \tab \strong{wwz} \cr
#'  VAX \tab domestic \tab VAX \tab DVA_FIN + DVA_INT + DVA_INTrex \tab DVA_FIN + DVA_INT + DVA_INTrexI1 + DVA_INTrexF + DVA_INTrexI2 \cr
#'  REF \tab domestic \tab REF \tab RDV_FIN + RDV_INT \tab RDV_INT + RDV_FIN + RDV_FIN2 \cr
#'  DDC \tab domestic \tab DDC \tab DDC \tab DDC_FIN + DDC_INT \cr
#'  FVA \tab foreign \tab FVA \tab FVA_FIN + FVA_INT \tab OVA_FIN + MVA_FIN + OVA_INT + MVA_INT \cr
#'  FDC \tab foreign \tab FDC \tab FDC \tab ODC + MDC \cr
#' }
#' The Leontief (Hummels-Ishii-Yi) decomposition only splits exports into domestic content
#' (\code{DC}) and foreign content (\code{FC}) by origin country, with no separation of double
#' counting. At the country level, its domestic content equals Borin-Mancini's \code{DC}.
#'
#' @return A long \code{data.table} with columns \code{method}, \code{Exporting_Country},
#'  (\code{Exporting_Industry}, \code{Importing_Country} depending on \code{level}), \code{term}
#'  (the method's own term), \code{category}, \code{content} and \code{value}.
#' @seealso \code{\link{bm}}, \code{\link{kww}}, \code{\link{wwz}}, \code{\link{leontief}}
#' @export
#' @examples
#' m <- load_icio(leather)
#' g <- gvc_components(m)
#' g[, .(GEXP = sum(value)), by = .(method, Exporting_Country)]
#' g[, .(value = sum(value)), by = .(method, content)]
gvc_components <- function(x, methods = c("leontief", "kww", "wwz", "bm"),
                           level = c("country", "sector", "bilateral")) {
  if (!inherits(x, "icio")) stop("x must be an object of class 'icio' created by load_icio().")
  level <- match.arg(level)
  methods <- match.arg(methods, several.ok = TRUE)
  supported <- list(country = c("leontief", "kww", "wwz", "bm"),
                    sector = c("leontief", "wwz", "bm"),
                    bilateral = c("wwz", "bm"))[[level]]
  drop <- setdiff(methods, supported)
  if (length(drop)) message("Dropping method(s) not available at level '", level, "': ",
                            paste(drop, collapse = ", "))
  methods <- intersect(methods, supported)
  if (!length(methods)) stop("No method supports level '", level, "'.")
  ids <- c("Exporting_Country", if (level != "country") "Exporting_Industry",
           if (level == "bilateral") "Importing_Country")

  res <- lapply(methods, function(meth) {
    d <- switch(meth,
      bm = .gvc_long(bm(x, aggregation = level), ids, .gvc_map$bm),
      kww = {
        k <- kww(x)
        data.table::setnames(k, "Country", "Exporting_Country")
        .gvc_long(k, ids, .gvc_map$kww)
      },
      wwz = {
        w <- wwz(x)[as.character(Exporting_Country) != as.character(Importing_Country)]
        terms <- names(.gvc_map$wwz)
        w <- w[, lapply(.SD, sum), by = ids, .SDcols = terms]
        .gvc_long(w, ids, .gvc_map$wwz)
      },
      leontief = {
        l <- leontief(x)
        l[, term := ifelse(as.character(Source_Country) == as.character(Using_Country), "DC", "FC")]
        data.table::setnames(l, c("Using_Country", "Using_Industry"),
                             c("Exporting_Country", "Exporting_Industry"))
        l <- l[, .(value = sum(FVAX)), by = c(ids, "term")]
        l[, `:=`(category = term, content = ifelse(term == "DC", "domestic", "foreign"))]
        l
      })
    d[, method := meth]
    data.table::setcolorder(d, c("method", ids, "term", "category", "content", "value"))
    d
  })
  res <- rbindlist(res)
  res[, method := factor(method, levels = methods)]
  res[]
}

utils::globalVariables(c("Exporting_Country", "Importing_Country", "Source_Country", "Using_Country",
                         "FVAX", "term", "category", "content", "value", "method", ".SD", ".",
                         ":=", "rate", "composition"))

.gvc_categories <- c(VAX = "domestic", REF = "domestic", DDC = "domestic",
                     FVA = "foreign", FDC = "foreign")

.gvc_map <- list(
  bm = c(VAX = "VAX", REF = "REF", DDC = "DDC", FVA = "FVA", FDC = "FDC"),
  kww = c(DVA_FIN = "VAX", DVA_INT = "VAX", DVA_INTrex = "VAX", RDV_FIN = "REF", RDV_INT = "REF",
          DDC = "DDC", FVA_FIN = "FVA", FVA_INT = "FVA", FDC = "FDC"),
  wwz = c(DVA_FIN = "VAX", DVA_INT = "VAX", DVA_INTrexI1 = "VAX", DVA_INTrexF = "VAX",
          DVA_INTrexI2 = "VAX", RDV_INT = "REF", RDV_FIN = "REF", RDV_FIN2 = "REF",
          DDC_FIN = "DDC", DDC_INT = "DDC", OVA_FIN = "FVA", MVA_FIN = "FVA", OVA_INT = "FVA",
          MVA_INT = "FVA", ODC = "FDC", MDC = "FDC"))

.gvc_long <- function(d, ids, map) {
  d <- data.table::melt(d[, c(ids, names(map)), with = FALSE], id.vars = ids,
                        variable.name = "term", value.name = "value", variable.factor = FALSE)
  d[, category := unname(map[term])]
  d[, content := unname(.gvc_categories[category])]
  d
}
