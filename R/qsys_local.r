#' Placeholder for local processing
#'
#' Mainly so tests pass without setting up a scheduler
LOCAL = R6::R6Class("LOCAL",
    inherit = QSys,

    public = list(
        initialize = function(..., data=NULL) {
            super$initialize(..., data=data)
        },

        set_common_data = function(...) {
        },

        submit_jobs = function(n_jobs=0, template=list(), log_worker=FALSE) {
        },

        cleanup = function() {
        }
    )
)
