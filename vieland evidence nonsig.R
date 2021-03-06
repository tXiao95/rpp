# Written by CHJ Hartgerink van MALM van Assen
if(!require(httr)){install.packages('httr')}
library(httr)

# Description of results included here 
# Of relevance to Gilbert et al's commentary on the Reproducibility Project:
# Psychology (OSC2015) is whether the nonsignificant results in OSC2015  may
# have arisen from true  nonzero effects. We re-analyzed the 64 statistically
# nonsignificant results to estimate their strength of evidence for non-zero
# effects. After excluding one result for which no test statistic was reported,
# Fisher’s test indicated that the hypothesis of 63 zero effects can be rejected
# (χ2(126) = 155.24, p = .039). To get an indication of how strong these
# non-zero effects may be, we hypothesized that X out of 63 results are
# generated by a true non-zero correlation of ρ, and 63-X are generated by true
# zero effects. Using the inversion method for calculating confidence intervals
# based on the observed value of the Fisher test statistic, we determined the
# 95% confidence interval of X for ρ = .1 (weak), .3 (medium), .5 (strong
# effect). Our analyses revealed that 0-63 nonsignificant results may be
# generated by a true small effect (0-100%), 0-21 by a true medium effect
# (0-33.3%), or 0-13 by a true large effect (0-20.6%). These results can be
# reproduced by executing this code.  These results demonstrate that we cannot
# draw strong conclusions about the true effect sizes underlying individual
# nonsignificant OSC2015 results.  The effects may all be essentially zero, but
# some could range from small to medium or even large. Therefore, we agree that
# the OSC2015 findings could underestimate the proportion of “true” effects,
# with the caveat that regardless of statistical significance, many published
# effect sizes are likely to be smaller than initially assumed.


# Read in data
info <- GET('https://osf.io/fgjvw/?action=download', write_disk('rpp_data.csv', overwrite = TRUE)) #downloads data file from the OSF
MASTER <- read.csv("rpp_data.csv")[1:167, ]
colnames(MASTER)[1] <- "ID" # Change first column name to ID to be able to load .csv file

# source function needed
info <- GET('https://osf.io/b2vn7/?action=download', write_disk('functions.r', overwrite = TRUE)) 
source('functions.r')

# number of iterations per condition
# if true probability is .025 or .975, then the SE = .00494 for n.iter = 1,000
n.iter <- 10000
# alpha of the individual test
alpha <- .05
# vector of ES
es <- c(.1, .3, .5)

# set seed
set.seed(alpha * n.iter * sum(es))

# select only the available and nonsignificant replications
# call this M
M <- MASTER[MASTER$T_sign_R == 0 
            & !is.na(MASTER$T_sign_R) 
            & (MASTER$T_Test.Statistic..R. == 't'
               | MASTER$T_Test.Statistic..R. == 'F'
               | MASTER$T_Test.Statistic..R. == 'r'
               | MASTER$T_Test.Statistic..R. == 'z'
               | MASTER$T_Test.Statistic..R. == 'Chi2'), ]

Fish_M <- FisherMethod(x = M$T_pval_USE..R.,
                       id = 1,
                       alpha = .05)

# selectors for easy selection later on  
selr <- M$T_Test.Statistic..R. == 'r'
selz <- M$T_Test.Statistic..R. == 'z'
selChi2 <- M$T_Test.Statistic..R. == 'Chi2'

# ensure that we can easily compute the effect size r
M$T_df1..R.[selr] <- 1
M$T_df2..R.[selr] <- M$T_N..R.[selr] - 2  
# ensure z is tranformed to fisher z
M$sigma[selz] <- sqrt(1 / (M$T_N..R.[selz] - 3))

# object to write count to
res <- list(NULL)
res[[1]] <- rep(0, dim(M)[1] + 1)
res[[2]] <- rep(0, dim(M)[1] + 1)
res[[3]] <- rep(0, dim(M)[1] + 1)

# compute critical value for F and t values
# we assume two-tailed tests everywhere
fCV <- qf(p = alpha, df1 = M$T_df1..R., df2 = M$T_df2..R., lower.tail = FALSE)
# compute critical value for z values
zCV <- qnorm(p = .025, mean = 0, sd = M$sigma[selz], lower.tail = FALSE)  
# compute critical value for chi2 values
Chi2CV <- qchisq(p = .05, df = M$T_df1..R.[selChi2], lower.tail = FALSE)

for(es_loop in 1:length(es)){
  
  # L will be the number of nonsignificant studies sampled from studies from M, 
  # which have true effect es > 0
  for (L in 0:dim(M)[1]){
    
    # randomly generate a p-value given the effect sizes
    # the null effects will yield uniform p-values      
    for (i in 1:n.iter){

      ran_L <- sample(dim(M)[1], size = L, replace = FALSE)
      
      # set population effect for the randomly sampled to es.
      pop_effect <- rep(0, dim(M)[1])
      if (!L == 0) pop_effect[ran_L] <- es[es_loop]
      
      # compute the noncentrality parameter
      # for the null effects this will be 0
      f2 <- pop_effect^2 / (1 - pop_effect^2)
      ncp <- f2 * ifelse(M$T_Test.Statistic..R. == "F",
                         M$T_df1..R. + M$T_df2..R. + 1,
                         ifelse(selr,
                                M$T_df1..R. + M$T_df2..R. + 1,
                                ifelse(selChi2,
                                       M$T_N..R.,
                                       M$T_df1..R. + M$T_df2..R.)))
      
      # determine area under H1 that corresponds to nonsignificant findings (= beta = Type II error)      
      beta <- pf(q = fCV, df1 = M$T_df1..R., df2 = M$T_df2..R., ncp = ncp, lower.tail = TRUE)
      beta[selz] <- pnorm(zCV, atanh(pop_effect[selz]), M$sigma[selz], lower.tail = TRUE) - pnorm(-zCV, atanh(pop_effect[selz]), M$sigma[selz], lower.tail = TRUE) 
      beta[selChi2] <- pchisq(Chi2CV, df = M$T_df1..R.[selChi2], ncp = ncp[selChi2], lower.tail = TRUE)
      
      # compute p-value alternative dist; sample from beta
      pA <- runif(length(beta), min = 0, max = beta)
      
      # test statistics simulated under alternative, based on beta
      fA <- qf(p = pA, df1 = M$T_df1..R., df2 = M$T_df2..R., ncp = ncp, lower.tail = TRUE)
      fA[selz] <- qnorm(pA[selz] + pnorm(-zCV, atanh(pop_effect[selz]), M$sigma[selz], lower.tail = TRUE),
                        atanh(pop_effect[selz]), M$sigma[selz], lower.tail = TRUE)
      fA[selChi2] <- qchisq(pA[selChi2], df = M$T_df1..R.[selChi2], ncp = ncp[selChi2], lower.tail = TRUE)  
      
      # pValues under null
      # convert test statistics under alternative to p-values under h0
      p0 <- pf(q = fA, df1 = M$T_df1..R., df2 = M$T_df2..R., lower.tail = FALSE)
      p0[selz] <- 1 - 2 * abs(pnorm(fA[selz], 0, M$sigma[selz], lower.tail = FALSE) - .5)
      p0[selChi2] <- pchisq(fA[selChi2], M$T_df1..R.[selChi2], lower.tail = FALSE)
      
      # Result of Fisher test for this run with L true effects > 0
      simulated <- FisherMethod(p0, 1, .05)
      
      res[[es_loop]][L + 1] <- res[[es_loop]][L + 1] + ifelse(simulated$Fish > Fish_M$Fish, 1, 0)
    }
  }
}

# pop_effect = .1
# sampled from L = 0:63
# 10000 iterations
# > res[[1]] / n.iter
# [1] 0.0386 0.0428 0.0519 0.0551 0.0576 0.0638 0.0752 0.0818 0.0902 0.0921 0.1018 0.1142
# [13] 0.1287 0.1312 0.1468 0.1595 0.1669 0.1812 0.1828 0.2010 0.2186 0.2352 0.2470 0.2629
# [25] 0.2733 0.2935 0.3037 0.3222 0.3439 0.3596 0.3723 0.3950 0.4047 0.4197 0.4432 0.4584
# [37] 0.4826 0.5048 0.5080 0.5365 0.5536 0.5576 0.5955 0.6062 0.6181 0.6363 0.6505 0.6713
# [49] 0.6738 0.6996 0.7166 0.7239 0.7394 0.7540 0.7760 0.7736 0.7920 0.8046 0.8165 0.8329
# [61] 0.8328 0.8523 0.8621 0.8719

# pop_effect = .3
# sampled from L = 0:63
# 10000 iterations
# > res[[2]] / n.iter
# [1] 0.0397 0.0590 0.0901 0.1294 0.1726 0.2231 0.2856 0.3542 0.4347 0.4947 0.5769 0.6511
# [13] 0.7153 0.7817 0.8280 0.8777 0.9038 0.9339 0.9532 0.9678 0.9790 0.9851 0.9903 0.9955
# [25] 0.9975 0.9982 0.9989 0.9995 0.9995 0.9996 0.9998 0.9999 1.0000 1.0000 1.0000 1.0000
# [37] 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000
# [49] 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000
# [61] 1.0000 1.0000 1.0000 1.0000

# pop_effect = .5
# sampled from L = 0:63
# 10000 iterations
# > res[[3]] / n.iter
# [1] 0.0386 0.0777 0.1265 0.2085 0.3026 0.4241 0.5481 0.6754 0.7932 0.8589 0.9169 0.9558
# [13] 0.9776 0.9888 0.9958 0.9985 0.9991 0.9995 0.9999 0.9999 1.0000 1.0000 1.0000 1.0000
# [25] 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000
# [37] 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000
# [49] 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000 1.0000
# [61] 1.0000 1.0000 1.0000 1.0000
