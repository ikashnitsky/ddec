# Build `dk_mortality`: Danish death counts, mid-year population and death rates by single year
# of age, 2000 and 2019 (the last pre-COVID year), from Eurostat.
#
# Source (no login required), Eurostat dissemination API, SDMX 3.0, CSV:
#   demo_magec - Deaths by age and sex
#   demo_pjan  - Population on 1 January by age and sex
# Raw downloads are cached in data-raw/cache/ and committed, so the package data (and the
# Quarto report) can be rebuilt without network access. Delete the cache to re-download.
#
# Why not the Human Mortality Database: HMD requires a (free) registered login, so it cannot be
# fetched non-interactively. To use HMD instead, download DNK Deaths_1x1.txt and Exposures_1x1.txt
# manually from https://www.mortality.org into data-raw/cache/ and adapt `read_counts()` below.
#
# Why not Eurostat's life tables (demo_mlifetable): their open age interval switches from 85+
# (until 2013) to 95+ (from 2014), so the two years would not share an age grid.
#
# Construction: m_x = D_x / P_x with P_x the mid-year population, approximated as the average of the
# 1 January populations of year t and t + 1. Ages are 0, 1, ..., OPEN_AGE - 1, OPEN_AGE+.
#
# Run from the package root:  Rscript data-raw/get_demo_data.R

library(data.table)

YEARS    <- c(2000L, 2019L)
OPEN_AGE <- 95L
GEO      <- "DK"
cache    <- file.path("data-raw", "cache")
dir.create(cache, showWarnings = FALSE, recursive = TRUE)

eurostat_csv <- function(dataset, years) {
  f <- file.path(cache, sprintf("%s_%s_%s.csv", dataset, GEO, paste(range(years), collapse = "-")))
  if (!file.exists(f)) {
    url <- sprintf(paste0("https://ec.europa.eu/eurostat/api/dissemination/sdmx/3.0/data/dataflow/",
                          "ESTAT/%s/1.0?c[geo]=%s&c[sex]=T&c[TIME_PERIOD]=%s&format=csvdata&compress=false"),
                   dataset, GEO, paste(years, collapse = ","))
    message("Downloading ", dataset, " ...")
    utils::download.file(url, f, quiet = TRUE, mode = "wb")
  }
  fread(f)
}

# Map Eurostat age codes to integer ages; the open age group collects OPEN_AGE and above
read_counts <- function(d) {
  d <- d[!age %in% c("TOTAL", "UNK", "Y_LT5", "Y_GE85", "Y_GE95") & !grepl("^Y[0-9]+-[0-9]+$", age)]
  d[, a := suppressWarnings(as.integer(sub("^Y", "", age)))]
  d[age == "Y_LT1", a := 0L]
  d[age == "Y_OPEN", a := 100L]
  stopifnot(!anyNA(d$a))
  d[, a := pmin(a, OPEN_AGE)]
  d[, .(value = sum(OBS_VALUE)), by = .(year = as.integer(TIME_PERIOD), age = a)]
}

deaths <- read_counts(eurostat_csv("demo_magec", YEARS))
pjan   <- read_counts(eurostat_csv("demo_pjan", c(YEARS, YEARS + 1L)))

# Mid-year population of year t = mean of 1 Jan t and 1 Jan t+1
pop <- merge(pjan[year %in% YEARS], pjan[year %in% (YEARS + 1L), .(year = year - 1L, age, next_value = value)],
             by = c("year", "age"))
pop[, pop := (value + next_value) / 2]

dk_mortality <- merge(deaths[, .(year, age, deaths = value)], pop[, .(year, age, pop)],
                      by = c("year", "age"))
setorder(dk_mortality, year, age)
dk_mortality[, mx := deaths / pop]
stopifnot(dk_mortality[, .N, by = year]$N == OPEN_AGE + 1L, all(dk_mortality$pop > 0))
setattr(dk_mortality, "open_age", OPEN_AGE)
setattr(dk_mortality, "source", "Eurostat demo_magec and demo_pjan, retrieved via the dissemination API")
dk_mortality <- as.data.frame(dk_mortality)  # stored as data.frame; ddec functions accept vectors

print(aggregate(cbind(deaths, pop) ~ year, dk_mortality, sum))
save(dk_mortality, file = file.path("data", "dk_mortality.rda"), compress = "xz")
