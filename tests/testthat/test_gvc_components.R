context("gvc_components and simulate_icio")

check_adding_up <- function(m, level) {
  g <- suppressMessages(gvc_components(m, level = level))
  ids <- c("Exporting_Country", if (level != "country") "Exporting_Industry",
           if (level == "bilateral") "Importing_Country")
  s <- g[, .(value = sum(value)), by = c("method", ids)]
  ref <- switch(level,
    country = data.table(Exporting_Country = m$k, GEXP = vapply(seq_len(m$G), function(g)
      sum(m$E[(g - 1) * m$N + seq_len(m$N)]), 0)),
    sector = data.table(Exporting_Country = rep(m$k, each = m$N), Exporting_Industry = rep(m$i, m$G),
                        GEXP = unname(m$E)),
    bilateral = data.table(Exporting_Country = rep(rep(m$k, each = m$N), m$G),
                           Exporting_Industry = rep(m$i, m$G * m$G),
                           Importing_Country = rep(m$k, each = m$G * m$N),
                           GEXP = as.vector(m$ESR)))
  ref <- ref[GEXP != 0 | level != "bilateral"]
  s[, (ids) := lapply(.SD, as.character), .SDcols = ids]
  chk <- merge(s, ref, by = ids)
  expect_equal(nrow(chk), nrow(s))
  expect_equal(chk$value, chk$GEXP, tolerance = 1e-8)
  g
}

test_that("every method's components sum to gross exports (leather)", {
  m <- load_icio(leather)
  g <- check_adding_up(m, "country")
  expect_equal(levels(g$method), c("leontief", "kww", "wwz", "bm"))
  check_adding_up(m, "sector")
  check_adding_up(m, "bilateral")
})

test_that("every method's components sum to gross exports (synthetic tables)", {
  for (tab in icio_synth) {
    m <- load_icio(tab)
    for (lev in c("country", "sector", "bilateral")) check_adding_up(m, lev)
  }
})

test_that("cross-method anchors hold", {
  m <- load_icio(leather)
  g <- gvc_components(m)
  dc <- function(meth) g[method == meth & content == "domestic", sum(value), by = Exporting_Country]$V1
  expect_equal(dc("leontief"), dc("bm"), tolerance = 1e-8)        # HIY domestic content = BM DC
  expect_equal(dc("kww"), dc("bm"), tolerance = 1e-8)
  vax <- function(meth) g[method == meth & category == "VAX", sum(value), by = Exporting_Country]$V1
  expect_equal(vax("kww"), vax("bm"), tolerance = 1e-8)
  expect_equal(vax("wwz"), vax("bm"), tolerance = 1e-8)
  expect_message(gvc_components(m, level = "bilateral"), "Dropping")
  expect_error(gvc_components(leather), "icio")
})

test_that("simulate_icio() produces a balanced, reproducible table", {
  s <- simulate_icio(G = 4, N = 3, va_share = 0.4, foreign_share = 0.3, seed = 7)
  expect_s3_class(s, "iot")
  expect_equal(dim(s$inter), c(12L, 12L))
  expect_equal(unname(s$output), unname(rowSums(s$inter) + rowSums(s$final)))
  m <- load_icio(s)
  expect_equal(unname(colSums(m$A)), rep(0.6, 12))
  expect_equal(simulate_icio(seed = 7), simulate_icio(seed = 7))
  expect_error(simulate_icio(G = 1), "two countries")
  expect_error(simulate_icio(va_share = 1), "va_share")
})
