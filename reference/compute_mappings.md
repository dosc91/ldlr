# Compute LDL comprehension and production mappings

Estimate a mapping in Julia and return its mapping, predictions,
accuracy, and metadata as an ordinary R object.

## Usage

``` r
compute_comprehension(C, S, C_test = NULL, S_test = NULL,
  learning = c("endstate", "frequency", "incremental"), frequency = NULL,
  epochs = 1L, learning_rate = 0.1, learning_sequence = NULL, seed = 314L,
  shift = 0.02)

compute_production(S, C, S_test = NULL, C_test = NULL,
  learning = c("endstate", "frequency", "incremental"), frequency = NULL,
  epochs = 1L, learning_rate = 0.1, learning_sequence = NULL, seed = 314L,
  shift = 0.02)
```

## Arguments

- C, S:

  Matched cue and semantic matrices. `C` may be an `ldlr_cues` object.

- C_test, S_test:

  Optional matched held-out matrices.

- learning:

  End-state, frequency-informed, or incremental Widrow-Hoff learning.

- frequency:

  Frequencies for frequency-informed learning, or integer event counts
  for incremental learning.

- epochs:

  Number of incremental passes through the presentation sequence.

- learning_rate:

  Widrow-Hoff learning rate.

- learning_sequence:

  Optional explicit sequence of training row indices.

- seed:

  Seed used to create a frequency-expanded random presentation sequence.

- shift:

  Positive ridge shift for end-state and frequency-informed mappings;
  the default matches JudiLing.

## Value

A portable `ldlr_comprehension` or `ldlr_production` model.

## Details

In R, the functions validate row alignment and dimensions, retain names
and targets, calculate predictions, and construct portable model
objects. End-state and frequency-informed fits call
`JudiLing.make_transform_matrix()`. Incremental fits call
`JudiLing.wh_learn()` and optionally `JudiLing.make_learn_seq()`.
Comprehension returns `S_hat = C F`; production returns `C_hat = S G`.
