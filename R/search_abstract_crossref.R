
#' Title
#'
#' @param doi A vaild doi to search in cross reference api
#' @param mailto A valid mail to the polite pool
#'
#' @return a Data frame with doi, title, abstract, year, month and day
#' @export
#' @importFrom httr2 request req_user_agent req_perform
#' @importFrom jsonlite fromJSON
#' @importFrom purrr map map_df
#' @importFrom dplyr bind_cols mutate rename
#' @importFrom stringr str_remove_all str_trim str_squish
#' @importFrom tibble as_tibble
#' @importFrom tidyr unnest
#' @importFrom rlang .data
#'
#' @examples
#' \dontrun{
#' #' doi <- "10.3389/fvets.2021.604560"
#' mail <- "your@@example.com"
#' search_abstract_crossref(doi, mail)
#' }

search_abstract_crossref <- function(doi = NULL, mailto = NULL){
  if(!is.null(mailto)){

    baseURL <- "https://api.crossref.org/works?select=DOI,title,abstract,published&filter=doi:"
    query <- paste0(baseURL, doi)
    req <- httr2::request(base_url = query)
    req_agent <- httr2::req_user_agent(req = req, string = mailto)
    bar <- function() {
      message("warning, bad request!. Return empty data frame")
      tibble::tibble(
        doi = NA_character_,
        title = NA_character_,
        abstract = NA_character_,
        year = NA_real_,
        month = NA_real_,
        day = NA_real_
      )
    }


    resp <- tryCatch(
      {
        httr2::req_perform(req)
      },
      error = function(e){
        bar()
      }
    )

    if(!all(is.na(resp))){
      works_sample <- jsonlite::fromJSON( rawToChar(resp$body) )
      works_table <- works_sample$message$items %>%
        tibble::as_tibble(.name_repair = 'unique') %>%
        dplyr::select(-.data$published) %>%
        tidyr::unnest(cols = "title")
      dates <- works_sample$message$items$published$`date-parts` %>%
        purrr::map(function(x)
          if(!is.null(x)){
            x
          } else{
            matrix(NA)
          }
        ) %>% purrr::map_df(tibble::as_tibble, .name_repair = 'unique')
      names(dates) <- c("year", "month", "day")
      works_table <- dplyr::bind_cols(works_table, dates) %>%
        dplyr::mutate(abstract = stringr::str_remove_all(.data$abstract, "<([a-z]+) *[^/]*?>")) %>%
        dplyr::mutate(abstract = stringr::str_remove_all(.data$abstract, "<*[^/]*?([a-z]+)>")) %>%
        dplyr::mutate(abstract = stringr::str_remove_all(.data$abstract, "</")) %>%
        dplyr::mutate(abstract = stringr::str_trim(.data$abstract, "both")) %>%
        dplyr::mutate(abstract = stringr::str_squish(string = .data$abstract))
      works_table <- works_table %>%
        dplyr::rename(doi = .data$DOI)
      return(works_table)
    } else {
      works_table <-  resp
      return(works_table)
    }

  } else{
    stop("Provide an email")
  }
}
