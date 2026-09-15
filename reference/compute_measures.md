# Compute LDL measures

Compute all applicable JudiLingMeasures measures through guarded Julia
implementations.

## Usage

``` r
available_measures()

compute_measures(model, measures = "all", neighbours = 8L,
  uncertainty_method = c("correlation", "cosine", "mse"),
  functional_load_method = c("correlation", "mse"))
```

## Arguments

- model:

  An ldlr comprehension, production, cross-validation, or produced-forms
  object. Cross-validation results support matrix-level measures.

- measures:

  Measure names, or `"all"` for every applicable measure.

- neighbours:

  Number of neighbours for semantic density.

- uncertainty_method:

  Correlation, cosine similarity, or mean squared error.

- functional_load_method:

  Correlation or mean squared error.

## Value

`available_measures()` returns the measure catalogue.
`compute_measures()` returns one data-frame row per item.

## Details

R selects measures applicable to the object and returns one row per
item. Names and intended quantities follow JudiLingMeasures. Numerical
work runs in `LDLRBackend.matrix_measures()` and
`LDLRBackend.cue_measures()` rather than dispatching directly to
upstream measure functions. These corrected Julia implementations guard
undefined correlations, missing values, cue indices, and scalar versus
vector measure names. Form-path inputs originate from
`JudiLing.learn_paths_rpi()` or `JudiLing.build_paths()`.
`available_measures()` itself is entirely native R code.
