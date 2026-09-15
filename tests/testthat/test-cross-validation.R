test_that("cross-validation helpers validate n and options", {
  C <- matrix(1:6, 3, 2)
  S <- matrix(1:9, 3, 3)
  expect_error(compute_comprehension_loo(C, S[-1, ], progress = FALSE), "same number")
  expect_error(compute_comprehension_loo(C, S, chunk_size = 0, progress = FALSE), "positive integer")
  expect_error(compute_comprehension_loo(C, S, shift = 0, progress = FALSE), "positive finite")
  expect_error(compute_comprehension_cv(C, S, folds = 4, progress = FALSE), "between 2")
})

test_that("fold assignment is balanced, reproducible, and preserves RNG", {
  set.seed(99)
  before <- .Random.seed
  first <- ldlr:::.ldlr_fold_ids(23L, 10L, 12L)
  second <- ldlr:::.ldlr_fold_ids(23L, 10L, 12L)
  expect_identical(first, second)
  expect_lte(max(table(first)) - min(table(first)), 1L)
  expect_identical(.Random.seed, before)
})

test_that("cross-validation objects have consistent R methods and persistence", {
  predicted <- matrix(c(1, 0, 0, 1), 2, byrow = TRUE,
                      dimnames = list(c("a", "b"), c("x", "y")))
  result <- ldlr:::.ldlr_cv_result("comprehension", predicted, predicted,
                                   c(1L, 2L), "k-fold",
                                   list(n = 2L, folds = 2L), NULL)
  expect_s3_class(result, "ldlr_cv")
  expect_identical(fitted(result), predicted)
  expect_equal(nrow(as.data.frame(result)), 2L)
  expect_equal(nrow(summary(result)), 1L)
  expect_equal(nrow(summary(result, by_fold = TRUE)), 2L)

  file <- tempfile(fileext = ".rds")
  save_ldlr_model(result, file)
  expect_equal(load_ldlr_model(file), result)
})
