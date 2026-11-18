context("life_table and arriaga_decomp")

d0 <- subset(dk_mortality, year == 2000)
d1 <- subset(dk_mortality, year == 2019)

test_that("life_table() is internally consistent", {
  lt <- life_table(d0$mx)
  expect_equal(nrow(lt), nrow(d0))
  expect_equal(lt$lx[1], 1)
  expect_equal(sum(lt$dx), 1)
  expect_equal(lt$Tx[1], sum(lt$Lx))
  expect_equal(tail(lt$qx, 1), 1)
  expect_gt(lt$ex[1], 75); expect_lt(lt$ex[1], 78)    # Denmark 2000: ~77 years
  expect_error(life_table(c(0.1, 0)), "open age")
  expect_error(life_table(d0$mx, ax = 0.5), "length")
})

test_that("arriaga_decomp() adds up exactly to the e0 difference", {
  a <- arriaga_decomp(d0$mx, d1$mx, age = d0$age)
  expect_equal(names(a), c("age", "direct", "indirect", "interaction", "total"))
  expect_equal(sum(a$total), attr(a, "e02") - attr(a, "e01"), tolerance = 1e-10)
  expect_equal(a$total, a$direct + a$indirect + a$interaction)
  expect_equal(tail(a$indirect, 1), 0)
  # reversing the direction flips the sum but not merely the sign of each age's contribution
  b <- arriaga_decomp(d1$mx, d0$mx)
  expect_equal(sum(b$total), -sum(a$total), tolerance = 1e-10)
})

test_that("life_table() and arriaga_decomp() agree with LEdecomp", {
  skip_if_not_installed("LEdecomp")
  age <- d0$age
  ax0 <- LEdecomp::mx_to_ax(d0$mx, age = age, sex = "t")
  ax1 <- LEdecomp::mx_to_ax(d1$mx, age = age, sex = "t")
  expect_equal(life_table(d0$mx, ax = ax0)$ex[1], LEdecomp::mx_to_e0(d0$mx, age = age, sex = "t"),
               tolerance = 1e-6)
  ours <- arriaga_decomp(d0$mx, d1$mx, ax1 = ax0, ax2 = ax1)
  ref <- LEdecomp::arriaga(d0$mx, d1$mx, age = age, sex1 = "t")
  expect_equal(ours$total, unname(ref), tolerance = 1e-6)
})
