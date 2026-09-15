test_that("produce_forms validates its paired models before Julia is called", {
  cues <- make_ortho_trigrams(c("cat", "dog"), sparse = FALSE)
  expect_error(produce_forms(list(), list(), cues), "production")
})

test_that("all documented measures have unique names", {
  catalog <- available_measures()
  expect_equal(anyDuplicated(catalog$name), 0L)
  expect_setequal(unique(catalog$stage), c("matrix", "cue", "path"))
})
