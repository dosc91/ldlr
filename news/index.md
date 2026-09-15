# Changelog

## ldlr 0.0.1

Initial development version.

- Added automatic and manual Julia discovery and isolated package setup.
- Added Windows Juliaup discovery through `USERPROFILE` and excluded
  Microsoft WindowsApps launcher aliases that provide JuliaConnectoR
  with a false bindir.
- Made DataFrames and Tables explicit Julia dependencies and restart
  Julia in the isolated ldlr project after a single eager precompilation
  pass.
- Added orthographic n-gram cue construction.
- Added
  [`load_fasttext_vectors()`](https://dosc91.github.io/ldlr/reference/load_fasttext_vectors.md)
  for reading fastText text-vector files.
- Added explicit comprehension and production functions for exact
  leave-one-out and balanced k-fold end-state predictions, with R
  progress bars.
- Added model-style methods, persistence, fold summaries, and matrix
  measures for cross-validation results, plus consistent ridge-shift
  control for fits.
- Added explicit comprehension and production mappings.
- Added end-state, frequency-informed, and incremental learning.
- Added portable model objects and save/load helpers.
- Added the complete JudiLingMeasures catalog and corrected
  matrix-measure backend.
- Added
  [`check_measure_values()`](https://dosc91.github.io/ldlr/reference/check_measure_values.md)
  to detect missing, non-finite, all-missing, constant, and
  near-constant measure output, including numeric list-columns.
- Corrected JuliaConnectoR dictionary translation for matrix, cue, and
  nested path-measure results.
- Made cue-path index handling compatible with JuliaConnectoR on Julia
  1.12.
- Made single-measure requests robust to JuliaConnectoR’s scalar string
  conversion.
