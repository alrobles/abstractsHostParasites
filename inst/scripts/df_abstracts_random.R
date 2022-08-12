if(require(abstractsHostParasites)){
  devtools::install_github("alrobles/abstractsHostParasites")
}

if(require(tidyverse)){
  install.packages("tidyverse")
}

if(require(textcat)){
  install.packages("textcat")
}

# Replicate 50 times the rand_abstract_table to create a table with random
# abstracts with 5000 rows

List_random_abstracts <- 50 %>%
  purrr::rerun(abstractsHostParasites::rand_abstract_table("alroble8@asu.edu"))


df_abstracts_random <- List_random_abstracts %>% purrr::reduce(dplyr::bind_rows)

df_abstracts_random <- df_abstracts_random %>%
  dplyr::mutate(abstract = abstractsHostParasites::prep_fun(abstract) ) %>%
  dplyr::mutate(abstract = stringr::str_trim(abstract)) %>%
  dplyr::select(doi, title, abstract)
df_abstracts_random <- df_abstracts_random %>% dplyr::mutate(class = "unknown")
df_abstracts_random <- df_abstracts_random %>%
  mutate(abstract = prep_fun(abstract)) %>%
  mutate(language = textcat(abstract)) %>%
  filter(language == "english")

#readr::write_csv(df_abstracts_random, "data-raw/df_abstracts_random.csv")

