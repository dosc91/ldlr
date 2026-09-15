# Diagnose problematic measure columns

Detect missing values, NaN, infinity, all-missing output, and constant
or numerically near-constant measures. Numeric values inside
list-columns are included.

## Usage

``` r
check_measure_values(x, problems_only = FALSE,
  tolerance = sqrt(.Machine$double.eps), include_identifiers = FALSE)
```

## Arguments

- x:

  A data frame returned by
  [`compute_measures()`](https://dosc91.github.io/ldlr/reference/compute_measures.md).

- problems_only:

  Return only columns with a detected problem.

- tolerance:

  Relative tolerance used to identify numerically constant
  floating-point columns.

- include_identifiers:

  Also inspect identifier columns named `item` and `fold`.

## Value

A data frame with one row per inspected measure, diagnostic counts,
flags, and a concise issues column.

## Details

All diagnostics are computed in R. Julia, JudiLing, and JudiLingMeasures
are not called.
