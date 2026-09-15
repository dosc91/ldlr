# Evaluation and cross-validation

Training accuracy describes the mapping on the observations used to
estimate it. Use explicit test data or cross-validation when the
research question is about generalization.

## Leave-one-out predictions

``` r

comp_loo <- compute_comprehension_loo(cues, S, progress = TRUE)
prod_loo <- compute_production_loo(S, cues, progress = TRUE)

summary(comp_loo)
as.data.frame(comp_loo)
S_hat_loo <- fitted(comp_loo)
```

Each row is predicted by a mapping estimated without that row. The
operation is mathematically equivalent to fitting
`JudiLing.make_transform_matrix()` `n` times with the chosen ridge
`shift`. For efficiency, `ldlr` implements the exact ridge leave-one-out
identity in Julia: one Cholesky factorization is prepared and
predictions are returned to R in `chunk_size` blocks. Thus this function
follows JudiLing’s end-state estimator but does not repeatedly call an
upstream JudiLing function.

## K-fold predictions

``` r

comp_cv <- compute_comprehension_cv(
  cues, S, folds = 10, seed = 314, progress = TRUE
)
prod_cv <- compute_production_cv(
  S, cues, folds = 10, seed = 314, progress = TRUE
)

summary(comp_cv)
summary(comp_cv, by_fold = TRUE)
```

R creates reproducible, approximately balanced fold labels. For every
fold, Julia fits an end-state ridge mapping using the same linear
algebra as `JudiLing.make_transform_matrix()`, and R multiplies the
held-out input by that mapping. Every row receives exactly one held-out
prediction. `folds` may range from 2 to the number of rows; the default
is 10 and is never tied to a fixed dataset size.

## Saving predictions during a run

``` r

comp_cv <- compute_comprehension_cv(
  cues, S,
  output = "comprehension_cv_predictions.csv"
)
```

`output` writes an R-friendly CSV containing item identifiers and
predictions. The returned `ldlr_cv` object additionally retains targets,
fold labels, accuracy, and parameters, and can be saved with
[`save_ldlr_model()`](https://dosc91.github.io/ldlr/reference/model_persistence.md).

## Measures for held-out predictions

``` r

cv_measures <- compute_measures(comp_cv, measures = "all")
check_measure_values(cv_measures)
```

Cross-validation objects support matrix-level measures. Cue-dependent
measures require a single fitted mapping and are therefore intentionally
unavailable.

## A cue-space caveat

Orthographic n-grams can be unique to one word. In random folds, a
held-out word may contain cues that occur nowhere in its training
partition. Those cue weights cannot be learned, and a prediction can
become a zero vector. Missing correlations, zero variance, or very low
recognition can therefore reflect the split and cue inventory rather
than a software failure. Inspect the output with
[`check_measure_values()`](https://dosc91.github.io/ldlr/reference/check_measure_values.md)
and report how folds and cue coverage were handled.
