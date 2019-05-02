#' NNS Boost
#'
#' Ensemble method using the predictions of the NNS base models \link{NNS.reg} for various uncorrelated feature combinations.
#'
#' @param IVs.train a matrix or data frame of variables of numeric or factor data types.
#' @param DV.train a numeric or factor vector with compatible dimsensions to \code{(IVs.train)}.
#' @param IVs.test a matrix or data frame of variables of numeric or factor data types with compatible dimsensions to \code{(IVs.train)}.
#' @param depth integer; \code{NULL} (default) Specifies the \code{order} parameter in the \code{NNS.reg} routine, assigning a number of splits in the regressors.
#' @param epochs integer; 500 (default) Total number of feature combinations to run.
#' @param folds integer; 5 (default) Number of times to resample the training data.  Splits the \code{epochs} over the dataset evenly over each \code{folds}.
#' @param CV.size numeric [0, 1]; \code{NULL} (default) Sets the cross-validation size if \code{(IVs.test = NULL)}.  Defaults to 0.25 for a 25 percent random sampling of the training set under \code{(CV.size = NULL)}.
#' @param threshold numeric [0, 1]; \code{NULL} (default) Sets the \code{obj.fn} threshold to keep feature combinations.
#' @param ncores integer; value specifying the number of cores to be used in the parallelized  procedure. If NULL (default), the number of cores to be used is
#' equal to the number of cores of the machine - 1.
#' @return Returns a vector of fitted values for the dependent variable test set.
#'
#' @keywords classifier
#' @author Fred Viole, OVVO Financial Systems
#' @references Viole, F. (2016) "Classification Using NNS Clustering Analysis"
#' \url{https://ssrn.com/abstract=2864711}
#' @note Currently only objective function is to maximize \code{mean(round(predicted)==as.numeric(actual))} since it is a classifier.  For a regression problem, simply use \code{NNS.reg}!
#' @examples
#'  ## Using 'iris' dataset where test set [IVs.test] is 'iris' rows 141:150.
#'  \dontrun{
#'  a = NNS.boost(iris[1:140, 1:4], iris[1:140, 5], IVs.test = iris[141:150, 1:4], epochs = 100)
#'
#'  ## Test accuracy
#'  mean(round(a)==as.numeric(iris[141:150,5]))
#'  }
#'
#' @export


NNS.boost <- function(IVs.train,
                      DV.train,
                      IVs.test,
                      depth = 2,
                      epochs=500,
                      folds=5,
                      CV.size=.2,
                      threshold=NULL,
                      ncores = NULL){


  obj.fn = expression(mean(round(predicted)==as.numeric(actual)))
  objective = "max"

  if (is.null(ncores)) {
    num_cores <- detectCores() - 1
  } else {
    num_cores <- ncores
  }

  cl <- makeCluster(num_cores)
  registerDoParallel(cl)

  mode = function(x){
    if(length(na.omit(x)) > 1){
      d <- density(na.omit(x))
      d$x[which.max(d$y)]
    } else {
      x
    }
  }


  x=data.frame(IVs.train); y=DV.train; z=data.frame(IVs.test)

  estimates=list()
  fold = list()

  # Test sample for threshold
  new.index = sample(length(x[,1]), as.integer(CV.size*length(x[,1])), replace = FALSE)

  actual = y[new.index]
  new.iv.test = x[new.index,]
  new.iv.train = x[-new.index,]
  new.dv.train = y[-new.index]


  # Add test loop for highest threshold
  if(is.null(threshold)){

    for(i in rep(seq(.99,.5,-.01),each=1)){
      features= sample(ncol(x),sample(2:ncol(x),1),replace = FALSE)

      #If estimate is > threshold, store 'features'
      predicted = NNS.reg(new.iv.train[,features],new.dv.train,point.est = new.iv.test[,features],plot=FALSE,residual.plot = FALSE,order=depth)$Point.est
      results = eval(obj.fn)

      if(results>=i){
        threshold = i
        break
      }
    }
  }


  fold <-  foreach(i = 1:folds,.packages = "NNS") %do% {
    keeper.features = list()

    new.index = sample(1:length(x[,1]),as.integer(CV.size*length(x[,1])),replace = FALSE)

    actual = y[new.index]
    new.iv.test = x[new.index,]
    new.iv.train = x[-new.index,]
    new.dv.train = y[-new.index]


    keeper.features <- foreach(j = 1:as.integer(epochs/folds),.packages = "NNS") %dopar% {

      actual = y[new.index]
      features= sample(ncol(x),sample(2:ncol(x),1),replace = FALSE)

      #If estimate is > threshold, store 'features'
      predicted = NNS.reg(new.iv.train[,features],new.dv.train,point.est = new.iv.test[,features],plot=FALSE,residual.plot = FALSE,order=depth)$Point.est
      results = eval(obj.fn)

      if(results>threshold){ features } else { NULL }
    }


    keeper.features[sapply(keeper.features, is.null)] <- NULL
    keeper.features = unique(keeper.features)
    fold[[i]]= keeper.features

  }

  if(length(fold)==0) stop("Please reduce [threshold]")

  final.features = do.call(c,fold)


  estimates <- foreach(i = 1:length(final.features),.packages = "NNS") %dopar% {
    estimates[[i]]= NNS.reg(x[,final.features[[i]]],y,point.est = z[,final.features[[i]]],plot=FALSE,residual.plot = FALSE,order=depth)$Point.est

  }

  stopCluster(cl)

  return(apply(do.call(cbind,estimates),1,mode))
}