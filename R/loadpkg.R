#' Load package function. Original in jsonlite package
#'
#' @param pkg The name of a R package to load
#' @noRd
loadpkg <- function (pkg)
{
  tryCatch(getNamespace(pkg), error = function(e) {
    stop("Required package ", pkg, " not found. Please run: install.packages('",
         pkg, "')", call. = FALSE)
  })
}
