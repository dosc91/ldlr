# Exercise: a complete LDL analysis

## What you will learn

This exercise introduces Linear Discriminative Learning (LDL) from the
beginning. No previous experience with LDL or Julia is assumed. By the
end, you will be able to

- represent word forms as an orthographic cue matrix **C**;
- represent meanings as a semantic matrix **S**;
- learn comprehension (**C -\> S**) and production (**S -\> C**)
  mappings;
- compute, inspect, combine, and save LDL measures; and
- fit frequency-informed and incremental mappings.

The code uses R throughout. `ldlr` sends computationally intensive
operations to Julia, JudiLing, and JudiLingMeasures in the background.

> **The two matrices are the heart of LDL.** Each row of **C** and **S**
> must describe the same lexical item, in the same order. **C** says
> which form cues are present; **S** says where that item’s meaning lies
> in semantic space.

## Before you begin

This exercise assumes that you have

1.  a data frame called `dat` with one observation per word or multiple
    observations containing a column called `word`;
2.  a fastText text-vector file in `.vec` format; and
3.  `ldlr` installed.

Replace the example file names and variable names where necessary.

``` r

library(ldlr)

# Run this once after installing ldlr. It finds or installs Julia and installs
# the required Julia packages into ldlr's own environment.
setup_julia(install_julia = TRUE)

# Confirm that Julia was found and that the backend is ready.
ldlr_status()
```

If Julia is already installed, `setup_julia(install_julia = FALSE)` is
enough. An explicit executable path can be supplied with
`setup_julia(julia = "...")`.

## 1. Minimal general workflow

### 1.1 Define the lexical items

LDL can be fitted at type level: one row represents one distinct word.
Preserve the order here, because this order will be used for both
matrices.

``` r

words <- unique(as.character(dat$word))

length(words)
head(words)
anyDuplicated(words)       # should return 0
```

### 1.2 Build the cue matrix C

Here, word forms are represented by overlapping orthographic trigrams.
Boundary markers distinguish word edges. For example, `cat` yields
`#ca`, `cat`, and `at#`.

``` r

cues <- make_ortho_trigrams(
  words,
  n = 3,
  boundary = "#",
  sparse = FALSE
)

C <- as.matrix(cues)

dim(C)
C[seq_len(min(5, nrow(C))), seq_len(min(10, ncol(C))), drop = FALSE]
```

`cues` is more than a matrix: it also stores the words, individual cue
paths, cue names, n-gram size, and boundary symbol. Keep this object.
Cue-dependent measures and path finding need that metadata later.

> **Task 1.** Inspect the first word in `words`. Identify its trigrams
> by hand, then locate their `1`s in the first row of `C`.

**One way to check your answer**

``` r

words[1]
cues$paths[[1]]
names(which(C[1, ] == 1))
```

The last two results should contain the same cues.

### 1.3 Build the semantic matrix S

Each row of **S** is a semantic vector for one word.
[`load_fasttext_vectors()`](https://dosc91.github.io/ldlr/reference/load_fasttext_vectors.md)
loads all vectors; indexing by `words` both selects the required
vocabulary and puts the rows in exactly the order used for **C**.

``` r

vectors <- load_fasttext_vectors("path/to/cc.en.300.vec")

# Check for absent words before subsetting. Otherwise missing names can be easy
# to overlook in a long analysis.
missing_words <- setdiff(words, rownames(vectors))
missing_words
stopifnot(length(missing_words) == 0L)

S <- vectors[words, , drop = FALSE]

dim(S)
stopifnot(
  nrow(C) == nrow(S),
  identical(rownames(C), rownames(S)),
  !anyNA(S),
  all(is.finite(S))
)
```

> **Task 2.** Explain why `vectors[rownames(vectors) %in% words, ]` is
> unsafe here even when it returns the correct number of rows.

**Explanation**

`%in%` retains the order of the complete fastText vocabulary, not the
order of `words`. Equal row counts therefore do not prove that rows
refer to the same items. Indexing with `vectors[words, ]` selects and
orders rows simultaneously.

### 1.4 Learn comprehension and production

An end-state comprehension mapping learns a matrix **F** that transforms
form cues into predicted semantic vectors: **C F = S-hat**. An end-state
production mapping learns **G** in the reverse direction: **S G =
C-hat**.

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

summary(comprehension)
summary(production)
```

The printed `Accuracy` is an item-identification accuracy, not a
regression coefficient or percentage of variance explained. Because no
test set was supplied, it describes the same lexical items that were
used to learn the mapping and should not be interpreted as out-of-sample
performance.

Useful components are available as ordinary R objects:

``` r

F <- coef(comprehension)
S_hat <- fitted(comprehension)

G <- coef(production)
C_hat <- fitted(production)

dim(F)
dim(S_hat)
dim(G)
dim(C_hat)
```

> **Task 3.** Use the dimensions to explain why **F** has one row per
> cue and one column per semantic dimension, whereas **G** has the
> reverse shape.

## 2. Measures

Measures turn the learned mappings and their predictions into item-level
quantities that can be inspected or used in later analyses. Some
measures compare predictions with targets; others describe the
neighbourhood of an item or the contribution of its cues.

``` r

measure_catalog <- available_measures()
measure_catalog
```

The `stage` and `direction` columns show when each measure is available.
For example, a comprehension-only measure should not be requested from a
production model.

### 2.1 Compute all applicable measures

``` r

comprehension_measures <- compute_measures(
  comprehension,
  measures = "all",
  neighbours = 8,
  uncertainty_method = "correlation",
  functional_load_method = "correlation"
)

production_measures <- compute_measures(
  production,
  measures = "all",
  neighbours = 8,
  uncertainty_method = "correlation",
  functional_load_method = "correlation"
)

dim(comprehension_measures)
names(comprehension_measures)
head(comprehension_measures)

dim(production_measures)
names(production_measures)
head(production_measures)
```

### 2.2 Diagnose the results

Missing, infinite, or constant columns may be mathematically possible,
but they can also reveal incompatible data or a failed calculation.
Always check them before continuing.

``` r

check_measure_values(comprehension_measures)
check_measure_values(production_measures)

# A shorter display containing only questionable columns:
check_measure_values(comprehension_measures, problems_only = TRUE)
check_measure_values(production_measures, problems_only = TRUE)
```

Do not delete a problematic measure automatically. First determine why
it is missing or constant and whether that is meaningful for the data.

### 2.3 Save all measures in one data frame

Comprehension and production share some measure names. Prefixing them
preserves their direction and prevents accidental duplicate column
names.

``` r

stopifnot(identical(
  as.character(comprehension_measures$item),
  as.character(production_measures$item)
))

comprehension_values <- comprehension_measures[, -1, drop = FALSE]
production_values <- production_measures[, -1, drop = FALSE]

names(comprehension_values) <- paste0("comprehension_", names(comprehension_values))
names(production_values) <- paste0("production_", names(production_values))

all_ldl_measures <- data.frame(
  item = comprehension_measures$item,
  comprehension_values,
  production_values,
  check.names = FALSE
)

dim(all_ldl_measures)
head(all_ldl_measures)

write.csv(
  all_ldl_measures,
  file = "all_ldl_measures.csv",
  row.names = FALSE
)
```

> **Task 4.** Open the saved CSV and identify one comprehension measure
> and one production measure. Why are the prefixes important?

## 3. Path extension: from C-hat to a word form

The production mapping stops at **C-hat**, a graded vector of predicted
cue support. Producing an ordered word form requires an additional
path-search step that finds sequences of mutually compatible cues.

> **Warning: shown for reference only. Do not run this block during the
> exercise.** Path search can take many hours for a realistically sized
> vocabulary. Its duration depends on the vocabulary, cue inventory,
> algorithm, and search settings, so a short completion time cannot be
> guaranteed.

The following code is deliberately not evaluated when this page is
built:

``` r

forms <- produce_forms(
  production = production,
  comprehension = comprehension,
  cues = cues,
  method = "learn",
  max_candidates = 10,
  threshold = -1,
  verbose = TRUE
)

forms
head(forms$items)
head(forms$candidates)

form_measures <- compute_measures(forms, measures = "all")
check_measure_values(form_measures)
```

`forms$items` gives item-level results, while `forms$candidates`
contains the candidate paths retained by the search. Path-dependent
measures become available only after this extension.

## 4. Frequency-informed LDL

End-state learning treats every type once. Frequency-informed learning
gives more frequent types greater influence. The frequency vector must
contain one finite, non-negative value for every row of **C** and **S**,
in their exact row order.

If the original data contain multiple observations per word, first
reduce the frequency information to one value per type. The following
example assumes that `LogFreq.Zipf.` is constant within word type.

``` r

dat$frequency <- round(exp(dat$LogFreq.Zipf.))

type_frequency <- aggregate(
  frequency ~ word,
  data = dat,
  FUN = function(x) x[1]
)

word_frequency <- type_frequency$frequency[
  match(words, type_frequency$word)
]

stopifnot(
  length(word_frequency) == length(words),
  !anyNA(word_frequency),
  all(is.finite(word_frequency)),
  all(word_frequency >= 0),
  identical(words, rownames(S)),
  identical(words, rownames(cues$C))
)
```

[`match()`](https://rdrr.io/r/base/match.html) is crucial: it returns
frequencies in `words` order rather than the alphabetical order often
produced by [`aggregate()`](https://rdrr.io/r/stats/aggregate.html).

``` r

comprehension_frequency <- compute_comprehension(
  C = cues,
  S = S,
  learning = "frequency",
  frequency = word_frequency
)

production_frequency <- compute_production(
  S = S,
  C = cues,
  learning = "frequency",
  frequency = word_frequency
)

comprehension_frequency
production_frequency
```

> **Task 5.** Compare the accuracy and selected measures of the
> end-state and frequency-informed models. Which differences do you
> observe? Why should a difference not automatically be called an
> improvement?

## 5. Incremental LDL

Incremental learning updates connection weights trial by trial.
Therefore the learning sequence, learning rate, number of epochs, and
random seed matter. A frequency vector can generate repeated exposures;
using one exposure per word, as below, provides a small first
demonstration.

``` r

comprehension_incremental <- compute_comprehension(
  C = cues,
  S = S,
  learning = "incremental",
  frequency = rep(1L, length(words)),
  epochs = 2,
  learning_rate = 0.1,
  seed = 123
)

production_incremental <- compute_production(
  S = S,
  C = cues,
  learning = "incremental",
  frequency = rep(1L, length(words)),
  epochs = 2,
  learning_rate = 0.1,
  seed = 123
)

comprehension_incremental
production_incremental
```

The seed makes the randomized learning order reproducible. Keeping the
seed, epochs, and learning rate in an analysis script is therefore part
of reporting the model, not merely a technical detail.

> **Task 6.** Refit one incremental mapping with another seed. Then
> refit it with `seed = 123`. Which result is reproduced, and why?

## 6. Using LDL measures in regression analysis

*This section will be added later.*

## What you should now be able to do

You should now be able to explain what **C**, **S**, **F**, **G**,
**S-hat**, and **C-hat** represent; fit comprehension and production
mappings; compute and diagnose measures; combine the measures in one
clearly named data frame; and distinguish end-state, frequency-informed,
and incremental learning. The path extension is a separate, potentially
very expensive step and is not required for analyses that stop at
predicted cue support.
