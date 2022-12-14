% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/PLUS.R
\name{PLUS}
\alias{PLUS}
\title{Title}
\usage{
PLUS(
  train_data = train_data,
  Label.obs = Label.obs,
  Sample_use_time = 30,
  l.rate = 1,
  qq = 0.1
)
}
\arguments{
\item{train_data}{train_data N*M matrix which has N samples and M variables.}

\item{Label.obs}{Positive Unlabeled for each sample, 1 means true positive label, 0 means unlabeled labels.}

\item{Sample_use_time}{used in stop criteria, how many times each samples to be used in training process.}

\item{l.rate}{control how much information from last iteration will be used in next.}

\item{qq}{quantile of the probability for positive samples, used to determine the cutoff between positive and negative.}
}
\value{
A list with fit.pi pred.y cutoff coef1 coef.glmnet. This are
the model, predicted y, predicted coefficient, and cutoff
}
\description{
Title
}
\examples{
\dontrun{
PLUS(train_data = dtm_df_tfidf_train,
    Label.obs = Label.obs,
    Sample_use_time = 30,
    l.rate = 1,
    qq = 0.1)
}
}
