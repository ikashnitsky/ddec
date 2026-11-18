#' @name ddec-package
#' @title Decomposition Methods Across Trade and Demography
#' @author
#' Ilya Kashnitsky (demographic decompositions and the bridging layer)\cr
#' Sebastian Krantz, Bastiaan Quast, Fei Wang, Victor Stolzenburg (GVC decompositions, from \code{icio})
#' @description \code{ddec} puts two families of decomposition methods side by side and shows,
#' with code and numbers, that they share their machinery:
#'
#' \itemize{
#'  \item \strong{Global value chain (GVC) decompositions} of gross exports from inter-country
#'  input-output (ICIO) tables: Leontief / Hummels-Ishii-Yi (2001), Koopman-Wang-Wei (2014),
#'  Wang-Wei-Zhu (2013) and Borin-Mancini (2019). These are inherited verbatim from the R package
#'  \code{icio}, of which \code{ddec} is a fork.
#'  \item \strong{Demographic decompositions}: Kitagawa (1955), Das Gupta (1993), Arriaga (1984)
#'  and fixed-design life table response experiments (LTRE, Caswell 1989).
#'  \item \strong{A bridging layer}: the Leontief inverse \eqn{(I - A)^{-1}} and the fundamental
#'  matrix \eqn{(I - U)^{-1}} of an absorbing Markov chain are the same object; Shapley
#'  (all-orderings) averaging solves the non-uniqueness of multi-factor decompositions in both fields;
#'  LTRE and Leontief-based attribution are both "sensitivity times parameter change".
#' }
#'
#' @section Contents:
#' \strong{GVC decompositions} (operating on an 'icio' object)
#'
#' \code{\link[=load_icio]{load_icio()}}, \code{\link[=load_icio_csv]{load_icio_csv()}},
#' \code{\link[=simulate_icio]{simulate_icio()}}\cr
#' \code{\link[=bm]{bm()}}, \code{\link[=leontief]{leontief()}}, \code{\link[=kww]{kww()}},
#' \code{\link[=wwz]{wwz()}}, \code{\link[=wwz2kww]{wwz2kww()}}, \code{\link[=decomp]{decomp()}}\cr
#' \code{\link[=gvc_components]{gvc_components()}} (all four methods in one tidy table)
#'
#' \strong{Demographic decompositions}
#'
#' \code{\link[=kitagawa2]{kitagawa2()}}, \code{\link[=das_gupta_n]{das_gupta_n()}},
#' \code{\link[=life_table]{life_table()}}, \code{\link[=arriaga_decomp]{arriaga_decomp()}},
#' \code{\link[=ltre_fixed]{ltre_fixed()}}
#'
#' \strong{Matrix models shared by both fields}
#'
#' \code{\link[=leontief_inverse]{leontief_inverse()}},
#' \code{\link[=value_added_multipliers]{value_added_multipliers()}},
#' \code{\link[=fundamental_matrix]{fundamental_matrix()}},
#' \code{\link[=expected_time_in_state]{expected_time_in_state()}},
#' \code{\link[=lambda_sensitivity]{lambda_sensitivity()}},
#' \code{\link[=leontief_sensitivity]{leontief_sensitivity()}},
#' \code{\link[=numeric_sensitivity]{numeric_sensitivity()}}
#'
#' \strong{Generic order-independent decomposition}
#'
#' \code{\link[=shapley_decomp]{shapley_decomp()}},
#' \code{\link[=sequential_decomp]{sequential_decomp()}},
#' \code{\link[=all_orderings]{all_orderings()}}
#'
#' \strong{Data}
#'
#' \code{\link{leather}} (3 x 3 toy ICIO table), \code{\link{icio_synth}} (synthetic two-period
#' ICIO tables), \code{\link{dk_mortality}} (Danish death rates and population, Eurostat).
#'
#' @section Note:
#' The GVC code is derived from the R package \code{icio} (Krantz and Quast), itself derived from
#' \code{decompr} (Quast and Kummritz 2015). \code{bm()} is the R counterpart of \code{decompose()}
#' in the Julia package
#' \href{https://github.com/SebKrantz/GlobalValueChains.jl}{GlobalValueChains.jl} and reproduces
#' the Stata \code{icio} command.
#'
#' @references
#' Hummels, D., Ishii, J., & Yi, K. M. (2001). The nature and growth of vertical specialization in world trade. \emph{Journal of International Economics, 54}(1), 75-96.
#'
#' Koopman, R., Wang, Z., & Wei, S. J. (2014). Tracing value-added and double counting in gross exports. \emph{American Economic Review, 104}(2), 459-94.
#'
#' Wang, Zhi, Shang-Jin Wei, and Kunfu Zhu (2013). Quantifying international production sharing at the bilateral and sector levels (No. w19677). \emph{National Bureau of Economic Research}.
#'
#' Borin, A., & Mancini, M. (2019). Measuring What Matters in Global Value Chains and Value-Added Trade. \emph{World Bank Policy Research Working Paper 8804}.
#'
#' Belotti, F., Borin, A., & Mancini, M. (2021). icio: Economic analysis with inter-country input-output tables. \emph{The Stata Journal, 21}(3), 708-755.
#'
#' Kitagawa, E. M. (1955). Components of a difference between two rates. \emph{Journal of the American Statistical Association, 50}(272), 1168-1194.
#'
#' Das Gupta, P. (1993). \emph{Standardization and Decomposition of Rates: A User's Manual}. U.S. Bureau of the Census, Current Population Reports P23-186.
#'
#' Arriaga, E. E. (1984). Measuring and explaining the change in life expectancies. \emph{Demography, 21}(1), 83-96.
#'
#' Caswell, H. (1989). Analysis of life table response experiments I. Decomposition of effects on population growth rate. \emph{Ecological Modelling, 46}(3-4), 221-237.
#' @importFrom stats setNames
#' @importFrom utils globalVariables
#' @importFrom matrixStats rowSums2 colSums2 x_OP_y
#' @importFrom data.table fread rbindlist setDT setattr data.table melt
#' @useDynLib ddec, .registration = TRUE
"_PACKAGE"

#' @name leather
#' @docType data
#' @title Leather Example ICIO Data
#' @description An example 3 x 3 ICIO table describing a GVC for leather products with industries 'Agriculture', 'Textile and Leather' and 'Transport Equipment'
#' for the countries 'Argentina', 'Turkey' and 'Germany'.
#' @usage data("leather")
#'
#' @format A list of class 'iot' with the following elements:
#' \describe{
#'  \item{\code{inter}}{9 x 9 input output matrix where each column gives the value of inputs supplied to the corresponding country-industry by each row country-industry.}
#'  \item{\code{final}}{9 x 3 final demand matrix showing the final demand in each country (column) for each country-industry's (rows) produce.}
#'  \item{\code{countries}}{character vector of country names (matching columns of \code{final}).}
#'  \item{\code{industries}}{character vector of industries, such that \code{as.vector(t(outer(countries, industries, FUN = paste, sep = ".")))} generates the row- and column-names of \code{inter} and the rownames of \code{final}.}
#'  \item{\code{out}}{A vector of gross country-industry output. In a complete productive system it should be equal to \code{rowSums(inter) + rowSums(final)}.}
#' }
#' @seealso \code{\link{ddec-package}}
NULL
