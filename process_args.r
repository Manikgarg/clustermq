.ll = import('base/list')

#' @param fun             the function to call
#' @param ...             arguments to vectorise over
#' @param const           arguments not to vectorise over
#' @param export          objects to export to computing nodes
#' @param get             returns the result of the run (default:T)
#' @param memory          how many Mb of memory should be reserved to run the job
#' @param split_array_by  how to split matrices/arrays in \code{...} (default: last dimension)
#' @param expand_grid     do every combination of arguments to vectorise over
#' @param seed            random seed for the function to run
#' @param n.chunks        how much jobs to split functions calls into (default: number of calls)
#' @param chunk.size      how many function calls in one job (default: 1)
#' @param faiiteron.error   if jobs fail, return all successful or throw overall error?
#' @return                list of job results if get=T
process_args = function(fun, iter, const=list(), expand_grid=FALSE, split_array_by=NA) {
    # summarise arguments
    fun = match.fun(fun)
    funargs = formals(fun)
    required = names(funargs)[unlist(lapply(funargs, function(f) class(f)=='name'))]

    if (length(iter) == 1 && length(required) == 1)
        names(iter) = required

    provided = names(c(iter, const))

    # perform checks that BatchJobs doesn't do
    if ('reg' %in% provided || 'fun' %in% provided)
        stop("'reg' and 'fun' are reserved and thus not allowed as argument to ` fun`")
    if (any(grepl("^ ", provided)))
        stop("Arguments starting with space are not allowed")
    if (expand_grid && length(iter) == 1)
        stop("Can not expand_grid on one vector")

    sdiff = unlist(setdiff(required, provided))
    if (length(sdiff) > 1 && sdiff != '...')
        stop(paste("If more than one argument, all must be named:", paste(sdiff, collapse=" ")))

    sdiff = unlist(setdiff(provided, names(funargs)))
#    if (length(sdiff) > 1 && ! '...' %in% names(funargs))
#        stop(paste("Argument provided but not accepted by function:", paste(sdiff, collapse=" ")))
    dups = duplicated(provided)
    if (any(dups))
        stop(paste("Argument duplicated:", paste(provided[[dups]], collapse=" ")))

    # convert matrices to lists so they can be vectorised over
    split_mat = function(X) { #TODO: move this to array (with: -1=last dim)?
        if (is.array(X) && length(dim(X)) > 1) {
            if (is.na(split_array_by))
                setNames(plyr::alply(X, length(dim(X))), dimnames(X)[[length(dim(X))]])
            else
                setNames(plyr::alply(X, split_array_by), dimnames(X)[[split_array_by]])
        } else
            X
    }
    .ll$transpose(lapply(iter, split_mat))
}
