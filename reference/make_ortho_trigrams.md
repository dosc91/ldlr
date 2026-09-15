# Create orthographic n-gram cues

Construct binary cue matrices while retaining the cue paths and metadata
required for form production.

## Usage

``` r
make_ortho_trigrams(words, n = 3L, boundary = "#", sparse = TRUE)

make_combined_ortho_trigrams(train_words, test_words, n = 3L,
  boundary = "#", sparse = TRUE)
```

## Arguments

- words:

  Character vector with one word type per row.

- train_words, test_words:

  Character vectors for training and test partitions.

- n:

  N-gram size.

- boundary:

  One-character boundary marker.

- sparse:

  Whether to use a sparse matrix when Matrix is installed.

## Value

An `ldlr_cues` object, or a list containing compatible training and test
cue objects.

## Details

Cue extraction and matrix construction are implemented entirely in R.
`make_ortho_trigrams()` mirrors the representation of
`JudiLing.make_cue_matrix()`; the combined function mirrors
`JudiLing.make_combined_cue_matrix()` by giving training and test
objects identical cue columns. During form production the Julia
representation is reconstructed and its cue order is checked against R.
