test_that("misordered named matrices fail loudly", {
  C <- matrix(1:4, 2, dimnames = list(c("a", "b"), NULL))
  S <- matrix(1:4, 2, dimnames = list(c("b", "a"), NULL))
  expect_error(ldlr:::.ldlr_validate_pair(C, S, "C", "S"), "ordered differently")
})

test_that("learning arguments are explicit", {
  expect_error(ldlr:::.ldlr_validate_learning("frequency", NULL, 1, .1, NULL))
  expect_equal(ldlr:::.ldlr_validate_learning("incremental", NULL, 1, .1, NULL),
               "incremental")
})

test_that("ridge shift is validated", {
  expect_error(ldlr:::.ldlr_validate_shift(0), "positive finite")
  expect_equal(ldlr:::.ldlr_validate_shift(0.02), 0.02)
})
