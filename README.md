
<!-- README.md is generated from README.Rmd. Please edit that file -->

# abstractsHostParasites

<!-- badges: start -->
<!-- badges: end -->

The goal of this R package abstractsHostParasites is to hold tools for
generate text classification models and process data associated with
this task.

## Installation

You can install the development version of abstractsHostParasites from
[GitHub](https://github.com/) with:

``` r
# install.packages("devtools")
devtools::install_github("alrobles/abstractsHostParasites")
```

## Acplication case

The main goals of this project is to have a model that given an abstract
can classify if this abstrac belongs to a specific category.

An application case is to consider articles related to host-parasite
interactions from open databases. In we case we get refered citations in
[Zover](http://www.mgc.ac.cn/cgi-bin/ZOVER/main.cgi) and Glogal mammal
parasite database [GMPD](https://gmpd2.ecology.uga.edu/)

## Example

This is a basic example which shows you how to solve a common problem:

``` r
library(abstractsHostParasites)
## basic example code
```

What is special about using `README.Rmd` instead of just `README.md`?
You can include R chunks like so:

``` r
summary(cars)
#>      speed           dist       
#>  Min.   : 4.0   Min.   :  2.00  
#>  1st Qu.:12.0   1st Qu.: 26.00  
#>  Median :15.0   Median : 36.00  
#>  Mean   :15.4   Mean   : 42.98  
#>  3rd Qu.:19.0   3rd Qu.: 56.00  
#>  Max.   :25.0   Max.   :120.00
```

You’ll still need to render `README.Rmd` regularly, to keep `README.md`
up-to-date. `devtools::build_readme()` is handy for this. You could also
use GitHub Actions to re-render `README.Rmd` every time you push. An
example workflow can be found here:
<https://github.com/r-lib/actions/tree/v1/examples>.

You can also embed plots, for example:

<img src="man/figures/README-pressure-1.png" width="100%" />

In that case, don’t forget to commit and push the resulting figure
files, so they display on GitHub and CRAN.
