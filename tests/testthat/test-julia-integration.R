test_that("Julia backend completes the core LDL workflow", {
  skip_if(Sys.getenv("LDLR_RUN_JULIA_TESTS") != "true")
  setup_julia(install_julia = FALSE)

  words <- c("cat", "cats", "dog", "dogs", "walk")
  cues <- make_ortho_trigrams(words, sparse = FALSE)
  set.seed(1)
  S <- matrix(rnorm(length(words) * 8), nrow = length(words),
              dimnames = list(words, paste0("s", 1:8)))
  rownames(cues$C) <- words

  for (learning in c("endstate", "frequency", "incremental")) {
    frequency <- if (learning == "endstate") NULL else seq_along(words)
    comp <- compute_comprehension(cues, S, learning = learning,
                                  frequency = frequency, epochs = 2L)
    prod <- compute_production(S, cues, learning = learning,
                               frequency = frequency, epochs = 2L)
    expect_equal(dim(comp$F), c(ncol(cues$C), ncol(S)))
    expect_equal(dim(prod$G), c(ncol(S), ncol(cues$C)))
  }

  comp <- compute_comprehension(cues, S)
  prod <- compute_production(S, cues)
  expect_equal(nrow(compute_measures(comp)), length(words))
  expect_equal(nrow(compute_measures(prod)), length(words))
  comp_names <- ldlr:::.ldlr_applicable_measures(comp)
  prod_names <- ldlr:::.ldlr_applicable_measures(prod)
  for (measure in comp_names) {
    expect_equal(nrow(compute_measures(comp, measures = measure)), length(words))
  }
  for (measure in prod_names) {
    expect_equal(nrow(compute_measures(prod, measures = measure)), length(words))
  }
  expect_equal(
    nrow(compute_measures(comp, measures = c("functional_load", "uncertainty"),
                          uncertainty_method = "mse", functional_load_method = "mse")),
    length(words)
  )

  built <- produce_forms(prod, comp, method = "build", max_candidates = 3L)
  expect_equal(nrow(built$items), length(words))
  learned <- produce_forms(prod, comp, method = "learn", max_candidates = 3L,
                           threshold = -1)
  expect_equal(nrow(learned$items), length(words))
  expect_equal(nrow(compute_measures(learned)), length(words))

  loo_c <- compute_comprehension_loo(cues, S, progress = FALSE, chunk_size = 2L)
  loo_p <- compute_production_loo(S, cues, progress = FALSE, chunk_size = 2L)
  expect_equal(dim(loo_c$S_hat), dim(S))
  expect_equal(dim(loo_p$C_hat), dim(as.matrix(cues)))
  cv_c <- compute_comprehension_cv(cues, S, folds = 3L, progress = FALSE)
  cv_p <- compute_production_cv(S, cues, folds = 3L, progress = FALSE)
  expect_equal(dim(cv_c$S_hat), dim(S))
  expect_equal(dim(cv_p$C_hat), dim(as.matrix(cues)))
  expect_equal(nrow(compute_measures(cv_c)), length(words))
  expect_equal(nrow(compute_measures(cv_p)), length(words))
})
