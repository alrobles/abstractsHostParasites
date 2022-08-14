#' get_class_score
#' @description Function to get a classification score given an abstract
#' classification model and vocabulary associated with the model.
#' Evaluates a string (abstracts) and returs the probability to belong a class
#'
#' @param model A PU learning model. Can provide from
#' automodel_pu_abstracts
#' @param vocabulary A vocabulary asociated to the PU learning model.
#' @param abstract A long string with the abstract to be evaluated
#'
#' @return A numeric value from 0 to 1. Is interpreted as the probability
#' of belonging to the class of the data set modeled.
#' @export
#'
#' @examples
#' library(dplyr)
#' output <- automodel_pu_abstracts(df_abstracts_sample, term_count = 20)
#' df_abstracts_score <- df_abstracts_sample %>%
#'   dplyr::slice(1:100) %>%
#'   dplyr::select(abstract, class) %>%
#'   dplyr::mutate(score = purrr::map_dbl(abstract, function(x){
#'       get_class_score(
#'       model = output$model$fit.pi,
#'       vocabulary =  output$vocabulary,
#'       abstract = x)
#'       }) )
get_class_score <- function(model, vocabulary, abstract){

  vectorizer <-  vocab_vectorizer(vocabulary)

  classification_score <- if(nchar(abstract) > 10){
    trial_text <- abstract
    trial_text <- prep_fun(trial_text)
    it_test = text2vec::itoken(trial_text, progressbar = FALSE)
      dtm_test = text2vec::create_dtm(it = it_test, vectorizer = vectorizer)
    preds = predict(model, dtm_test, type = 'response')[,1]
    return(preds)
  } else {
    return(0)
  }
}
