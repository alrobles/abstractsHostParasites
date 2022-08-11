#' prep_fun
#' @description Preprocesing function. Change all characters to lower case
#' replace the alfanumerics and remove the spaces and the line breaks
#'
#' @param x String with an abstract (or title) to preprocess
#'
#' @return A processed string
#' @export
#'
#' @examples
#' \dontrun{
#' prep_fun("This is an Example  of the string")
#' }
prep_fun = function(x) {
  # make text lower case
  x = stringr::str_to_lower(x)
  # remove non-alphanumeric symbols
  x = stringr::str_replace_all(x, "[^[:alnum:]]", " ")
  # collapse multiple spaces
  x = stringr::str_replace_all(x, "\\s+", " ")
  # collapse multiple line breaks
  x = stringr::str_replace_all(x, "\\n+", " ")
}
