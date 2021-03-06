#' SLURM scheduler functions
#'
#' Derives from QSys to provide SLURM-specific functions
SLURM = R6::R6Class("SLURM",
    inherit = QSys,

    public = list(
        initialize = function(...) {
            super$initialize(...)
        },

        submit_jobs = function(n_jobs, template=list(), log_worker=FALSE) {
            template = utils::modifyList(SLURM$defaults, template)
            template$n_jobs = n_jobs
            template$master = private$master
            private$job_id = template$job_name = paste0("cmq", self$id)
            if (log_worker)
                template$log_file = paste0(template$job_name, ".log")

            filled = infuser::infuse(SLURM$template, template)

            success = system("sbatch", input=filled, ignore.stdout=TRUE)
            if (success != 0) {
                print(filled)
                stop("Job submission failed with error code ", success)
            }
            private$workers_total = n_jobs
        },

        cleanup = function() {
            success = super$cleanup()
            self$finalize(success)
        },

        finalize = function(clean=FALSE) {
            if (!private$is_cleaned_up) {
                system(paste("scancel --jobname", private$job_id),
                       ignore.stdout=clean, ignore.stderr=clean)
                private$is_cleaned_up = TRUE
            }
        }
    ),

    private = list(
        is_cleaned_up = FALSE,
        job_id = NULL
    )
)

# Static method, process scheduler options and return updated object
SLURM$setup = function() {
    user_template = getOption("clustermq.template.slurm")
    if (!is.null(user_template)) {
        warning("scheduler-specific templates are deprecated; use clustermq.template instead")
        SLURM$template = readChar(user_template, file.info(user_template)$size)
    }
    user_template = getOption("clustermq.template")
    if (!is.null(user_template))
        SLURM$template = readChar(user_template, file.info(user_template)$size)

    user_defaults = getOption("clustermq.defaults")
    if (!is.null(user_defaults))
        SLURM$defaults = user_defaults
    else
        SLURM$defaults = list()

    SLURM
}

# Static method, overwritten in qsys w/ user option
SLURM$template = paste(sep="\n",
    "#!/bin/sh",
    "#SBATCH --job-name={{ job_name }}",
    "#SBATCH --output={{ log_file | /dev/null }}",
    "#SBATCH --error={{ log_file | /dev/null }}",
    "#SBATCH --mem-per-cpu={{ memory | 4096 }}",
    "#SBATCH --array=1-{{ n_jobs }}",
    "",
    "ulimit -v $(( 1024 * {{ memory | 4096 }} ))",
    "R --no-save --no-restore -e 'clustermq:::worker(\"{{ master }}\")'")
