# Troubleshooting

Start diagnostics with:

``` r

ldlr_status()
```

## Julia is not found or the wrong executable starts

Let
[`setup_julia()`](https://dosc91.github.io/ldlr/reference/setup_julia.md)
install Julia, or pass the exact executable path:

``` r

setup_julia(install_julia = TRUE)

# Alternatively:
setup_julia(julia = "C:/path/to/julia.exe", install_julia = FALSE)
```

On Windows, a path under `Microsoft` may point to an application alias
rather than a working Julia installation. Prefer the executable reported
by Juliaup or the actual Julia installation directory. On macOS, pass
the executable inside the `.app` bundle if command-line discovery fails.

## First setup is slow

The first setup installs and precompiles Julia dependencies. This is
expected and is normally a one-time cost. Keep the R process open until
setup reports a successful smoke test. Subsequent sessions reuse the
isolated environment.

## C and S do not align

Both matrices must contain the same items in the same row order. Use
name-based indexing rather than `%in%`:

``` r

words <- unique(as.character(data$word))
S <- vectors[words, , drop = FALSE]
cues <- make_ortho_trigrams(words)

stopifnot(
  !anyNA(S),
  identical(rownames(cues$C), rownames(S))
)
```

For separate partitions, use
[`make_combined_ortho_trigrams()`](https://dosc91.github.io/ldlr/reference/make_ortho_trigrams.md)
so train and test matrices have identical cue columns.

## Cue-dependent measures are rejected

Pass the full `ldlr_cues` object to the model function:

``` r

compute_comprehension(cues, S)       # retains cue paths
compute_comprehension(as.matrix(cues), S) # loses cue metadata
```

Both forms can fit a mapping, but only the first supports measures that
need ordered cue paths.

## Missing, infinite, or constant measures

``` r

result <- compute_measures(comprehension, measures = "all")
check_measure_values(result)
```

Zero-variance predicted or target vectors make correlation undefined. A
constant measure may be valid but uninformative. In cross-validation,
unseen held-out cues can yield zero predictions. Inspect cue coverage
and the model inputs before treating an `NA` as a backend error.

## A single requested measure fails

Current `ldlr` versions normalize both one name and multiple names to
the Julia string-vector representation expected by the backend:

``` r

compute_measures(comprehension, "uncertainty",
                 uncertainty_method = "mse")
compute_measures(comprehension,
                 c("functional_load", "uncertainty"),
                 uncertainty_method = "mse",
                 functional_load_method = "mse")
```

If an installed copy still reports a Julia dispatch error involving
`String` or `Vector{String}`, reinstall the latest package build and
restart R.

## Form production takes too long

[`produce_forms()`](https://dosc91.github.io/ldlr/reference/produce_forms.md)
searches ordered candidate paths and can be far more expensive than
fitting `F` or `G`. Runtime depends on vocabulary size, cue network,
maximum time step, candidate limit, threshold, and algorithm. Test a
small representative subset first. Stop a long run from R if path output
is not needed for the analysis; comprehension, production,
cross-validation, and matrix/cue measures do not depend on form
production.

## Reporting a problem

Include
[`ldlr_status()`](https://dosc91.github.io/ldlr/reference/setup_julia.md),
[`sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html), matrix
dimensions, the complete error, and a small reproducible example when
opening an issue at <https://github.com/dosc91/ldlr/issues>. Do not
attach a full fastText model when a small numeric matrix can reproduce
the problem.
