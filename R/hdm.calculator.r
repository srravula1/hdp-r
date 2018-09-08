#################################################
# Matrix calculations
#################################################

#' Calculate the normalized weights for each node and add them to the tree
#'
#' This function will take a defined model and corresponding set of
#' comboFrames and add normalized and weighted values to the tree
#'
#' @example
#' hdp$tree <- calculateHDMWeights(hdp$tree, comboFrameList)
#'
#' @param tree the tree representing the model to calculate
#' @param comboFrames a list of dataframes with comparative values corresponding
#' to the tree
#' @export
calculateHDMWeights <- function(tree, comboFrames) {

  tree$Do(function(node) {
    node$norm <-  normalizeValueForNode(node, comboFrames[[node$name]])
    node$weight <-  finalizeWeightsForNode(node)
  }, filterFun = isNotRoot)

  tree
}

#' Calculate weight for requested node
#'
#' Designed to be used recursively in the tree, this function will return
#' the normalized value for a node.
#'
#' @param currentNode the node to operate on
#' @param comboFrames the associated frames to use in the calculation
normalizeValueForNode <- function(currentNode, comboFrames) {
  #get parent
  parent <- currentNode$parent
  #build the comparison frames into a matrix
  matrixColumns <- lapply(1:length(parent$children), function(i){
    parent$children[[i]]$name
  })
  populatedMatrix <- matrix.buildFromComboFrames(matrixColumns,comboFrames)
  #now that we have the matrix of comparisons, run the calculations
  calculatedMatrix <- matrix.calculate(populatedMatrix)
  #return calculated values for this node
  return(calculatedMatrix[[currentNode$name,2]])
}

#' Calculate the weighted value for each node
#'
#' As the final step in the calculation return the finalized weight of each node.
#'
#' @param node the node to operate on
finalizeWeightsForNode <- function(node) {
  parent.norm <- node$parent$norm
  weight <- node$norm * parent.norm
  return(weight)
}

#' Given a set of names and dataframes with evaluation data,
#' build out the first matrix to operate on
#'
#' This is only used internally as the first step in the calculation
#'
#' @param names the names of the elements being compared in a pairwise manner
#' @param comboFrames the frames to transform into a matrix
matrix.buildFromComboFrames <- function(names,comboFrames) {
  A <- matrix(,
              nrow = length(names),
              ncol = length(names),
              dimnames = list(names,names))
  diag(A) <- 1
  for(df in comboFrames) {
    #print(paste0("--------colnames:",colnames(df)[1],"-",colnames(df)[2]))
    A[colnames(df)[1],colnames(df)[2]] <- df[[1,1]]
    A[colnames(df)[2],colnames(df)[1]] <- df[[1,2]]
  }
  A
}

#' Given a populated matrix, divide the comparisons against
#' each other to get relative weights
#'
#' This is only used internally as the second part of the calculation
#'
#' @param A the matrix to operate on
matrix.calculate <- function(A) {
  #calculate everything else
  B <- t(A) / A
  diag(B) <- 1
  B.norm <- sweep(B,2,colSums(B),`/`)
  nMeans <- rowMeans(B.norm)
  nSd <- apply(B.norm,1,sd)
  nVar <- apply(B.norm,1,var)
  inconsistency <- sqrt(sum(nVar) * .25)

  B.norm
  #divide col1 by col2, col2 by col3, etc to create Matrix C
  C <- matrix(ncol = ncol(B)-1, nrow = nrow(B))
  for(c in 1:ncol(C)) {
    C[,c] <- B[,c] / B[,c+1]
  }
  cMeans <- colMeans(C)

  #final calculation
  matrix.final <- matrix(ncol = 2, nrow = nrow(B), dimnames = list(rev(colnames(B)), list("Raw","Normalized")))
  #matrix.final[nrow(matrix.final),1] <- 1
  matrix.final[1,1] <- 1
  cMeans.reverse <- rev(cMeans)
  for(c in 2:nrow(matrix.final)) {
    matrix.final[c, 1] <- matrix.final[c-1,1] * cMeans.reverse[c-1]
  }

  matrix.final.raw.sum <- sum(matrix.final[,1])
  matrix.final[,2] <- matrix.final[,1] / matrix.final.raw.sum

  should.be.one <- sum(matrix.final[,2])

  matrix.final
}
