#' search_abstract_with_rentrez
#'
#' @param DOI A valid DOI
#' @param TITLE A title to validate the search
#' @param APIKEY A entrez API key
#' @importFrom rentrez entrez_search entrez_fetch
#' @importFrom tibble tibble
#' @importFrom XML xmlToList
#' @importFrom stringdist stringsim
#' @importFrom purrr map_df map_chr
#' @importFrom dplyr filter slice
#' @importFrom rlang .data
#' @importFrom stringr str_to_lower str_replace_all
#' @return a data frame with doi title abstract
#' @export
#'
#' @examples
#' \dontrun{
#' doi <- "10.3389/fvets.2021.604560"
#' title <- "American Mammals Susceptibility to Dengue"
#' search_abstract_pubmed(
#' doi,
#' title
#' )
#' }
search_abstract_pubmed <-
  function(DOI = NULL, TITLE, APIKEY = NULL){

    if(is.null(APIKEY)){
      another_search <- rentrez::entrez_search(db = "pubmed",
                                               term=TITLE,
                                               retmax=10
      )
    } else {
      another_search <- rentrez::entrez_search(db = "pubmed",
                                               term = TITLE,
                                               retmax = 10,
                                               api_key = APIKEY
      )
    }


    if(length(another_search$ids) == 0){
      df = tibble::tibble(doi = NA_character_,
                          title = NA_character_,
                          abstract = NA_character_,
                          year = NA_real_,
                          month = NA_real_,
                          day = NA_real_
                          )
    } else {
      df <- purrr::map_df(another_search$ids, function(x){
        paper_rec <- rentrez::entrez_fetch(db="pubmed", id = x, rettype="xml", parsed=TRUE)
        paper_rec_list <- XML::xmlToList(paper_rec)
        search_title <- paper_rec_list$PubmedArticle$MedlineCitation$Article$ArticleTitle
        search_abstract <- paper_rec_list$PubmedArticle$MedlineCitation$Article$Abstract$AbstractText
        pmid <- paper_rec_list$PubmedArticle$MedlineCitation$PMID$text

        articleidlist <- paper_rec_list$PubmedArticle$PubmedData$ArticleIdList

        articleidnames <- articleidlist %>% purrr::map_chr(function(x) x$.attrs)
        articleid <- articleidlist %>% purrr::map_chr(function(x) x$text)
        names(articleid) <- articleidnames

        doi <- articleid["doi"]

        if( any(articleidnames == "doi")){
          doi <- articleid["doi"]
        } else if(!is.null(DOI)) {
          doi <- DOI
        } else {
          doi <- NA
        }
        year <- paper_rec_list$PubmedArticle$MedlineCitation$Article$ArticleDate$Year
        month <- paper_rec_list$PubmedArticle$MedlineCitation$Article$ArticleDate$Month
        day <- paper_rec_list$PubmedArticle$MedlineCitation$Article$ArticleDate$Day


        if(length(search_title) > 2){
          search_title = paste0(search_title, collapse = " ")
        }

        if(length(search_abstract) > 2){
          search_abstract = paste0(search_abstract, collapse = " ")
        }

        if(is.list(search_abstract)  && identical(names(search_abstract) , c("text", ".attrs") ) ){
          search_abstract = search_abstract$text
        }
        tibble::tibble(doi, search_title, search_abstract, pmid, year, month, day)

      })

      original_title <- TITLE
      search_title <- df$search_title
      prep_fun = function(x) {
        # make text lower case
        x = stringr::str_to_lower(x)
        # remove non-alphanumeric symbols
        x = stringr::str_replace_all(x, "[^[:alnum:]]", " ")
        # collapse multiple spaces
        stringr::str_replace_all(x, "\\s+", " ")
      }
      df$sim <- stringdist::stringsim(prep_fun(original_title), prep_fun(search_title))
      df$title <- search_title
      #df$doi = DOI

      df <- dplyr::filter(df, .data$sim == max(.data$sim))
      if(length(df) > 1){
        df <- dplyr::slice(df, 1)
      }
      return(df)
    }
  }
