# Package index

## Package overview

- [`ldlr`](https://dosc91.github.io/ldlr/reference/ldlr-package.md)
  [`ldlr-package`](https://dosc91.github.io/ldlr/reference/ldlr-package.md)
  : Linear Discriminative Learning from R

## Setup and data input

- [`setup_julia()`](https://dosc91.github.io/ldlr/reference/setup_julia.md)
  [`ldlr_status()`](https://dosc91.github.io/ldlr/reference/setup_julia.md)
  : Configure the Julia backend
- [`load_fasttext_vectors()`](https://dosc91.github.io/ldlr/reference/load_fasttext_vectors.md)
  : Load vectors in fastText text format

## Cue matrices

- [`make_ortho_trigrams()`](https://dosc91.github.io/ldlr/reference/make_ortho_trigrams.md)
  [`make_combined_ortho_trigrams()`](https://dosc91.github.io/ldlr/reference/make_ortho_trigrams.md)
  : Create orthographic n-gram cues

## Comprehension and production

- [`compute_comprehension()`](https://dosc91.github.io/ldlr/reference/compute_mappings.md)
  [`compute_production()`](https://dosc91.github.io/ldlr/reference/compute_mappings.md)
  : Compute LDL comprehension and production mappings
- [`save_ldlr_model()`](https://dosc91.github.io/ldlr/reference/model_persistence.md)
  [`load_ldlr_model()`](https://dosc91.github.io/ldlr/reference/model_persistence.md)
  : Save and load portable ldlr objects

## Evaluation and cross-validation

- [`compute_comprehension_loo()`](https://dosc91.github.io/ldlr/reference/cross_validation.md)
  [`compute_production_loo()`](https://dosc91.github.io/ldlr/reference/cross_validation.md)
  [`compute_comprehension_cv()`](https://dosc91.github.io/ldlr/reference/cross_validation.md)
  [`compute_production_cv()`](https://dosc91.github.io/ldlr/reference/cross_validation.md)
  [`summary(`*`<ldlr_cv>`*`)`](https://dosc91.github.io/ldlr/reference/cross_validation.md)
  [`as.data.frame(`*`<ldlr_cv>`*`)`](https://dosc91.github.io/ldlr/reference/cross_validation.md)
  [`fitted(`*`<ldlr_cv>`*`)`](https://dosc91.github.io/ldlr/reference/cross_validation.md)
  : Cross-validated LDL predictions

## Measures and diagnostics

- [`available_measures()`](https://dosc91.github.io/ldlr/reference/compute_measures.md)
  [`compute_measures()`](https://dosc91.github.io/ldlr/reference/compute_measures.md)
  : Compute LDL measures
- [`check_measure_values()`](https://dosc91.github.io/ldlr/reference/check_measure_values.md)
  : Diagnose problematic measure columns

## Word-form paths

- [`produce_forms()`](https://dosc91.github.io/ldlr/reference/produce_forms.md)
  : Produce ordered forms
