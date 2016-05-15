library(glmnet)
library(foreach)
library(doMC)
registerDoMC(cores=6)

source("coordinate_descent.r")
source("soft_threshold.r")
source("pirls.")

# lmnet sanity check
x=matrix(rnorm(100*20),100,ncol=20)
y=rnorm(100)
fit1 = glmnet(x, y, standardize=FALSE, intercept=FALSE)
lambdas = fit1$lambda
fit2_betas = foreach(lambda=lambdas, .combine=cbind) %do% {
  pirls(x, y, lambda=lambda, family=gaussian)$beta
}
beta_diff = (fit1$beta - fit2_betas)^2
if (any(sqrt(colSums(beta_diff)) > 1e-3)) stop("Precision problem.")

cbind(fit1$beta, fit2$beta)

# Timing
glmnet_times = c()
glmnet_fit_times=c()
num_cols = round(seq(20, 1000, length.out=20))
for (j in num_cols) {
  x=matrix(rnorm(100*j), 100, ncol=j)
  y=rnorm(100)

  lambdas=glmnet(x, y, standardize=FALSE, intercept=FALSE)$lambda
  lambda = lambdas[round(length(lambdas)/2)]
  glmnet_times = c(glmnet_times, 
    system.time({
      a = glmnet(x, y, standardize=FALSE, lambda=lambda, intercept=FALSE)
    })[3])

  glmnet_fit_times = c(glmnet_fit_times,
    system.time({
      b = pirls(x, y, lambda=lambda, family=gaussian)
    })[3])

  print("a")
  print(sd(y - x %*% a$beta)) 
  print("b")
  print(sd(y - x %*% b$beta))
}

#binomial
x=matrix(rnorm(100*20),100,ncol=20)
g2=sample(1:2,100,replace=TRUE)
fit1 = glmnet(x,g2,family="binomial", standardize=FALSE, intercept=FALSE)
lambdas = fit1$lambda
lambda = lambdas[length(round(lambdas))/2]
fit2 = pirls(x, g2-1, family=binomial, lambda=lambda)
cbind(fit1$beta[,length(round(lambdas))/2], fit2$beta)


# Soft threshold testing
RcppParallel::setThreadOptions(numThreads = 4)
library(Matrix)
library(devtools)
document()
nrows = 10
ncols = 100
sp_mat = spMatrix(ncol=1, nrow=nrows)

X = matrix(rnorm(nrows*ncols), nrow=nrows, ncol=ncols)
W = as(diag(nrows), "dgCMatrix")
z = matrix(rnorm(nrows), ncol=1)
lambda = 0.3
alpha = 1
beta = as(matrix(0, nrow=ncols, ncol=1), "dgCMatrix")

system.time({
  cuc = c_update_coordinates(X, W, z, lambda, alpha, beta, parallel=FALSE,
                             grain_size=100)})
system.time({
  uc = update_coordinates(X, diag(W), z, lambda, alpha, beta)})

c_quadratic_loss(X, W, z, lambda, alpha, beta)
quadratic_loss(X, diag(W), z, lambda, alpha, beta)

c_safe_filter(X, z, lambda)
