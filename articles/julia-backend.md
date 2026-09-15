# R and Julia architecture

`ldlr` separates the public R interface from the numerical Julia
backend. The boundary is deliberate: users retain familiar R objects and
explicit data checks, while large matrix operations use Julia.

## What runs where?

| R function | Work in R | Julia function or implementation |
|----|----|----|
| [`setup_julia()`](https://dosc91.github.io/ldlr/reference/setup_julia.md) | discovery, installation orchestration, status | loads `JudiLing`, `DataFrames`, `LinearAlgebra`, `SparseArrays`, `Statistics`, and `LDLRBackend` |
| [`load_fasttext_vectors()`](https://dosc91.github.io/ldlr/reference/load_fasttext_vectors.md) | complete import with [`data.table::fread()`](https://rdrr.io/pkg/data.table/man/fread.html) | none |
| [`make_ortho_trigrams()`](https://dosc91.github.io/ldlr/reference/make_ortho_trigrams.md) | complete cue construction and metadata | none; mirrors `JudiLing.make_cue_matrix()` |
| [`make_combined_ortho_trigrams()`](https://dosc91.github.io/ldlr/reference/make_ortho_trigrams.md) | shared train/test cue vocabulary | none; mirrors `JudiLing.make_combined_cue_matrix()` |
| [`compute_comprehension()`](https://dosc91.github.io/ldlr/reference/compute_mappings.md) / [`compute_production()`](https://dosc91.github.io/ldlr/reference/compute_mappings.md) | validation, prediction, R object | `JudiLing.make_transform_matrix()` or `JudiLing.wh_learn()`; optional `JudiLing.make_learn_seq()` |
| leave-one-out functions | validation, progress, result object | exact custom ridge-leverage implementation equivalent to repeated end-state fits |
| k-fold functions | fold assignment, progress, held-out multiplication | custom Cholesky end-state fit equivalent to `JudiLing.make_transform_matrix()` |
| [`compute_measures()`](https://dosc91.github.io/ldlr/reference/compute_measures.md) | selection, applicability, tidy output | guarded `LDLRBackend.matrix_measures()` and `cue_measures()` implementing JudiLingMeasures concepts |
| [`produce_forms()`](https://dosc91.github.io/ldlr/reference/produce_forms.md) | validation and portable R result | `JudiLing.make_cue_matrix()`, `make_combined_cue_matrix()`, `cal_max_timestep()`, `learn_paths_rpi()` or `build_paths()`, and `translate()` |
| [`check_measure_values()`](https://dosc91.github.io/ldlr/reference/check_measure_values.md) | complete diagnostics | none |
| save/load functions | RDS serialization | none |

## Model fitting calls

The Julia wrapper `LDLRBackend.fit_mapping()` receives `X`, `Y`, a
learning method, and its parameters. End-state learning calls:

``` julia
JudiLing.make_transform_matrix(X, Y; shift = shift)
```

Frequency-informed learning calls its weighted method:

``` julia
JudiLing.make_transform_matrix(X, Y, frequency; shift = shift)
```

Incremental learning calls:

``` julia
JudiLing.make_learn_seq(frequency; random_seed = seed)
JudiLing.wh_learn(X, Y; n_epochs = epochs, eta = learning_rate,
                  learn_seq = sequence, verbose = false)
```

These are implementation details, not commands an `ldlr` user needs to
run.

## Why measures use a package backend

The measure vocabulary and intended quantities come from
JudiLingMeasures, but calling its public functions through an R bridge
exposed several correctness and robustness problems: scalar strings were
dispatched differently from string vectors, cue paths could arrive as
integers rather than strings, some indices assumed a particular
representation, and undefined correlations were not consistently
guarded. `ldlr` therefore calls corrected Julia functions in its own
backend. This keeps the expensive pairwise calculations in Julia while
making behavior explicit and testable from R.

[`available_measures()`](https://dosc91.github.io/ldlr/reference/compute_measures.md)
retains each original JudiLingMeasures name so results can be related to
the Julia literature and code.

## Portable R objects

Julia objects are not stored in a fitted model. Mappings, targets,
predictions, cue metadata, parameters, and summaries are converted into
R matrices, vectors, data frames, and lists. Therefore models can be
serialized with
[`save_ldlr_model()`](https://dosc91.github.io/ldlr/reference/model_persistence.md)
and inspected on a machine without an active Julia session.

## Reproducibility

Report the `ldlr` package version, Julia version, learning method and
parameters, cue construction, semantic-vector source, row ordering, and
evaluation design.
[`ldlr_status()`](https://dosc91.github.io/ldlr/reference/setup_julia.md)
provides backend and Julia information useful for a methods record or
bug report.
