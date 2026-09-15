test_that("Julia dictionaries become recursively named R lists", {
  translated <- ldlr:::.ldlr_normalize_julia(list(
    keys = list("first", "nested"),
    values = list(1:2, list(keys = list("answer"), values = list(42)))
  ))

  expect_identical(names(translated), c("first", "nested"))
  expect_identical(translated$first, 1:2)
  expect_identical(translated$nested$answer, 42)
  expect_null(ldlr:::.ldlr_julia_get(NULL))
})
