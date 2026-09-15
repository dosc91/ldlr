# Getting started with ldlr

`ldlr` lets an R user construct, fit, evaluate, and inspect Linear
Discriminative Learning models without writing Julia code. A
comprehension model learns the mapping `C -> S`; a production model
learns `S -> C`.

## Installation and first setup

``` r

install.packages(c("JuliaConnectoR", "remotes"))
remotes::install_github("dosc91/ldlr")
library(ldlr)

setup_julia(install_julia = TRUE)
ldlr_status()
```

The first call may take several minutes. In R,
[`setup_julia()`](https://dosc91.github.io/ldlr/reference/setup_julia.md)
locates or installs Julia, creates a package-specific environment,
installs JudiLing and its dependencies, starts the Julia connection,
loads `LDLRBackend`, and runs a small mapping test. No Julia commands
are required. Later sessions normally only need
[`library(ldlr)`](https://dosc91.github.io/ldlr/); a backend call starts
Julia when needed.

If Julia is already installed but cannot be detected, supply its
executable:

``` r

setup_julia(julia = "C:/Users/name/.julia/juliaup/julia-1.12.0+0.x64.w64.mingw32/bin/julia.exe",
            install_julia = FALSE)
```

On macOS a manually supplied path often resembles
`/Applications/Julia-1.12.app/Contents/Resources/julia/bin/julia`.

## Prepare semantic vectors

`S` must be a numeric matrix with one lexical item per row. For fastText
text vectors,
[`load_fasttext_vectors()`](https://dosc91.github.io/ldlr/reference/load_fasttext_vectors.md)
reads the header, uses the first field as row names, and returns the
remaining fields as a numeric matrix. This operation is implemented
entirely in R with
[`data.table::fread()`](https://rdrr.io/pkg/data.table/man/fread.html).

``` r

vectors <- load_fasttext_vectors("cc.en.300.vec")
words <- unique(as.character(data$word))
S <- vectors[words, , drop = FALSE]

stopifnot(!anyNA(S), identical(rownames(S), words))
```

Subsetting with `vectors[words, ]`, rather than `%in%`, preserves the
requested order. Missing words create `NA` rows and should be handled
before fitting.

## Construct a cue matrix

``` r

cues <- make_ortho_trigrams(words, n = 3, boundary = "#", sparse = TRUE)
C <- as.matrix(cues)

identical(rownames(C), rownames(S))
```

The function returns an `ldlr_cues` object containing the matrix `C`,
the ordered words, cue names, and each word’s ordered cue path. Keeping
this object, rather than only its matrix, enables cue-dependent measures
and path finding. Cue construction is native R code. It mirrors the
representation created by `JudiLing.make_cue_matrix()`;
[`produce_forms()`](https://dosc91.github.io/ldlr/reference/produce_forms.md)
independently reconstructs the Julia cue object and verifies that both
cue orders agree.

## Fit comprehension and production

``` r

comprehension <- compute_comprehension(
  C = cues,
  S = S,
  learning = "endstate"
)

production <- compute_production(
  S = S,
  C = cues,
  learning = "endstate"
)

comprehension
production
```

For comprehension, `mapping` is the matrix `F`, and `S_hat = C %*% F`.
For production, `mapping` is `G`, and `C_hat = S %*% G`. The R functions
validate row alignment and dimensions, retain names and targets,
calculate recognition accuracy, and return portable R objects. The
expensive fit is delegated to `JudiLing.make_transform_matrix()`.

Useful standard R methods include:

``` r

summary(comprehension)
coef(comprehension)
fitted(comprehension)
as.data.frame(comprehension)
predict(comprehension, newdata = as.matrix(cues))
```

## Compute and check measures

``` r

measures <- compute_measures(comprehension, measures = "all")
problems <- check_measure_values(measures)

head(measures)
problems
```

[`compute_measures()`](https://dosc91.github.io/ldlr/reference/compute_measures.md)
returns one R data-frame row per item. Use
[`available_measures()`](https://dosc91.github.io/ldlr/reference/compute_measures.md)
to see applicability by stage and direction. The [measures
guide](https://dosc91.github.io/ldlr/articles/measures-and-diagnostics.md)
documents definitions and the Julia implementation in detail.

## Save the result

``` r

save_ldlr_model(comprehension, "comprehension.rds")
restored <- load_ldlr_model("comprehension.rds")
```

The stored object is ordinary R data. Loading or inspecting it does not
require Julia; Julia is needed again only when a new backend calculation
is requested.
