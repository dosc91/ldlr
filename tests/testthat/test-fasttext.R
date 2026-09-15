test_that("fastText vectors are loaded as a named numeric matrix", {
  file <- tempfile(fileext = ".vec")
  writeLines(c("3 2", "cat 1.0 2.0", "dog 3.0 4.0", "walk 5.0 6.0"), file)
  vectors <- load_fasttext_vectors(file)

  expect_true(is.matrix(vectors))
  expect_type(vectors, "double")
  expect_identical(dim(vectors), c(3L, 2L))
  expect_identical(rownames(vectors), c("cat", "dog", "walk"))
  expect_identical(colnames(vectors), c("dim_1", "dim_2"))
})

test_that("fastText header and dimensions are checked", {
  file <- tempfile(fileext = ".vec")
  writeLines(c("not a header", "cat 1 2"), file)
  expect_error(load_fasttext_vectors(file), "first line")

  writeLines(c("1 3", "cat 1 2"), file)
  expect_error(load_fasttext_vectors(file), "declares 3")
})
