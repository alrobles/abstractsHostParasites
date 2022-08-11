#' Search Abstrac
#' @description This function search an abstract in crossref
#' (if there is any DOI) or search in PubMed with entrez API
#'
#' @param doi A valid doi
#' @param title A title for search if does not have a doi
#' @param email An email for the pool in the crossref API
#' @param APIKEY An entrez API KEY
#' @importFrom dplyr rename select
#' @importFrom rlang .data
#'
#'
#' @return A data frame with abstracts
#' @export
#'
#' @examples
#' #' \dontrun{
#' doi <- "10.3389/fvets.2021.604560"
#' title <- "American Mammals Susceptibility to Dengue"
#' search_abstract(
#' doi,
#' title
#' )
#' }
search_abstract <- function(doi = NULL, title = NULL, email = NULL, APIKEY = NULL){
  if(!is.null(doi)){
    search_table <- search_abstract_crossref(
      doi,
      email
    )
    #return(search_table)

  }
  if(is.na(search_table$abstract)){
    cat("Search in crossref not sucsesfull. Searching in  PubMed")
    if(is.null(title)){
      title = doi
    }
    search_table <- search_abstract_pubmed(
      doi,
      title,
      APIKEY = APIKEY
    )
    search_table <- search_table %>%
      dplyr::rename(abstract = .data$search_abstract) %>%
      dplyr::select(.data$doi, .data$title, .data$abstract, .data$year, .data$month, .data$day)
    return(search_table)
  } else {
    return(search_table)
  }
}
