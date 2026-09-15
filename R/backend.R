.ldlr_backend <- new.env(parent = emptyenv())
.ldlr_backend$ready <- FALSE
.ldlr_backend$module <- NULL

.ldlr_julia_path <- function(julia = NULL) {
  homes <- unique(c(
    path.expand("~"),
    Sys.getenv("USERPROFILE", unset = NA_character_),
    Sys.getenv("HOME", unset = NA_character_)
  ))
  homes <- homes[!is.na(homes) & nzchar(homes)]
  explicit <- c(julia, getOption("ldlr.julia"),
                Sys.getenv("LDLR_JULIA", unset = NA_character_))
  standard <- if (.Platform$OS.type == "windows") {
    c(
      # JuliaCall installs Juliaup versions here. Prefer the real executable to
      # the Microsoft Store/App Installer alias, whose location is not JULIA_BINDIR.
      unlist(lapply(homes, function(home) {
        Sys.glob(file.path(home, ".julia", "juliaup", "julia-*", "bin", "julia.exe"))
      }), use.names = FALSE),
      Sys.glob(file.path(Sys.getenv("LOCALAPPDATA"), "Programs", "Julia-*", "bin", "julia.exe")),
      file.path(homes, ".juliaup", "bin", "julia.exe")
    )
  } else {
    c(
      file.path(homes, ".juliaup", "bin", "julia"),
      Sys.glob("/Applications/Julia-*.app/Contents/Resources/julia/bin/julia"),
      "/usr/local/bin/julia", "/opt/homebrew/bin/julia"
    )
  }
  candidates <- c(
    explicit,
    standard,
    Sys.which("julia")
  )
  candidates <- candidates[!is.na(candidates) & nzchar(candidates)]
  candidates <- unique(normalizePath(candidates, winslash = "/", mustWork = FALSE))
  candidates <- candidates[file.exists(candidates)]
  if (.Platform$OS.type == "windows") {
    candidates <- candidates[!grepl(
      "/AppData/Local/Microsoft/(WindowsApps/)?julia(\\.exe)?$",
      candidates, ignore.case = TRUE
    )]
  }
  if (!length(candidates)) return(NULL)
  candidates[[1L]]
}

#' Inspect the Julia backend
#'
#' Reports Julia discovery, the selected executable, package environment, and
#' whether the backend is currently usable. This function performs its checks
#' in R. A backend smoke test, when requested during setup, loads JudiLing and
#' fits a small mapping with `JudiLing.make_transform_matrix()`.
#' @export
ldlr_status <- function(julia = NULL) {
  path <- .ldlr_julia_path(julia)
  list(
    julia_found = !is.null(path) && file.exists(path),
    julia = path,
    connector_available = requireNamespace("JuliaConnectoR", quietly = TRUE),
    backend_ready = isTRUE(.ldlr_backend$ready)
  )
}

#' Install or configure Julia and the ldlr backend
#'
#' From R, this function locates or installs Julia, creates an isolated Julia
#' environment, installs JudiLing and its dependencies, loads the package's
#' `LDLRBackend` module, and runs a numerical smoke test. Julia package
#' management is performed programmatically; users do not need Julia syntax.
#'
#' @param julia Optional path to the Julia executable.
#' @param install_julia Install Julia when it cannot be found.
#' @param install_packages Install JudiLing and JudiLingMeasures in an isolated environment.
#' @export
setup_julia <- function(julia = NULL, install_julia = interactive(),
                        install_packages = TRUE) {
  path <- .ldlr_julia_path(julia)
  if (is.null(path) || !file.exists(path)) {
    if (!isTRUE(install_julia)) {
      .ldlr_stop("Julia was not found. Supply `julia`, set `options(ldlr.julia=...)`, or use `install_julia = TRUE`.")
    }
    if (!requireNamespace("JuliaCall", quietly = TRUE)) {
      .ldlr_stop(
        "Automatic Julia installation requires the optional R package `JuliaCall`. ",
        "Install it first, or install Julia with Juliaup and supply its executable path."
      )
    }
    JuliaCall::install_julia()
    path <- .ldlr_julia_path(julia)
    if (is.null(path) || !file.exists(path)) {
      .ldlr_stop("Julia was installed but its executable was not detected. Supply its path in `setup_julia(julia = ...)`.")
    }
  }

  Sys.setenv(JULIA_BINDIR = dirname(path))
  backend_file <- system.file("julia", "LDLRBackend.jl", package = "ldlr")
  if (!nzchar(backend_file)) .ldlr_stop("The bundled Julia backend could not be found.")
  project <- tools::R_user_dir("ldlr", "data")
  dir.create(project, recursive = TRUE, showWarnings = FALSE)
  options(ldlr.julia_project = project, ldlr.julia = path)

  quoted_project <- encodeString(normalizePath(project, winslash = "/", mustWork = FALSE), quote = '"')
  if (install_packages) {
    JuliaConnectoR::juliaEval(paste0(
      "ENV[\"JULIA_PKG_PRECOMPILE_AUTO\"] = \"0\"; ",
      "import Pkg; Pkg.activate(", quoted_project, "); ",
      # These are direct backend/connector imports and therefore must be direct
      # project dependencies, even though JudiLing also depends on them.
      "Pkg.add([\"DataFrames\", \"Tables\"]); ",
      "Pkg.add(Pkg.PackageSpec(name=\"JudiLing\", version=\"1\")); ",
      "Pkg.add(Pkg.PackageSpec(url=\"https://github.com/quantling/JudiLingMeasures.jl\")); ",
      "Pkg.precompile()"
    ))
    # JuliaConnectoR initially loads Tables from its default environment. Start
    # a clean process so dependencies are loaded consistently from ldlr's project.
    JuliaConnectoR::stopJulia()
  }
  project_option <- paste0("--project=", quoted_project)
  existing_options <- Sys.getenv("JULIACONNECTOR_JULIAOPTS")
  if (!grepl("(^|[[:space:]])--project(=|[[:space:]])", existing_options)) {
    Sys.setenv(JULIACONNECTOR_JULIAOPTS = trimws(paste(existing_options, project_option)))
  }
  JuliaConnectoR::juliaEval(paste0("import Pkg; Pkg.activate(", quoted_project, ")"))
  JuliaConnectoR::juliaEval(paste0("include(",
    encodeString(normalizePath(backend_file, winslash = "/"), quote = '"'), ")"))
  .ldlr_backend$module <- JuliaConnectoR::juliaImport("Main.LDLRBackend")
  if (!isTRUE(.ldlr_backend$module$smoke_test())) {
    .ldlr_stop("The Julia backend smoke test failed.")
  }
  .ldlr_backend$ready <- TRUE
  invisible(ldlr_status(path))
}

.ldlr_require_backend <- function() {
  if (!isTRUE(.ldlr_backend$ready)) setup_julia(install_julia = interactive())
  .ldlr_backend$module
}

.ldlr_fit_backend <- function(X, Y, learning, frequency, epochs,
                              learning_rate, learning_sequence, seed, shift = 0.02) {
  backend <- .ldlr_require_backend()
  X <- as.matrix(X)
  Y <- as.matrix(Y)
  if (is.null(frequency)) frequency <- numeric()
  if (is.null(learning_sequence)) learning_sequence <- integer()
  backend$fit_mapping(X, Y, learning, as.numeric(frequency), as.integer(epochs),
                      as.numeric(learning_rate), as.integer(learning_sequence),
                      as.integer(seed), as.numeric(shift))
}

.ldlr_loo_backend <- function(X, Y, shift, chunk_size, progress) {
  backend <- .ldlr_require_backend()
  X <- as.matrix(X)
  Y <- as.matrix(Y)
  state <- backend$prepare_loo(X, Y, as.numeric(shift))
  predictions <- matrix(NA_real_, nrow(X), ncol(Y))
  groups <- split(seq_len(nrow(X)),
                  ceiling(seq_len(nrow(X)) / as.integer(chunk_size)))
  progress_bar <- if (isTRUE(progress)) {
    utils::txtProgressBar(min = 0L, max = length(groups), style = 3L)
  } else NULL
  if (!is.null(progress_bar)) on.exit(close(progress_bar), add = TRUE)
  for (i in seq_along(groups)) {
    rows <- groups[[i]]
    chunk <- .ldlr_julia_get(
      backend$loo_predictions_chunk(state, as.integer(rows))
    )
    predictions[rows, ] <- as.matrix(chunk)
    if (!is.null(progress_bar)) utils::setTxtProgressBar(progress_bar, i)
  }
  predictions
}

.ldlr_endstate_backend <- function(X, Y, shift = 0.02) {
  backend <- .ldlr_require_backend()
  .ldlr_julia_get(backend$fit_endstate(as.matrix(X), as.matrix(Y), as.numeric(shift)))
}

.ldlr_measure_backend <- function(predicted, target, names, neighbours,
                                  uncertainty_method = "correlation") {
  backend <- .ldlr_require_backend()
  .ldlr_julia_get(backend$matrix_measures(
    as.matrix(predicted), as.matrix(target), as.character(names),
    as.integer(neighbours), uncertainty_method
  ))
}

.ldlr_julia_get <- function(x) {
  if (is.null(x)) return(NULL)
  if (inherits(x, "JuliaProxy")) {
    x <- JuliaConnectoR::juliaGet(x)
  }
  .ldlr_normalize_julia(x)
}

.ldlr_normalize_julia <- function(x) {
  if (is.data.frame(x) || !is.list(x)) return(x)
  if (identical(sort(names(x)), c("keys", "values"))) {
    keys <- as.character(unlist(x$keys, recursive = TRUE, use.names = FALSE))
    values <- lapply(x$values, .ldlr_normalize_julia)
    if (length(keys) != length(values)) {
      .ldlr_stop("Julia returned a dictionary with unequal key and value counts.")
    }
    names(values) <- keys
    return(values)
  }
  attributes_x <- attributes(x)
  x <- lapply(x, .ldlr_normalize_julia)
  if (!is.null(attributes_x$names)) names(x) <- attributes_x$names
  x
}

.ldlr_cue_measure_backend <- function(direction, mapping, predicted, target,
                                      paths, cue_names, names, functional_load_method) {
  backend <- .ldlr_require_backend()
  index_paths <- lapply(paths, function(path) {
    indices <- match(path, cue_names)
    if (anyNA(indices)) .ldlr_stop("A cue path contains cues absent from the model matrix.")
    as.character(indices)
  })
  .ldlr_julia_get(backend$cue_measures(
    direction, as.matrix(mapping), as.matrix(predicted), as.matrix(target),
    index_paths, as.character(names), functional_load_method
  ))
}

.ldlr_paths_backend <- function(train_words, words, C_train, S, F, Chat,
                                cue_names, n, boundary,
                                method, max_candidates, threshold, tolerant,
                                tolerance, max_tolerance, neighbours, verbose) {
  backend <- .ldlr_require_backend()
  .ldlr_julia_get(backend$produce_word_forms(
    as.character(train_words), as.character(words), as.matrix(C_train),
    as.matrix(S), as.matrix(F), as.matrix(Chat),
    as.character(cue_names), as.integer(n), boundary, method,
    as.integer(max_candidates), as.numeric(threshold), tolerant,
    as.numeric(tolerance), as.integer(max_tolerance), as.integer(neighbours),
    verbose
  ))
}
