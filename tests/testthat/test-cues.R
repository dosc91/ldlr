test_that("orthographic trigrams retain matrix and path metadata", {
  cues <- make_ortho_trigrams(c(cat = "cat", dog = "dog"), sparse = FALSE)
  expect_s3_class(cues, "ldlr_cues")
  expect_equal(cues$paths[[1]], c("#ca", "cat", "at#"))
  expect_equal(unname(cues$C[1, cues$paths[[1]]]), c(1, 1, 1))
  expect_equal(rownames(cues$C), c("cat", "dog"))
})

test_that("combined cue matrices have identical columns", {
  cues <- make_combined_ortho_trigrams(c("cat", "dog"), c("cats", "dogs"), sparse = FALSE)
  expect_identical(colnames(cues$train$C), colnames(cues$test$C))
  expect_true("ts#" %in% colnames(cues$train$C))
  expect_equal(unname(cues$train$C[1, "ts#"]), 0)
})

test_that("unnamed words become cue row names", {
  words <- c("cat", "dogs")
  cues <- make_ortho_trigrams(words, sparse = FALSE)
  expect_identical(rownames(cues$C), words)
})

test_that("cue input is validated", {
  expect_error(make_ortho_trigrams(c("ok", NA_character_)))
  expect_error(make_ortho_trigrams("a#b"))
  expect_error(make_ortho_trigrams("word", n = 0))
})
