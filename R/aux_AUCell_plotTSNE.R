# @import
#' @title Plot
#' @description  Plots the AUC histogram and t-SNE coloured by AUC, binary activity and TF expression
#' @importFrom graphics box legend plot
#' @importFrom grDevices adjustcolor dev.off png rainbow
#' @param tSNE t-SNE coordinates (e.g. \code{tSNE$Y})
#' @param exprMat Expression matrix
#' @param cellsAUC AUC (as returned by calcAUC)
#' @param thresholds Thresholds returned by AUCell
#' @param cex Scaling factor for the dots in the scatterplot
#' @param alphaOn Transparency for the dots representing "active" cells
#' @param alphaOff Transparency for the dots representing "inactive" cells
#' @param borderColor Border color for the dots (scatterplot)
#' @param offColor Color for the dots representing "inactive" cells
#' @param plots Which plots to generate? Select one or multiple: \code{plots=c("histogram", "binaryAUC", "AUC", "expression")}
#' @param exprCols Color scale for the expression
#' @param asPNG Output each individual plot in a .png file? (can also be a directory)
#' @param ... Other arguments to pass to \code{\link{hist}} function.
#' @return Returns invisible: \code{cells_trhAssignment}
#' @details To avoid calculating thresholds, set thresholds to FALSE
#' @seealso List of vignettes included in the package: \code{vignette(package="AUCell")}
#' @example inst/examples/example_AUCell_plotTSNE.R
#' @export
# thresholds=NULL; cex=1; alphaOn=1; alphaOff=0.2;  offColor="lightgray"
# borderColor=adjustcolor("darkgrey", alpha=.3); plots=c("histogram", "binaryAUC", "AUC", "expression")
AUCell_plotTSNE <- function(tSNE, exprMat, cellsAUC=NULL, thresholds=NULL, cex=1,
                         alphaOn=1, alphaOff=0.2,
                         borderColor=adjustcolor("lightgray", alpha.f=0.1),
                         offColor="lightgray",
                         plots=c("histogram", "binaryAUC", "AUC", "expression"),
                         exprCols= c("goldenrod1", "darkorange", "brown"),
                         asPNG=FALSE, ...)
{
  #library(BiocGenerics)
  #library(AUCell)
  ####################################
  # Check inputs (TO DO)
  if(is.null(rownames(tSNE))) stop("Please, provide the cell rownames in the t-SNE")
  if(!is.matrix(tSNE) | ncol(tSNE)!=2) stop("The t-SNE should be a matrix with 2 columns (cell coordinates)")
  if (any(grepl("binary", tolower(plots)))) {
    plots[grep("binary", tolower(plots))] <- "binaryAUC"
  }
    
  ####################################
  # Calculate thresholds if needed
  if(is.logical(thresholds) && thresholds == FALSE) thresholds <- NA
  if(!is.null(thresholds))
  {
    # if it is a list... probably return from AUCell. Let's try...
    if(is.list(thresholds[1])) {
      # Aucell
      if("aucThr" %in% names(thresholds[[1]])) thresholds <- sapply(thresholds, function(x) unname(x$aucThr$selected))
      # previous run of this function
      if("threshold" %in% names(thresholds[[1]]))  thresholds <- sapply(thresholds, function(x) unname(x$threshold))
    }

    if(!is.null(names(thresholds)))
    {
      geneSetNames <- rownames(cellsAUC)[which(rownames(cellsAUC) %in% names(thresholds))]
      cellsAUC <- cellsAUC[geneSetNames,]
    }
    if(is.null(names(thresholds)) || length(thresholds)==1)
    {
      thresholds <- setNames(rep(thresholds, nrow(cellsAUC)), rownames(cellsAUC))
    }
  }

  if(!is.null(cellsAUC)){
    selectedGeneSets <- rownames(cellsAUC)
  }else{
    selectedGeneSets <- rownames(exprMat)
    plots <- "expression"
    # warning("no AUC provided... only plotting expression")
  }

  cells_trhAssignment <- list()

  ####################################
  # Start plots
  dirName <- "./"
  if(is.character(asPNG))
  {
    if(!file.exists(asPNG)) dir.create(asPNG)
    dirName <- paste0(asPNG,"/")
    asPNG <- TRUE
  }
  if(asPNG){
    nCols <- length(plots)
    figsMatrix <- matrix(nrow=length(selectedGeneSets), ncol=nCols)
    rownames(figsMatrix) <- selectedGeneSets
    colnames(figsMatrix) <- plots
  }
  for (geneSetName in selectedGeneSets)
  {
    ##################
    # Histogram
    if(is.null(thresholds) && any(c("histogram", "binaryAUC") %in% plots))
    {
      if(asPNG) {
        imgFile <- paste0(geneSetName,"_histogram.png")
        figsMatrix[geneSetName, "histogram"] <- imgFile # paste("<img src=\"", imgFile, "\") height=\"100\" alt=\"",imgFile, "\"></img>", sep = "")
        png(paste0(dirName, imgFile))
      }

      set.seed(123)
      cells_trhAssignment[[geneSetName]] <- AUCell_exploreThresholds(cellsAUC[geneSetName,], assignCells=TRUE,
                                            plotHist=("histogram" %in% tolower(plots)))[[geneSetName]]
      thisTrheshold <- cells_trhAssignment[[geneSetName]]$aucThr$selected
      thisAssignment <- cells_trhAssignment[[geneSetName]]$assignment

      if(asPNG) dev.off()
    }

    if(!is.null(thresholds) && !is.na(thresholds))
    {
      if("histogram" %in% tolower(plots))
      {
        if(asPNG) {
          imgFile <- paste0(geneSetName,"_histogram.png")
          figsMatrix[geneSetName, "histogram"] <- imgFile # paste("<img src=\"", imgFile, "\") height=\"100\" alt=\"",imgFile, "\"></img>", sep = "")
          png(paste0(dirName, imgFile))
        }

        ### Plot
        #hist(, col="#00609060", border="#0060f0")
        thisTrh <- thresholds[geneSetName]
        tmp <- .auc_plotHist(auc=getAUC(cellsAUC)[geneSetName,], gSetName=geneSetName,
                             aucThr=min(thisTrh, 1), nBreaks=100, sub="AUC")

        if(!is.null(thisTrh))
        {
            abline(v=thisTrh, lwd=3, lty=2, col="darkorange")
        }else{
            warning("No threshold for gene set: ",geneSetName)
        }
        if(asPNG) dev.off()
      }
      thisTrheshold <- thresholds[geneSetName]
      if(is.matrix(cellsAUC)){
        AUCmatrix <- cellsAUC
      }else{
        matrixAUC <- getAUC(cellsAUC)
      }
      thisAssignment <- names(which(matrixAUC[geneSetName,] > thisTrheshold))
      cells_trhAssignment[[geneSetName]] <- list("threshold"=thisTrheshold, "assignment"=thisAssignment)
    }

    ######### t-SNE 1: binary #############
    # Cells assigned at current threshold
    if(any(grepl("binary", tolower(plots))))
    {
      if(asPNG) {
        imgFile <- paste0(geneSetName,"_binaryAUC.png")
        figsMatrix[geneSetName, "binaryAUC"] <- imgFile # paste("<img src=\"", imgFile, "\") height=\"100\" alt=\"",imgFile, "\"></img>", sep = "")
        png(paste0(dirName, imgFile))
      }
      ### Plot
      thrAsTxt <- ""
      if(is.numeric(thisTrheshold)) thrAsTxt <- paste("Cells with AUC > ", signif(thisTrheshold, 2), sep="")
      .auc_plotBinaryTsne(tSNE, selectedCells=thisAssignment,
                          title=geneSetName, txt=thrAsTxt,
                          cex=cex, alphaOn=alphaOn, alphaOff=alphaOff,
                          borderColor=borderColor, offColor=offColor, ...)
      if(asPNG) dev.off()
    }

    ######### t-SNE 2: Continuous #############
    # Regulon AUC
    if("auc" %in% tolower(plots))
    {
      if(asPNG) {
        imgFile <- paste0(geneSetName,"_AUC.png")
        figsMatrix[geneSetName, "AUC"] <- imgFile# paste("<img src=\"", imgFile, "\") height=\"100\" alt=\"",imgFile, "\"></img>", sep = "")
        png(paste0(dirName, imgFile))
      }
      ### Plot
      .auc_plotGradientTsne(tSNE, cellProp=getAUC(cellsAUC)[geneSetName,],
                            title=geneSetName, txt="Gene set activity (AUC)",
                            cex=cex, alphaOn=alphaOn, alphaOff=alphaOff,
                            borderColor=borderColor, offColor=offColor, ...)
      if(asPNG) dev.off()
    }

    ######### t-SNE 3: expression #############
    # TF expression
    if("expression" %in% tolower(plots))
    {
      gene <- gsub( "\\s\\(\\d+g)", "",geneSetName)
      gene <- gsub( "_extended", "", gene)
      if(gene %in% rownames(exprMat))
      {
        if(asPNG) {
          imgFile <- paste0(geneSetName,"_expression.png")
          figsMatrix[geneSetName, "expression"] <- imgFile# paste("<img src=\"", imgFile, "\") height=\"100\" alt=\"",imgFile, "\"></img>", sep = "")
          png(paste0(dirName, imgFile))
        }
        ### Plot
        .auc_plotGradientTsne(tSNE, cellProp=exprMat[gene,],
                              colorsForPal = exprCols,
                              title=paste(gene, "expression"), txt="",
                              cex=cex, alphaOn=alphaOn, alphaOff=alphaOff,
                              borderColor=borderColor, offColor=offColor, ...)
        if(asPNG) dev.off()
      }
    }
  }
  if(asPNG) {
    cells_trhAssignment <- c(cells_trhAssignment, figsMatrix=list(figsMatrix))
    if("R2HTML" %in% rownames(installed.packages())) asHTML(figsMatrix, dirName)
  }
  invisible(cells_trhAssignment)
}

asHTML <- function(figsMatrix, imgDir="./")
{
  figsMatrix <- t(apply(figsMatrix, 1, function(x) paste("<img src=\"", imgDir, x, "\") height=\"100\"></img>", sep = "")))

  #file.copy("test.css", ".")
  R2HTML::HTML(figsMatrix, file=R2HTML::HTMLInitFile("."))#, CSSFile="test.css")
  R2HTML::HTMLEndFile()
}
