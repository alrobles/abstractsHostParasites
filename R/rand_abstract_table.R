#' Random abstract table
#' @description This function retrives a table with 100 random abstracts from
#' crossref api at https://api.crossref.org/works?. Use an email to identify in
#' the pool and connect to the crossref API through httr2 package.
#'
#' @param mailto A vaild mail addres to the pool
#' @param n A number of abstracts to retrive. Default is 100
#' @return a data frame with doi, title abstract, year, month and day
#' @importFrom httr2 request req_user_agent req_perform
#' @importFrom jsonlite fromJSON
#' @importFrom purrr map map_df
#' @importFrom dplyr bind_cols mutate rename
#' @importFrom stringr str_remove_all str_trim str_squish
#' @importFrom tibble as_tibble
#' @importFrom tidyr unnest
#' @importFrom rlang .data
#' @export
#'
#' @examples
#' rand_abstract_table(mailto = "alroble8@@asu.edu", n = 1)
#'
rand_abstract_table <- function(mailto = NULL, n = 100){
  if(!is.null(mailto)){
    basUrl <- "https://api.crossref.org/works?sample="
    filterString <- "&filter=has-abstract:1&select=DOI,title,abstract,published"
    url <- paste0(basUrl, n, filterString)
    req <- httr2::request(base_url = url)
    req_agent <- httr2::req_user_agent(req = req, string = mailto)
    resp <- httr2::req_perform(req)
    works_sample <- jsonlite::fromJSON( rawToChar(resp$body) )
    works_table <- works_sample$message$items %>%
      tibble::as_tibble() %>%
      dplyr::select(-.data$published) %>%
      tidyr::unnest(cols = "title")

    suppressWarnings(
      dates <- works_sample$message$items$published$`date-parts` %>%
        purrr::map(function(x)
          if(!is.null(x)){
            x
          } else{
            matrix(NA)
          }
        ) %>%
        purrr::map_df(tibble::as_tibble)
    )
    names(dates) <- c("year", "month", "day")
    works_table <- dplyr::bind_cols(works_table, dates) %>%
      dplyr::mutate(abstract = stringr::str_remove_all(.data$abstract, "<([a-z]+) *[^/]*?>")) %>%
      dplyr::mutate(abstract = stringr::str_remove_all(.data$abstract, "<*[^/]*?([a-z]+)>")) %>%
      dplyr::mutate(abstract = stringr::str_remove_all(.data$abstract, "</")) %>%
      dplyr::mutate(abstract = stringr::str_trim(.data$abstract, "both")) %>%
      dplyr::mutate(abstract = stringr::str_squish(string = .data$abstract))
    works_table %>%
      dplyr::rename(doi = .data$DOI)

  } else{
    stop("Provide an email")
  }
}
