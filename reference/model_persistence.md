# Save and load portable ldlr objects

Persist ordinary R data rather than a live Julia proxy.

## Usage

``` r
save_ldlr_model(model, file)

load_ldlr_model(file)
```

## Arguments

- model:

  An ldlr model, cross-validation result, or produced-forms object.

- file:

  RDS file path.

## Value

The save path invisibly, or the restored object.

## Details

These functions call [`saveRDS()`](https://rdrr.io/r/base/readRDS.html)
and [`readRDS()`](https://rdrr.io/r/base/readRDS.html) and validate the
restored class. No Julia session is required.
