# Measures and diagnostics

[`compute_measures()`](https://dosc91.github.io/ldlr/reference/compute_measures.md)
provides one consistent R interface for measures at three stages:
numeric mapping predictions, ordered cue paths, and produced forms.

``` r

available_measures()

measures <- compute_measures(
  comprehension,
  measures = "all",
  neighbours = 8,
  uncertainty_method = "correlation",
  functional_load_method = "correlation"
)
```

R checks whether a requested measure is defined for the object and
direction, passes only the required arrays to Julia, converts Julia
values and missingness to R, and binds results by item.
`functional_load` is a list-column because it contains one value per cue
in each item.

## Matrix-level measures

| R name | JudiLingMeasures name | Interpretation |
|----|----|----|
| `l1` | `L1Norm` | L1 norm of the predicted vector |
| `l2` | `L2Norm` | Euclidean norm of the predicted vector |
| `semantic_density` | `density` | Mean similarity of the nearest semantic neighbours |
| `average_lexical_correlation` | `ALC` | Mean similarity to all lexical targets |
| `euclidean_nearest_neighbour` | `EDNN` | Distance to the closest target |
| `nearest_neighbour_correlation` | `NNC` | Highest target correlation |
| `target_correlation` | `target_correlation` | Correlation with the paired target |
| `rank` | `rank` | Rank of the paired target among candidates |
| `recognition` | `recognition` | Whether the paired target is ranked first |
| `uncertainty` | `uncertainty` | Dispersion of candidate similarities |

These names follow JudiLingMeasures. They are calculated by guarded
functions in `LDLRBackend.matrix_measures()` rather than by calling
JudiLingMeasures directly. This preserves the intended formulas while
handling zero-variance vectors, missing similarities, single requested
measures, and the R-to-Julia string conversion explicitly. Pairwise
correlations use Julia’s `Statistics.cor`; Euclidean, cosine, and MSE
matrices use Julia linear algebra.

For uncertainty, select the comparison scale in R:

``` r

u_cor <- compute_measures(comprehension, "uncertainty",
                          uncertainty_method = "correlation")
u_cos <- compute_measures(comprehension, "uncertainty",
                          uncertainty_method = "cosine")
u_mse <- compute_measures(comprehension, "uncertainty",
                          uncertainty_method = "mse")
```

## Cue-dependent measures

`functional_load`, `total_distance`, `semantic_support_for_form`,
`last_support`, and `c_precision` use each item’s ordered cue path. The
model must consequently have been fitted with an `ldlr_cues` object, not
a bare matrix.

The R names correspond to the same-named JudiLingMeasures concepts
(`SCPP` is the upstream name associated with path support). `ldlr`
calculates them in `LDLRBackend.cue_measures()` because the upstream
functions contain edge cases or indexing assumptions that are unsafe for
this interface. The corrected implementation converts cue identifiers
robustly, uses item-specific paths, checks model direction, and returns
missing values for undefined correlations instead of silently producing
misleading numbers.

``` r

cue_measures <- compute_measures(
  comprehension,
  measures = c("functional_load", "total_distance"),
  functional_load_method = "mse"
)
```

## Path-level measures

After
[`produce_forms()`](https://dosc91.github.io/ldlr/reference/produce_forms.md),
[`compute_measures()`](https://dosc91.github.io/ldlr/reference/compute_measures.md)
can expose `scpp`, `path_sum`, `target_path_sum`, `path_sum_chat`,
`within_path_entropy`, `mean_word_support`, `mean_word_support_chat`,
`length_weakest_link_ratio`, its `_chat` variant, `path_count`, both
path entropy variants, and `average_levenshtein_distance` (`ALDC`).

JudiLing supplies the candidate paths and support structures through
`JudiLing.learn_paths_rpi()` or `JudiLing.build_paths()`. The ldlr
backend then calculates these JudiLingMeasures-compatible summaries with
guarded entropy, missing-value, zero-support, and path-index handling.
Measures that require RPI support are unavailable for `method = "build"`
and are rejected by the R API.

Path finding can be computationally expensive. Estimate runtime on a
small, representative subset before applying it to a large lexicon.

## Diagnose suspicious results

``` r

diagnostics <- check_measure_values(measures)
diagnostics

check_measure_values(measures, problems_only = FALSE)
```

This function is entirely implemented in R. It reports missing values,
infinities, non-finite values, the number of distinct finite values, and
constant or nearly constant columns. It also inspects numeric
list-columns. A flag is not automatically proof of an error: a constant
recognition column, for example, may mean that every item was either
recognized or missed. It is a prompt to inspect the analysis, cue
coverage, and chosen formula.
