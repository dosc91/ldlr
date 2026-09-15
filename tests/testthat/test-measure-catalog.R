test_that("the complete measure catalog retains original names", {
  catalog <- available_measures()
  expect_equal(nrow(catalog), 28L)
  expect_true(all(c("name", "stage", "direction", "original") %in% names(catalog)))
  expect_true(all(c("uncertainty", "functional_load", "scpp") %in% catalog$name))
})
