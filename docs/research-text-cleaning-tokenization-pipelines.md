# Research: Metadata Extraction, Text Cleaning, Tokenization Pipelines & Glossary Extraction

> **Repository:** `alrobles/abstractsHostParasites`
> **Date:** 2026-04-04
> **Package version:** 0.1.0

---

## Table of Contents

1. [Overview](#1-overview)
2. [Metadata Extraction from Papers and Web Sources](#2-metadata-extraction-from-papers-and-web-sources)
   - 2.1 [CrossRef API — `rand_abstract_table()` & `search_abstract_crossref()`](#21-crossref-api)
   - 2.2 [PubMed / Entrez API — `search_abstract_pubmed()`](#22-pubmed--entrez-api)
   - 2.3 [Unified Fallback — `search_abstract()`](#23-unified-fallback)
3. [Plain Text Extraction and Cleaning](#3-plain-text-extraction-and-cleaning)
   - 3.1 [HTML / JATS-XML Tag Stripping](#31-html--jats-xml-tag-stripping)
   - 3.2 [Text Normalisation — `prep_fun()`](#32-text-normalisation)
   - 3.3 [Language Filtering](#33-language-filtering)
4. [Tokenization Pipeline](#4-tokenization-pipeline)
   - 4.1 [Iterator Creation](#41-iterator-creation)
   - 4.2 [Vocabulary Construction & Stopword Removal](#42-vocabulary-construction--stopword-removal)
   - 4.3 [Vocabulary Pruning (Glossary Extraction)](#43-vocabulary-pruning-glossary-extraction)
   - 4.4 [Document-Term Matrix & TF-IDF Weighting](#44-document-term-matrix--tf-idf-weighting)
   - 4.5 [Inference-Time Tokenization — `get_class_score()`](#45-inference-time-tokenization)
5. [Data Sources and Datasets](#5-data-sources-and-datasets)
6. [End-to-End Pipeline Diagram](#6-end-to-end-pipeline-diagram)
7. [Key Dependencies](#7-key-dependencies)

---

## 1. Overview

The `abstractsHostParasites` R package is a **literature abstract classification system** built on a Positive-Unlabeled (PU) learning framework. Its pipeline can be divided into four major stages:

1. **Metadata extraction** — fetching DOI, title, abstract text, and publication date from CrossRef and PubMed APIs.
2. **Plain text cleaning** — stripping embedded HTML/XML tags, normalising whitespace, lowercasing.
3. **Tokenization** — converting cleaned abstracts into n-gram vocabularies, pruning, and building TF-IDF document-term matrices.
4. **Glossary / vocabulary extraction** — the pruned vocabulary produced during tokenization serves as the domain glossary for classification.

Each stage is described below with references to specific source files and line numbers.

---

## 2. Metadata Extraction from Papers and Web Sources

### 2.1 CrossRef API

Two functions fetch metadata via the CrossRef REST API (`https://api.crossref.org/works?`):

#### `rand_abstract_table()` — Random abstract sampling

**File:** [`R/rand_abstract_table.R`](../R/rand_abstract_table.R), lines 22–60

This function retrieves a table of random abstracts from CrossRef. Key implementation details:

- **API endpoint construction** (lines 24–26):
  ```r
  basUrl <- "https://api.crossref.org/works?sample="
  filterString <- "&filter=has-abstract:1&select=DOI,title,abstract,published"
  url <- paste0(basUrl, n, filterString)
  ```
  The `has-abstract:1` filter ensures only papers with abstracts are returned, and `select=DOI,title,abstract,published` restricts returned fields.

- **HTTP request** via `httr2` (lines 27–29): A polite pool email is set as the user agent.

- **JSON parsing** (line 30): `jsonlite::fromJSON(rawToChar(resp$body))` deserializes the response.

- **Date extraction** (lines 37–47): Publication dates are extracted from the nested `published$date-parts` field using `purrr::map()` / `purrr::map_df()`, then named `year`, `month`, `day`.

- **Abstract cleaning** (lines 48–53): HTML/XML tags are stripped (see [Section 3.1](#31-html--jats-xml-tag-stripping)).

- **Column rename** (line 55): `DOI` → `doi` for consistency.

#### `search_abstract_crossref()` — DOI-based abstract lookup

**File:** [`R/search_abstract_crossref.R`](../R/search_abstract_crossref.R), lines 24–85

Searches CrossRef by a specific DOI. The logic mirrors `rand_abstract_table()` with additional error handling:

- **Error handling** (lines 31–51): A `tryCatch` block around `httr2::req_perform()` returns an empty tibble with `NA` values on failure.

- **Response validation** (line 53): Checks `!all(is.na(resp))` before parsing.

- **Date parsing** (lines 59–67) and **abstract cleaning** (lines 69–73): Identical pattern to `rand_abstract_table()`.

### 2.2 PubMed / Entrez API

#### `search_abstract_pubmed()`

**File:** [`R/search_abstract_pubmed.R`](../R/search_abstract_pubmed.R), lines 23–111

Uses the `rentrez` package to search PubMed when CrossRef fails or lacks an abstract. Per-record metadata extraction:

| Metadata Field | Source Path in XML | Line |
|---|---|---|
| Article title | `PubmedArticle$MedlineCitation$Article$ArticleTitle` | 52 |
| Abstract text | `PubmedArticle$MedlineCitation$Article$Abstract$AbstractText` | 53 |
| PMID | `PubmedArticle$MedlineCitation$PMID$text` | 54 |
| DOI | `PubmedArticle$PubmedData$ArticleIdList` (filtered for `"doi"`) | 56–70 |
| Publication date | `ArticleDate$Year`, `$Month`, `$Day` | 71–73 |

**Structured abstract handling** (lines 76–86):
- Multi-part titles (`length > 2`) are collapsed: `paste0(search_title, collapse = " ")` (line 77).
- Multi-section abstracts are collapsed similarly (line 81).
- Named list abstracts (with `text` and `.attrs`) extract just the text (lines 84–86).

**Title similarity matching** (lines 91–108):
- Uses `stringdist::stringsim()` to compare the original search title against all returned titles.
- Both titles are normalised with an inline `prep_fun()` (lines 93–100) before comparison.
- The result with the highest similarity is selected, with ties broken by `dplyr::slice(df, 1)`.

### 2.3 Unified Fallback

#### `search_abstract()`

**File:** [`R/search_abstract.R`](../R/search_abstract.R), lines 23–46

Orchestrates the two API sources with automatic fallback:

1. First attempts CrossRef via `search_abstract_crossref()` (line 25).
2. If the returned abstract is `NA`, falls back to PubMed (lines 29–42).
3. Normalises the PubMed return schema: renames `search_abstract` → `abstract` and selects a canonical column set: `doi`, `title`, `abstract`, `year`, `month`, `day` (lines 40–41).

---

## 3. Plain Text Extraction and Cleaning

### 3.1 HTML / JATS-XML Tag Stripping

CrossRef abstracts are frequently returned with embedded JATS-XML tags, e.g.:
```xml
<jats:p>Background: This study...</jats:p>
```

Three sequential regex-based `stringr::str_remove_all()` calls strip these tags. This pattern appears identically in two files:

- **`R/rand_abstract_table.R`** lines 49–53
- **`R/search_abstract_crossref.R`** lines 69–73

| Step | Regex Pattern | Purpose |
|------|---------------|---------|
| 1 | `<([a-z]+) *[^/]*?>` | Remove opening HTML/XML tags (e.g., `<jats:p>`, `<p class="...">`) |
| 2 | `<*[^/]*?([a-z]+)>` | Remove closing and self-closing tags (e.g., `</jats:p>`, `</p>`) |
| 3 | `</` | Remove any remaining stray close-tag delimiters |

After tag removal:
- `stringr::str_trim(.data$abstract, "both")` — removes leading/trailing whitespace.
- `stringr::str_squish(.data$abstract)` — collapses all internal whitespace runs to single spaces.

### 3.2 Text Normalisation — `prep_fun()`

**File:** [`R/prep_fun.R`](../R/prep_fun.R), lines 15–24

This is the **core text preprocessing function** applied before tokenisation and also used independently for title comparison:

```r
prep_fun = function(x) {
  x = stringr::str_to_lower(x)                          # Step 1: lowercase
  x = stringr::str_replace_all(x, "[^[:alnum:]]", " ")  # Step 2: remove non-alphanumerics
  x = stringr::str_replace_all(x, "\\s+", " ")          # Step 3: collapse multiple spaces
  stringr::str_replace_all(x, "\\n+", " ")               # Step 4: collapse newline characters
}
```

| Step | Operation | Effect |
|------|-----------|--------|
| 1 | `str_to_lower()` | Case-normalises all text |
| 2 | Replace `[^[:alnum:]]` with `" "` | Strips all punctuation, hyphens, special characters — intentionally aggressive for maximum token coverage |
| 3 | Replace `\\s+` with `" "` | Collapses multiple whitespace characters |
| 4 | Replace `\\n+` with `" "` | Collapses newlines into spaces |

> **Note:** An identical copy of this function (without step 4) appears inline in [`R/search_abstract_pubmed.R`](../R/search_abstract_pubmed.R) lines 93–100, used for title-similarity scoring before selecting the best PubMed match.

### 3.3 Language Filtering

**Files:**
- [`inst/scripts/df_abstracts.R`](../inst/scripts/df_abstracts.R) lines 21–22
- [`inst/scripts/df_abstracts_random.R`](../inst/scripts/df_abstracts_random.R) lines 28–30

After `prep_fun()` normalisation, the `textcat` package performs language detection and only English abstracts are retained:

```r
mutate(language = textcat(abstract)) %>%
filter(language == "english")
```

This acts as a quality gate ensuring the classifier only trains on English-language text.

---

## 4. Tokenization Pipeline

The full tokenization pipeline lives in [`R/automodel_pu_abstracts.R`](../R/automodel_pu_abstracts.R) and uses the **`text2vec`** package throughout.

### 4.1 Iterator Creation

**File:** [`R/automodel_pu_abstracts.R`](../R/automodel_pu_abstracts.R), lines 46–53

```r
it_train = text2vec::itoken(db_abstracts_train$abstract,
                             preprocessor = prep_fun,
                             progressbar = FALSE)
```

`text2vec::itoken()` creates a lazy token iterator from raw abstract strings. The `preprocessor` argument is set to `prep_fun`, chaining cleaning and tokenisation in a single pipeline. Separate iterators are created for both train and test splits.

### 4.2 Vocabulary Construction & Stopword Removal

**File:** [`R/automodel_pu_abstracts.R`](../R/automodel_pu_abstracts.R), lines 54–59

```r
stop_words <- stopwords::stopwords()

v <- text2vec::create_vocabulary(it_train,
                                  ngram = c(1L, 5L),
                                  stopwords = stop_words)
v <- v %>% dplyr::filter(!grepl(pattern = "^[0-9]", .data$term))
```

Key aspects:
- **N-gram range:** Unigrams through **5-grams** (`ngram = c(1L, 5L)`) — capturing multi-word domain terms like `"host parasite interaction"`.
- **Stopword removal:** Uses the `stopwords` package's default English stopword list.
- **Numeric filtering** (line 59): Terms beginning with digits are removed with `grepl(pattern = "^[0-9]")`.

### 4.3 Vocabulary Pruning (Glossary Extraction)

**File:** [`R/automodel_pu_abstracts.R`](../R/automodel_pu_abstracts.R), lines 61–65

```r
pruned_vocab = text2vec::prune_vocabulary(v,
  term_count_min     = term_count,       # default = 2
  doc_proportion_max = doc_prop_max,     # default = 0.5
  doc_proportion_min = doc_prop_min      # default = 0.1
)
```

This is the closest analogue to **glossary extraction** in the codebase. The pruning filters:

| Parameter | Default | Effect |
|-----------|---------|--------|
| `term_count_min` | 2 | Removes terms appearing fewer than 2 times across all documents |
| `doc_proportion_max` | 0.5 | Removes terms appearing in more than 50% of documents (too common) |
| `doc_proportion_min` | 0.1 | Removes terms appearing in fewer than 10% of documents (too rare) |

The resulting `pruned_vocab` object functions as the **domain vocabulary / glossary** for the classifier. It is:
- Returned as part of the model output (line 83): `list(model = Prediction, vocabulary = pruned_vocab)`
- Reused at inference time in [`R/get_class_score.R`](../R/get_class_score.R) (line 29)

**Pre-computed vocabularies:**
- A GBIF-specific pruned vocabulary is stored at `data-raw/gbif_literature_pruned_vocab.rds`.
- Topic-level representative term lists (e.g., `"species, genus, first, genera, known"` for Topic 1) are stored in `data-raw/clean_gbif_topics.csv` and `data-raw/gbif_abstract_topic.csv`.

### 4.4 Document-Term Matrix & TF-IDF Weighting

**File:** [`R/automodel_pu_abstracts.R`](../R/automodel_pu_abstracts.R), lines 67–73

```r
vectorizer <- text2vec::vocab_vectorizer(pruned_vocab)
dtm_train  <- text2vec::create_dtm(it_train, vectorizer)
dtm_test   <- text2vec::create_dtm(it_test, vectorizer)

tfidf = text2vec::TfIdf$new()
dtm_df_tfidf_train_matrix <- text2vec::fit_transform(dtm_train, tfidf)
dtm_df_tfidf_test         <- text2vec::fit_transform(dtm_test, tfidf)
```

The pipeline:
1. **Vectorizer** — maps tokens to column indices based on the pruned vocabulary.
2. **DTM creation** — builds sparse document-term matrices for train and test sets.
3. **TF-IDF transformation** — applies Term Frequency–Inverse Document Frequency weighting, down-weighting terms that are common across documents and up-weighting distinctive terms.

The resulting matrices (`dtm_df_tfidf_train`) and matching label vectors (`label_obs`) are also bundled as package datasets:
- [`R/dtm_df_tfidf_train.R`](../R/dtm_df_tfidf_train.R) — sparse TF-IDF matrix documentation
- [`R/label_obs.R`](../R/label_obs.R) — observation label vector documentation

### 4.5 Inference-Time Tokenization — `get_class_score()`

**File:** [`R/get_class_score.R`](../R/get_class_score.R), lines 27–41

At inference time, a single abstract is processed through the same pipeline:

```r
get_class_score <- function(model, vocabulary, abstract){
  vectorizer <- vocab_vectorizer(vocabulary)
  classification_score <- if(nchar(abstract) > 10){
    trial_text <- abstract
    trial_text <- prep_fun(trial_text)                                    # Step 1: normalise
    it_test = text2vec::itoken(trial_text, progressbar = FALSE)           # Step 2: tokenise
    dtm_test = text2vec::create_dtm(it = it_test, vectorizer = vectorizer) # Step 3: DTM
    preds = predict(model, dtm_test, type = 'response')[,1]               # Step 4: predict
    return(preds)
  } else {
    return(0)
  }
}
```

- **Guard clause** (line 31): Abstracts shorter than 10 characters return a score of `0`.
- The function reuses the **same `prep_fun()`** and **same vocabulary** from training to ensure consistent tokenization.
- Returns a numeric score in `[0, 1]`, interpreted as the probability of belonging to the target class.

---

## 5. Data Sources and Datasets

| Dataset | Source | File | Size | Description |
|---------|--------|------|------|-------------|
| GMPD abstracts | Global Mammal Parasite Database | `data-raw/gmpd_doi_abstract_date.csv` | 1.8 MB | Parasite-related abstracts with DOI and dates |
| ZOVER abstracts | ZOVER database | `data-raw/zover_doi_abstract_date.csv` | 366 KB | Zoonotic virus abstracts |
| Combined parasite abstracts | GMPD + ZOVER | `data-raw/parasiteAbstracts.csv` | 2.1 MB | Merged, cleaned, English-only parasite abstracts |
| Random abstracts | CrossRef random sample | `data-raw/df_abstracts_random.csv` | 5.7 MB | Random abstracts labelled as `"unknown"` class |
| Combined training set | All above | `data-raw/df_abstracts.csv` | 9.3 MB | ~5,986 abstracts (English only, shuffled) |
| Training sample | Subset | `data-raw/df_abstracts_sample.csv` | 593 KB | 2,394 abstracts for quick testing |
| GBIF literature | GBIF API | `data-raw/gbif_literature_english.csv` | 9.2 MB | GBIF biodiversity literature corpus |
| GBIF topics (annotated) | LDA output | `data-raw/clean_gbif_topics.csv` | 9.4 MB | Per-document topic assignments with representative terms |
| GBIF topic glossary | LDA summary | `data-raw/gbif_abstract_topic.csv` | 11 KB | Per-topic-per-year representative term lists |
| GBIF pruned vocabulary | text2vec | `data-raw/gbif_literature_pruned_vocab.rds` | — | Pre-computed pruned vocabulary object |

**Dataset assembly scripts:**
- [`inst/scripts/df_abstracts.R`](../inst/scripts/df_abstracts.R) — Merges GMPD + ZOVER, cleans with `prep_fun()`, filters English, combines with random abstracts.
- [`inst/scripts/df_abstracts_random.R`](../inst/scripts/df_abstracts_random.R) — Generates random abstracts via 50 × `rand_abstract_table()` calls, cleans and filters English.

---

## 6. End-to-End Pipeline Diagram

```
┌──────────────────────────────────────────────────────────┐
│                   DATA ACQUISITION                       │
│                                                          │
│  CrossRef API                    PubMed / Entrez API     │
│  ├─ rand_abstract_table()        ├─ search_abstract_     │
│  │  (R/rand_abstract_table.R)    │  pubmed()             │
│  │                               │  (R/search_abstract_  │
│  └─ search_abstract_crossref()   │  pubmed.R)            │
│     (R/search_abstract_          │                       │
│      crossref.R)                 └─ XML::xmlToList()     │
│                                     rentrez::entrez_     │
│  httr2 + jsonlite                   fetch()              │
│                                                          │
│  Unified: search_abstract()                              │
│           (R/search_abstract.R)                          │
└────────────────────┬─────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────┐
│                 HTML TAG STRIPPING                        │
│                                                          │
│  str_remove_all("<([a-z]+) *[^/]*?>")   ← opening tags   │
│  str_remove_all("<*[^/]*?([a-z]+)>")    ← closing tags   │
│  str_remove_all("</")                   ← stray delims   │
│  str_trim(abstract, "both")             ← trim edges     │
│  str_squish(abstract)                   ← collapse spaces│
│                                                          │
│  (R/rand_abstract_table.R:49-53)                         │
│  (R/search_abstract_crossref.R:69-73)                    │
└────────────────────┬─────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────┐
│              TEXT NORMALISATION — prep_fun()              │
│              (R/prep_fun.R:15-24)                        │
│                                                          │
│  1. str_to_lower()                                       │
│  2. str_replace_all("[^[:alnum:]]", " ")                 │
│  3. str_replace_all("\\s+", " ")                         │
│  4. str_replace_all("\\n+", " ")                         │
└────────────────────┬─────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────┐
│              LANGUAGE FILTERING                           │
│              (inst/scripts/df_abstracts.R:21-22)         │
│                                                          │
│  textcat(abstract) → filter(language == "english")       │
└────────────────────┬─────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────┐
│              TOKENIZATION PIPELINE                        │
│              (R/automodel_pu_abstracts.R:46-73)          │
│                                                          │
│  text2vec::itoken(preprocessor = prep_fun)               │
│       │                                                  │
│       ▼                                                  │
│  create_vocabulary(ngram = c(1L, 5L), stopwords)         │
│       │                                                  │
│       ▼                                                  │
│  filter(!grepl("^[0-9]", term))                          │
│       │                                                  │
│       ▼                                                  │
│  prune_vocabulary(term_count_min, doc_proportion_*)      │
│       │              ← GLOSSARY / DOMAIN VOCABULARY      │
│       ▼                                                  │
│  vocab_vectorizer() → create_dtm()                       │
│       │                                                  │
│       ▼                                                  │
│  TfIdf$new() → fit_transform()                           │
│       │                                                  │
│       ▼                                                  │
│  Sparse TF-IDF Document-Term Matrix                      │
└────────────────────┬─────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────┐
│              PU LEARNING CLASSIFICATION                   │
│              (R/PLUS.R:24-96)                            │
│                                                          │
│  PLUS(train_data, Label.obs, ...)                        │
│       │                                                  │
│       ▼                                                  │
│  glmnet::cv.glmnet() → iterative label refinement       │
│       │                                                  │
│       ▼                                                  │
│  Classification score ∈ [0, 1]                           │
│  (R/get_class_score.R:27-41)                             │
└──────────────────────────────────────────────────────────┘
```

---

## 7. Key Dependencies

| Package | Role | Used In |
|---------|------|---------|
| `httr2` | HTTP requests to CrossRef API | `rand_abstract_table.R`, `search_abstract_crossref.R` |
| `jsonlite` | JSON parsing of API responses | `rand_abstract_table.R`, `search_abstract_crossref.R` |
| `rentrez` | PubMed/Entrez API access | `search_abstract_pubmed.R` |
| `XML` | XML-to-list conversion of PubMed records | `search_abstract_pubmed.R` |
| `stringr` | Regex-based text cleaning and normalisation | `prep_fun.R`, `rand_abstract_table.R`, `search_abstract_crossref.R`, `search_abstract_pubmed.R` |
| `stringdist` | Title similarity matching | `search_abstract_pubmed.R` |
| `textcat` | Language detection | `inst/scripts/df_abstracts.R`, `inst/scripts/df_abstracts_random.R` |
| `text2vec` | Tokenization, vocabulary, DTM, TF-IDF | `automodel_pu_abstracts.R`, `get_class_score.R` |
| `stopwords` | English stopword lists | `automodel_pu_abstracts.R` |
| `glmnet` | Penalised logistic regression (PLUS algorithm) | `PLUS.R` |
| `purrr` | Functional iteration over API results and dates | Multiple files |
| `dplyr` / `tibble` / `tidyr` | Data wrangling and tidying | Multiple files |
| `rsample` | Train/test splitting | `automodel_pu_abstracts.R` |

---

*This document was generated as part of the `@alrobles/ecoagent` documentation effort.*
