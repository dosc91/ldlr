# Produce ordered forms

Turn predicted cue activation into ordered candidate word forms using
JudiLing.

## Usage

``` r
produce_forms(production, comprehension, cues = production$cues,
  method = c("build", "learn"), max_candidates = 10L,
  threshold = 0.1, tolerant = FALSE, tolerance = -1000,
  max_tolerance = 3L, neighbours = 10L, verbose = FALSE)
```

## Arguments

- production:

  Matching production model.

- comprehension:

  Matching comprehension model used for synthesis-by-analysis.

- cues:

  Structured cue object for the evaluated word types.

- method:

  JudiLing's build-paths or learn-paths algorithm.

- max_candidates:

  Maximum candidate paths retained per item.

- threshold, tolerant, tolerance, max_tolerance:

  Learn-paths threshold settings.

- neighbours:

  Nearest training forms used by build-paths.

- verbose:

  Whether JudiLing should report progress.

## Value

A portable `ldlr_forms` object containing item and candidate tables.

## Details

R validates the model and cue objects. Julia reconstructs cues with
`JudiLing.make_cue_matrix()` or `JudiLing.make_combined_cue_matrix()`,
obtains the search horizon with `JudiLing.cal_max_timestep()`, and calls
`JudiLing.learn_paths_rpi()` or `JudiLing.build_paths()`. Candidate
paths are converted to forms with `JudiLing.translate()` and returned as
portable R tables. Path search can be computationally expensive.
