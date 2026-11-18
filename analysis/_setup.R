# Shared setup for the Quarto report. Sourced at the top of every page; the working directory is
# the project (= package) root, see `execute-dir: project` in _quarto.yml.
set.seed(1)
suppressPackageStartupMessages({
  pkgload::load_all(".", quiet = TRUE, export_all = FALSE)
  library(data.table)
  library(ggplot2)
})

# Categorical palette (fixed slot order; validated for CVD separation on adjacent pairs).
# Slots 3-5 are below 3:1 contrast on white, so every figure is paired with a table or direct labels.
pal <- c("#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300", "#6250d6", "#e34948")
ink <- "#0b0b0b"; ink2 <- "#52514e"

theme_ddec <- function() {
  theme_minimal(base_size = 12) +
    theme(panel.grid.minor = element_blank(),
          panel.grid.major = element_line(colour = "#e8e7e3", linewidth = 0.3),
          axis.text = element_text(colour = ink2), axis.title = element_text(colour = ink2),
          plot.title = element_text(colour = ink, face = "bold"),
          plot.subtitle = element_text(colour = ink2),
          strip.text = element_text(colour = ink, face = "bold", hjust = 0),
          legend.position = "top", legend.justification = "left",
          legend.title = element_blank(), legend.text = element_text(colour = ink2))
}
theme_set(theme_ddec())

fmt <- function(x, d = 3) formatC(x, format = "f", digits = d, big.mark = ",")
