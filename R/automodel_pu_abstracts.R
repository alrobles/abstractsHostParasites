#' Automodel is a function to create an abstract classfication
#' using a data frame with abstracts and two given target classes.
#' One of this is labeled as unknown. The model is carried out with
#' an implementation of the PU learning algorithm. (You can find information
#' of the algorithm in the function PLUS)
#'
#' @param abstracts_data_frame A data frame with abstracts and class of abstracts
#' to be classified using PU learning via PLUS function
#' @param term_count Minimum frequency a word should have in each document
#' @param objetive_class string with the label of the target class of abstracts
#' to classify
#' @param split_prop proportion of the training and testing data
#' to be considered for modeling.
#' @import text2vec
#' @importFrom dplyr mutate filter
#' @importFrom rlang .data
#' @importFrom rsample initial_split training testing
#' @importFrom stopwords stopwords
#' @return a list of 2 objects. A model and a vocabulary associated
#' to that model.
#' @export
#'
#' @examples
#' \dontrun{
#' data(df_abstracts_sample)
#' output <- automodel_pu_abstracts(df_abstracts_sample)
#' }
automodel_pu_abstracts <- function(abstracts_data_frame,
                                   term_count = 2,
                                   objetive_class = "parasite",
                                   split_prop = 0.65) {
  df_abstracts <- abstracts_data_frame %>%
    dplyr::mutate(label_obs = ifelse(.data$class == objetive_class, 1, 0))
  train_test_split <- rsample::initial_split(df_abstracts, prop = split_prop)
  db_abstracts_train <- rsample::training(train_test_split)
  db_abstracts_test <- rsample::testing(train_test_split)

  loadpkg("stringi")

  it_train = text2vec::itoken(db_abstracts_train$abstract,
                              preprocessor = prep_fun,
                              #tok_fun = word_tokenizer,
                              progressbar = FALSE)
  it_test = text2vec::itoken(db_abstracts_test$abstract,
                             preprocessor = prep_fun,
                             #tok_fun = word_tokenizer,
                             progressbar = FALSE)
  stop_words <- stopwords::stopwords()

  v <-  text2vec::create_vocabulary(it_train,
                                    ngram = c(1L, 5L),
                                    stopwords = stop_words)
  v <- v %>% dplyr::filter(!grepl(pattern = "^[0-9]", .data$term ))

  pruned_vocab = text2vec::prune_vocabulary(v,
                                            term_count_min = term_count
                                            #,doc_proportion_max = 0.5
                                            #,doc_proportion_min = 0.01
  )

  vectorizer <-  text2vec::vocab_vectorizer(pruned_vocab)
  dtm_train  <-  text2vec::create_dtm(it_train, vectorizer)
  dtm_test   <-  text2vec::create_dtm(it_test, vectorizer)

  tfidf = text2vec::TfIdf$new()
  dtm_df_tfidf_train_matrix <- text2vec::fit_transform(dtm_train, tfidf)
  dtm_df_tfidf_test  <- text2vec::fit_transform(dtm_test, tfidf)

  label_obs_vec <- db_abstracts_train$label_obs

  Prediction <- abstractsHostParasites::PLUS(train_data = dtm_df_tfidf_train_matrix,
                                             Label.obs = db_abstracts_train$label_obs,
                                             Sample_use_time = 30,
                                             l.rate = 1,
                                             qq = 0.1)

  return( list(model = Prediction, vocabulary = pruned_vocab) )
}

