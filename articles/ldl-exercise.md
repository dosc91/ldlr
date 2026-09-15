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

The supplied `dat.RData` uses descriptive names throughout:

| Variable | Meaning |
|----|----|
| `word` | presented word |
| `participant_id` | participant identifier |
| `sentence_id` | sentence identifier |
| `sentence_order` | position of the sentence in the presentation sequence |
| `question_correctness` | trial-level response to the comprehension question |
| `question_response_time_ms` | response time for that question in milliseconds |
| `word_position` | position of the word within its sentence |
| `RT` | self-paced reading time in milliseconds |
| `age_years` | participant age in years |
| `english_onset_age` | age at which the participant began learning English |
| `sex` | participant sex |
| `handedness` | participant handedness |
| `participant_accuracy` | participant’s overall comprehension accuracy |
| `word_length` | word length in letters |
| `zipf_frequency` | SUBTLEX-UK frequency on the Zipf scale |

``` r

library(ldlr)

# This file loads one object called dat.
load("dat.RData")
stopifnot(exists("dat"), is.data.frame(dat))

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

# Identify measures that contain more than one value per lexical item.
list_columns <- names(all_ldl_measures)[
  vapply(all_ldl_measures, is.list, logical(1L))
]
list_columns
```

Some cue-dependent measures are **list-columns**. For example,
functional load contains one value for every cue in a word, so different
rows can contain vectors of different lengths. This is valid inside an R
data frame, but the CSV format cannot represent such vectors as numeric
values in a single cell.

Save the complete object as an RDS file. This preserves every scalar and
every cue-level vector exactly and can be read back with
[`readRDS()`](https://rdrr.io/r/base/readRDS.html).

``` r

saveRDS(all_ldl_measures, file = "all_ldl_measures.rds")

# Check that the saved object is identical to the original.
all_ldl_measures_reloaded <- readRDS("all_ldl_measures.rds")
stopifnot(identical(all_ldl_measures, all_ldl_measures_reloaded))
```

For a conventional CSV with exactly one scalar value per item and
column, exclude list-columns explicitly:

``` r

scalar_ldl_measures <- all_ldl_measures[
  !vapply(all_ldl_measures, is.list, logical(1L))
]

write.csv(
  scalar_ldl_measures,
  file = "scalar_ldl_measures.csv",
  row.names = FALSE
)
```

If cue-level functional load is needed in CSV format, store it as a
**long** table: one row per item and cue. This preserves the numeric
values instead of turning a vector into text such as
`c(0.32, 0.17, ...)`.

``` r

functional_load_long <- do.call(
  rbind,
  lapply(seq_along(words), function(i) {
    values <- comprehension_measures$functional_load[[i]]
    data.frame(
      item = comprehension_measures$item[i],
      cue = cues$paths[[i]],
      cue_position = seq_along(values),
      functional_load = as.numeric(values),
      stringsAsFactors = FALSE
    )
  })
)

rownames(functional_load_long) <- NULL
head(functional_load_long)

write.csv(
  functional_load_long,
  file = "comprehension_functional_load.csv",
  row.names = FALSE
)
```

> **Task 4.** Open `scalar_ldl_measures.csv` and identify one
> comprehension measure and one production measure. Then inspect
> `comprehension_functional_load.csv`: how many rows belong to the first
> word, and how does that number relate to its trigrams? Why are both
> the direction prefixes and the long cue-level format important?

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
example assumes that `zipf_frequency` is constant within word type. A
Zipf value is logarithmic; the transformation below recovers relative
frequency weights while subtracting a constant to keep the numbers
manageable.

``` r

dat$frequency_weight <- 10 ^ (
  dat$zipf_frequency - min(dat$zipf_frequency, na.rm = TRUE)
)

type_frequency <- aggregate(
  frequency_weight ~ word,
  data = dat,
  FUN = function(x) x[1]
)

word_frequency <- type_frequency$frequency_weight[
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

LDL measures can be added to a statistical model of behavioural
observations. Here, the dependent variable is self-paced reading time in
milliseconds. The analysis proceeds cumulatively:

1.  a **basic model** contains participant characteristics;
2.  a **linguistic model** adds established lexical predictors; and
3.  an **LDL model** adds theoretically selected LDL measures.

This ordering asks whether lexical variables improve on the basic model
and whether LDL measures provide information beyond those lexical
variables.

> **Important:** Choose LDL predictors for theoretical reasons before
> looking at their p-values. Trying every available measure and
> retaining only the significant ones would make the reported evidence
> too optimistic.

### 6.1 Prepare the data

The LDL table has one row per word type, whereas `dat` has many
token-level observations per word. The merge therefore attaches the same
type-level LDL values to every occurrence of that word.

``` r

library(lme4)
library(lmerTest)
library(ggplot2)

# Use the in-memory table created in Section 2. Reading the scalar CSV instead
# would also work:
# ldl_measures <- read.csv("scalar_ldl_measures.csv")
ldl_measures <- scalar_ldl_measures
names(ldl_measures)[names(ldl_measures) == "item"] <- "word"

stopifnot(
  !anyDuplicated(ldl_measures$word),
  all(ldl_measures$word %in% dat$word)
)

# Scale every usable numeric scalar measure. Scaling gives each measure a mean
# of zero and a standard deviation of one, making coefficients easier to
# compare. Constant columns cannot be scaled and are excluded.
numeric_measures <- names(ldl_measures)[
  vapply(ldl_measures, is.numeric, logical(1L))
]

scalable_measures <- numeric_measures[
  vapply(
    ldl_measures[numeric_measures],
    function(x) {
      observed <- x[is.finite(x)]
      length(observed) > 1L && stats::sd(observed) > 0
    },
    logical(1L)
  )
]

scaled_measures <- as.data.frame(scale(ldl_measures[scalable_measures]))
names(scaled_measures) <- paste0(scalable_measures, "_scaled")
ldl_measures <- cbind(ldl_measures, scaled_measures)

dat_reg <- merge(
  dat,
  ldl_measures,
  by = "word",
  all = FALSE,
  sort = FALSE
)

# Remove impossible and exceptionally long responses before taking logs.
dat_reg <- subset(dat_reg, is.finite(RT) & RT > 0 & RT <= 8000)
dat_reg$RT_log <- log(dat_reg$RT)

# Mark grouping and categorical predictors explicitly as factors.
dat_reg$participant_id <- factor(dat_reg$participant_id)
dat_reg$word <- factor(dat_reg$word)
dat_reg$sex <- factor(dat_reg$sex)
dat_reg$handedness <- factor(dat_reg$handedness)

summary(dat_reg$RT)
nrow(dat_reg)
nlevels(dat_reg$participant_id)
nlevels(dat_reg$word)
```

The log transformation makes multiplicative differences in reading time
additive in the model. After exponentiation, a predicted value is again
on the millisecond scale.

> **Task 7.** Compare the number of rows before and after filtering.
> Inspect the excluded observations and explain why the filtering rule
> should be documented in a report.

### 6.2 Fit a basic model

The basic model controls for age, sex, and handedness. Random intercepts
allow participants to differ in their general response speed and words
to differ in their general difficulty.

``` r

mdl_basic <- lmer(
  RT_log ~
    age_years +
    sex +
    handedness +
    (1 | word) +
    (1 | participant_id),
  data = dat_reg,
  REML = FALSE
)

summary(mdl_basic)
anova(mdl_basic)
```

`REML = FALSE` fits by maximum likelihood, which is needed when models
with different fixed effects are compared.

### 6.3 Add established linguistic predictors

The linguistic model adds Zipf frequency and word length. Higher Zipf
values mean more frequent words; `word_length` is measured in letters.

``` r

mdl_ling <- lmer(
  RT_log ~
    age_years +
    sex +
    handedness +
    zipf_frequency +
    word_length +
    (1 | word) +
    (1 | participant_id),
  data = dat_reg,
  REML = FALSE
)

summary(mdl_ling)
anova(mdl_ling)
```

> **Task 8.** Determine the estimated directions of the frequency and
> length effects. Do they agree with the expectations that frequent
> words are read faster and longer words more slowly?

### 6.4 Add LDL measures

The LDL model adds five preselected measures. Their `_scaled` suffix
means that a one-unit change is a one-standard-deviation change in the
original measure.

``` r

mdl_ldl <- lmer(
  RT_log ~
    age_years +
    sex +
    handedness +
    zipf_frequency +
    word_length +
    comprehension_l2_scaled +
    comprehension_semantic_density_scaled +
    comprehension_target_correlation_scaled +
    production_uncertainty_scaled +
    production_semantic_support_for_form_scaled +
    (1 | word) +
    (1 | participant_id),
  data = dat_reg,
  REML = FALSE
)

summary(mdl_ldl)
ldl_tests <- anova(mdl_ldl)
ldl_tests
```

Interpret an LDL coefficient conditionally: it describes the association
with reading time while the other predictors in this model are held
constant. A coefficient alone does not establish a causal process.

### 6.5 Compare the models

All three models were fitted to the same rows and use maximum
likelihood, so their fit can be compared.

``` r

AIC(mdl_basic, mdl_ling, mdl_ldl)
anova(mdl_basic, mdl_ling, mdl_ldl)
```

Smaller AIC values indicate a better trade-off between fit and
complexity. The likelihood-ratio comparisons ask whether each larger
model improves fit enough to justify its additional parameters. Also
inspect the size and direction of individual coefficients; a
statistically detectable effect need not be large or theoretically
important.

> **Task 9.** Which model has the smallest AIC? Do the likelihood-ratio
> tests lead to the same ordering? Compare the coefficients shared by
> all models: do their estimates remain stable as predictors are added?

### 6.6 Plot LDL effects

In these data, inspect `ldl_tests` before deciding which effects warrant
a plot. The helper below creates fixed-effect predictions while holding
numeric covariates at their means, factors at their first level, and all
other scaled LDL measures at zero. Random effects are omitted, so the
lines describe the population-level model.

``` r

plot_ldl_effect <- function(model, data, predictor, points = 100L) {
  stopifnot(predictor %in% names(data))

  reference <- data[1, , drop = FALSE]
  reference$age_years <- mean(data$age_years, na.rm = TRUE)
  reference$zipf_frequency <- mean(data$zipf_frequency, na.rm = TRUE)
  reference$word_length <- mean(data$word_length, na.rm = TRUE)
  reference$sex <- factor(levels(data$sex)[1], levels = levels(data$sex))
  reference$handedness <- factor(
    levels(data$handedness)[1],
    levels = levels(data$handedness)
  )

  ldl_scaled <- grep(
    "^(comprehension|production)_.*_scaled$",
    names(reference),
    value = TRUE
  )
  reference[ldl_scaled] <- 0

  x <- seq(
    quantile(data[[predictor]], 0.025, na.rm = TRUE),
    quantile(data[[predictor]], 0.975, na.rm = TRUE),
    length.out = points
  )
  newdata <- reference[rep(1, points), , drop = FALSE]
  newdata[[predictor]] <- x
  newdata$predicted_RT <- exp(predict(
    model,
    newdata = newdata,
    re.form = NA,
    allow.new.levels = TRUE
  ))

  ggplot(newdata, aes(x = .data[[predictor]], y = predicted_RT)) +
    geom_line(linewidth = 1) +
    scale_y_continuous(
      limits = c(0, NA),
      expand = expansion(mult = c(0, 0.05))
    ) +
    labs(
      x = predictor,
      y = "Predicted reading time (ms)"
    ) +
    theme_bw()
}
```

For the current analysis, comprehension L2 and production semantic
support for form are the LDL measures showing evidence of an effect.
Plot them as follows:

``` r

plot_ldl_effect(
  mdl_ldl,
  dat_reg,
  "comprehension_l2_scaled"
)

plot_ldl_effect(
  mdl_ldl,
  dat_reg,
  "production_semantic_support_for_form_scaled"
)
```

These plots show model-adjusted associations rather than raw
correlations. The first asks how predicted reading time changes with
semantic prediction error; the second asks how it changes as the
predicted form receives greater support from the semantic vector.

> **Task 10.** Describe each line without using the words “significant”
> or “non-significant.” State its direction, approximate size across the
> displayed range, and a cautious linguistic interpretation.

## What you should now be able to do

You should now be able to explain what **C**, **S**, **F**, **G**,
**S-hat**, and **C-hat** represent; fit comprehension and production
mappings; compute and diagnose measures; combine the measures in one
clearly named data frame; distinguish end-state, frequency-informed, and
incremental learning; and test whether selected LDL measures improve a
regression analysis beyond basic and established linguistic predictors.
The path extension is a separate, potentially very expensive step and is
not required for analyses that stop at predicted cue support.
