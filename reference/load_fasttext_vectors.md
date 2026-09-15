# Load vectors in fastText text format

Read a fastText `.vec` text file into a matrix suitable for use as an
LDL semantic matrix.

## Usage

``` r
load_fasttext_vectors(file)
```

## Arguments

- file:

  Path to a fastText text-vector file. Its first line must contain the
  vocabulary size and vector dimension.

## Value

A numeric matrix with vocabulary items as row names and vector
dimensions as columns.

## Details

This function is implemented entirely in R using
[`data.table::fread()`](https://rdrr.io/pkg/data.table/man/fread.html).
It does not start Julia or call JudiLing.
