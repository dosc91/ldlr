# Configure the Julia backend

Locate Julia, activate an isolated ldlr environment, install
dependencies, load the adapter, and run a smoke test.

## Usage

``` r
setup_julia(julia = NULL, install_julia = interactive(), install_packages = TRUE)

ldlr_status(julia = NULL)
```

## Arguments

- julia:

  Optional path to the Julia executable.

- install_julia:

  Whether the optional JuliaCall installer may install Julia.

- install_packages:

  Whether to install and precompile compatible Julia dependencies.

## Value

A status list, invisibly for `setup_julia()`.

## Details

The workflow is controlled from R and requires no Julia syntax. It
installs Julia when requested, manages a package-specific Julia
environment, loads JudiLing and the ldlr backend, and tests the
connection with a small call to `JudiLing.make_transform_matrix()`.
`ldlr_status()` performs R-side discovery and reports the selected
executable and environment.
