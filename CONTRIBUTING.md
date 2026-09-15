# Contributing to ldlr

Bug reports and focused pull requests are welcome at
<https://github.com/dosc91/ldlr>.

## Documentation

Function reference pages are generated from roxygen comments in `R/`. Longer
guides live in `vignettes/`, and navigation is configured in `_pkgdown.yml`.
After changing a public function, update its R behavior and underlying Julia
implementation notes together.

Build the documentation locally with:

```r
devtools::document()
pkgdown::build_site()
```

The `pkgdown` GitHub Actions workflow builds the site and deploys it to the
`gh-pages` branch. In the repository settings, configure GitHub Pages to deploy
from that branch and its root directory. The public URL is
<https://dosc91.github.io/ldlr/>.

Examples in the long guides do not run while the website is built because a
site build should not install Julia, download semantic vectors, or perform
expensive model fitting. Executable behavior is covered by package tests.

