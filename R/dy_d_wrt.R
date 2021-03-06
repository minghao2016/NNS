#' Partial Derivative dy/d_[wrt]
#'
#' Returns the numerical partial derivative of \code{y} with respect to [wrt] any regressor for a point of interest.  Finite difference method is used with \link{NNS.reg} estimates as \code{f(x + h)} and \code{f(x - h)} values.
#'
#' @param x a numeric matrix or data frame.
#' @param y a numeric vector with compatible dimensions to \code{x}.
#' @param wrt integer; Selects the regressor to differentiate with respect to (vectorized).
#' @param eval.points numeric or options: ("obs", "apd", "mean", "median", "last"); Regressor points to be evaluated.
#' \itemize{
#' \item Numeric values must be in matrix or data.frame form to be evaluated for each regressor, otherwise, a vector of points will evaluate only at the \code{wrt} regressor.  See examples for use cases.
#' \item Set to \code{(eval.points = "obs")} (defalut) to find the average partial derivative at every observation of the variable with respect to \emph{for specific tuples of given observations.}
#' \item Set to \code{(eval.points = "apd")} to find the average partial derivative at every observation of the variable with respect to \emph{over the entire distribution of other regressors.}
#' \item Set to \code{(eval.points = "mean")} to find the partial derivative at the mean of value of every variable.
#' \item Set to \code{(eval.points = "median")} to find the partial derivative at the median value of every variable.
#' \item Set to \code{(eval.points = "last")} to find the partial derivative at the last observation of every value (relevant for time-series data).
#' }
#' @param mixed logical; \code{FALSE} (default) If mixed derivative is to be evaluated, set \code{(mixed = TRUE)}.
#' @param ncores integer; value specifying the number of cores to be used in the parallelized procedure. If NULL (default), the number of cores to be used is equal to the number of cores of the machine - 1.
#' @param messages logical; \code{TRUE} (default) Prints status messages.
#' @return Returns column-wise matrix of wrt regressors:
#' \itemize{
#' \item{\code{dy.d_(...)[, wrt]$First}} the 1st derivative
#' \item{\code{dy.d_(...)[, wrt]$Second}} the 2nd derivative
#' \item{\code{dy.d_(...)[, wrt]$Mixed}} the mixed derivative (for two independent variables only).
#' }
#'
#' @author Fred Viole, OVVO Financial Systems
#'
#' @references Viole, F. and Nawrocki, D. (2013) "Nonlinear Nonparametric Statistics: Using Partial Moments"
#' \url{https://www.amazon.com/dp/1490523995}
#'
#' Vinod, H. and Viole, F. (2020) "Comparing Old and New Partial Derivative Estimates from Nonlinear Nonparametric Regressions"
#' \url{https://ssrn.com/abstract=3681104}
#'
#' @examples
#' \dontrun{
#' set.seed(123) ; x_1 <- runif(100) ; x_2 <- runif(100) ; y <- x_1 ^ 2 * x_2 ^ 2
#' B <- cbind(x_1, x_2)
#'
#' #' ## To find derivatives of y wrt 1st regressor for specific points of both regressors
#' dy.d_(B, y, wrt = c(1, 2), eval.points = t(c(.5, .5)))
#'
#' ## To find average partial derivative of y wrt 1st regressor,
#' only supply 1 value in [eval.points], or a vector of [eval.points]:
#' dy.d_(B, y, wrt = 1, eval.points = .5)
#'
#' dy.d_(B, y, wrt = 1, eval.points = fivenum(B[,1]))
#'
#'
#' ## To find average partial derivative of y wrt 1st regressor,
#' for every oberservation of 1st regressor:
#' apd <- dy.d_(B, y, wrt = 1, eval.points = "apd")
#' plot(B[,1], apd[,1]$First)
#'
#' ## 95% Confidence Interval to test if 0 is within
#' ### Lower CI
#' LPM.VaR(.025, 0, apd[,1]$First)
#'
#' ### Upper CI
#' UPM.VaR(.025, 0, apd[,1]$First)
#' }
#' @export


dy.d_<- function(x, y, wrt,
                 eval.points = "obs",
                 mixed = FALSE,
                 ncores = NULL,
                 messages = TRUE){




  n <- dim(x)[1]
  nn <- min(n, 100)
  l <- dim(x)[2]


  if(is.null(l)) stop("Please ensure (x) is a matrix or data.frame type object.")
  if(l < 2) stop("Please use dy.dx(...) for univariate partial derivatives.")

  if(is.null(colnames(x))){
    colnames.list <- list()
    for(i in 1 : l){
      colnames.list[i] <- paste0("X", i)
    }
    colnames(x) <- as.character(colnames.list)
  }


  if(NNS.dep.hd(cbind(x, y))$Dependence > 0.25) h <- 0.2 else h <- max(0.1, 1/exp(l-2))

  order <- NULL

  if(l != 2) mixed <- FALSE

  if(is.character(eval.points)){
    eval.points <- tolower(eval.points)
    if(eval.points == "median"){
      eval.points <- t(apply(x, 2, median))
    } else {
      if(eval.points == "last"){
        eval.points <- tail(x, 1)
      } else {
        if(eval.points == "mean"){
          eval.points <- t(apply(x, 2, mean))
        } else {
          if(eval.points == "apd"){
            eval.points <- as.vector(x[ , wrt, drop = FALSE])
          } else {
            eval.points <- x
          }
        }
      }
    }
  }


  original.eval.points.min <- eval.points
  original.eval.points.max <- eval.points
  original.eval.points <- eval.points

  if(messages){
    message("Currently generating NNS.reg finite difference estimates...","\r",appendLF=TRUE)
  }

  if(is.vector(eval.points) || dim(eval.points)[2] == 1){
    eval.points <- unlist(eval.points)

    h_step <- LPM.ratio(1, eval.points, x[, wrt])
    h_step <- LPM.VaR(h_step + h, 1, x[, wrt]) - LPM.VaR(h_step - h, 1, x[, wrt])

    original.eval.points.min <- original.eval.points.min - h_step
    original.eval.points.max <- h_step + original.eval.points.max

    deriv.points <- apply(x, 2, function(z) LPM.VaR(seq(0,1,.05), 0, z))

    if(dim(deriv.points)[2]!=dim(x)[2]){
      deriv.points <- matrix(deriv.points, ncol = l, byrow = FALSE)
    }


    sampsize <- length(seq(0,1,.05))

    deriv.points <- data.table::data.table(do.call(rbind, replicate(3*length(eval.points), deriv.points, simplify = FALSE)))

    data.table::set(deriv.points, i=NULL, j = as.integer(wrt), value = rep(unlist(rbind(original.eval.points.min,
                                                                            eval.points,
                                                                            original.eval.points.max))
                                                               , each = sampsize, length.out = dim(deriv.points)[1] ))


    colnames(deriv.points) <- colnames(x)

    distance_wrt <- 2 * h_step

    position <- rep(rep(c("l", "m", "u"), each = sampsize), length.out = dim(deriv.points)[1])
    id <- rep(1:length(eval.points), each = 3*sampsize, length.out = dim(deriv.points)[1])


    if(messages){
      message(paste("Currently evaluating the ", dim(deriv.points)[1], " required points"  ),"\r",appendLF=TRUE)
    }

    estimates <- NNS.reg(x, y, point.est = deriv.points, dim.red.method = "equal", plot = FALSE, threshold = 0, order = order)$Point.est

    estimates <- data.table::data.table(cbind(estimates = estimates,
                                              position = position,
                                              id = id))

    lower_msd <- estimates[position=="l", sapply(.SD, function(x) list(mean=mean(as.numeric(x)), sd=sd(as.numeric(x)))), .SDcols = "estimates", by = id]
    lower <- lower_msd$V1
    lower_sd <- lower_msd$V2

    fx_msd <- estimates[position=="m", sapply(.SD, function(x) list(mean=mean(as.numeric(x)), sd=sd(as.numeric(x)))), .SDcols = "estimates", by = id]
    two.f.x <- 2* fx_msd$V1
    two.f.x_sd <- fx_msd$V2

    upper_msd <- estimates[position=="u", sapply(.SD, function(x) list(mean=mean(as.numeric(x)), sd=sd(as.numeric(x)))), .SDcols = "estimates", by = id]
    upper <- upper_msd$V1
    upper_msd <- upper_msd$V2

    rise <- upper - lower

  } else {
    n <- dim(eval.points)[1]
    original.eval.points <- eval.points

    h_step <- LPM.ratio(1, unlist(eval.points[, wrt]), x[, wrt])
    h_step <- mean(LPM.VaR(h_step + h, 1, x[, wrt]) - LPM.VaR(h_step - h, 1, x[, wrt]))

    original.eval.points.min[ , wrt] <- original.eval.points.min[ , wrt] - h_step
    original.eval.points.max[ , wrt] <- h_step + original.eval.points.max[ , wrt]

    deriv.points <- rbind(original.eval.points.min,
                          original.eval.points,
                          original.eval.points.max)

    estimates <- NNS.reg(x, y, point.est = deriv.points, dim.red.method = "equal", plot = FALSE, threshold = 0, order = order)$Point.est


    lower <- head(estimates,n)
    two.f.x <- 2 * estimates[(n+1):(2*n)]
    upper <- tail(estimates,n)

    rise <- upper - lower

    distance_wrt <- 2 * h_step
  }


  if(mixed){
    if(is.null(dim(eval.points))){
      if(length(eval.points)!=2){
        stop("Mixed Derivatives are only for 2 IV")
      }
    } else {
      if(ncol(eval.points) != 2){
        stop("Mixed Derivatives are only for 2 IV")
      }
    }

    if(!is.null(dim(eval.points))){
      h_step_1 <- LPM.ratio(1, eval.points, x[, 1])
      h_step_1 <- LPM.VaR(h_step_1 + h, 1, x[, 1]) - LPM.VaR(h_step_1 - h, 1, x[, 1])

      h_step_2 <- LPM.ratio(1, eval.points, x[, 2])
      h_step_2 <- LPM.VaR(h_step_2 + h, 1, x[, 2]) - LPM.VaR(h_step_2 - h, 1, x[, 2])

      mixed.deriv.points <- matrix(c(h_step_1 + eval.points[,1], h_step_2 + eval.points[,2],
                                     eval.points[,1] - h_step_1, h_step_2 + eval.points[,2],
                                     h_step_1 + eval.points[,1], eval.points[,2] - h_step_2,
                                     eval.points[,1] - h_step_1, eval.points[,2] - h_step_2), ncol = 2, byrow = TRUE)

      mixed.distances <- 4 * h_step_1 * h_step_2

    } else {
      mixed.deriv.points <- matrix(c(h_step + eval.points,
                                     eval.points[1] - h_step, h_step + eval.points[2],
                                     h_step + eval.points[1], eval.points[2] - h_step,
                                     eval.points - h_step), ncol = 2, byrow = TRUE)

      mixed.distances <- (2 * h_step) * (2 * h_step)
    }


    mixed.estimates <- NNS.reg(x, y, point.est = deriv.points, dim.red.method = "equal", plot = FALSE, threshold = 0, order = order)$Point.est


    if(messages){
      message("Done :-)","\r",appendLF=TRUE)
    }

    z <- matrix(mixed.estimates, ncol=4, byrow=TRUE)
    z <- z[,1] + z[,4] - z[,2] - z[,3]
    mixed <- (z / mixed.distances)

    results <- list("First" = as.numeric(unlist(rise / distance_wrt)),
                    "Second" = as.numeric(unlist((upper - two.f.x + lower) / ((distance_wrt) ^ 2))),
                    "Mixed" = mixed)

    return(results)
  } else {

    results <- list("First" = as.numeric(unlist(rise / distance_wrt)),
                    "Second" = as.numeric(unlist((upper - two.f.x + lower) / ((distance_wrt) ^ 2) )))

    return(results)
  }


}

dy.d_ <- Vectorize(dy.d_, vectorize.args = "wrt")
