if(require(tidyverse)){
  install.packages("tidyverse")
}
if(require(abstractsHostParasites)){
  devtools::install_github("alrobles/abstractsHostParasites")
}

if(require(textcat)){
  install.packages("textcat")
}


gmpd <- readr::read_csv("data-raw/gmpd_doi_abstract_date.csv") %>%
  select(doi, title, abstract)
zover <- readr::read_csv("data-raw/zover_doi_abstract_date.csv") %>%
  select(doi, title, abstract)

df_parasites <- bind_rows(gmpd , zover) %>%
  mutate(class = "parasite") %>%
  mutate(abstract = prep_fun(abstract)) %>%
  mutate(language = textcat(abstract)) %>%
  filter(language == "english")

df_abstracts_random <- readr::read_csv("data-raw/df_abstracts_random.csv")
df_abstracts <- bind_rows(df_parasites, df_abstracts_random ) %>%
  sample_frac(1) %>%
  na.exclude() %>%
  mutate(abstract = abstractsHostParasites::prep_fun(abstract)) %>%
  select(-language)


#write_csv(df_abstracts, "inst/scripts/df_abstracts.csv")

