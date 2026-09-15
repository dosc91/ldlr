test_that("measure diagnostics identify common problems", {
  values <- data.frame(
    item = letters[1:4],
    good = c(1, 2, 3, 4),
    constant = rep(2, 4),
    broken = c(1, NA, Inf, NaN),
    logical_constant = rep(TRUE, 4)
  )
  result <- check_measure_values(values)
  expect_false("item" %in% result$measure)
  expect_false(result$problem[result$measure == "good"])
  expect_true(result$constant[result$measure == "constant"])
  expect_equal(result$missing[result$measure == "broken"], 2L)
  expect_equal(result$nan[result$measure == "broken"], 1L)
  expect_equal(result$infinite[result$measure == "broken"], 1L)
  expect_true(result$constant[result$measure == "logical_constant"])
  expect_true(all(check_measure_values(values, problems_only = TRUE)$problem))
})

test_that("measure diagnostics inspect numeric list-columns", {
  values <- data.frame(item = c("a", "b"))
  values$functional_load <- I(list(c(1, NA), c(1, 1)))
  result <- check_measure_values(values)
  expect_equal(result$storage, "list-column")
  expect_equal(result$missing, 1L)
  expect_true(result$constant)
})

test_that("measure diagnostic arguments are validated", {
  expect_error(check_measure_values(matrix(1)), "data frame")
  expect_error(check_measure_values(data.frame(x = 1), tolerance = -1),
               "non-negative")
})
