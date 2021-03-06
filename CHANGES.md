* 0.8.4
  * Fix error for `qsys$reusable` when using `n_jobs=0`/local processing (#75)
  * Scheduler-specific templates are deprecated. Use `clustermq.template` instead
  * Allow option `clustermq.defaults` to fill default template values (#71)
  * Errors in worker processing are now shut down cleanly (#67)
  * Progress bar now shows estimated time remaining (#66)
  * Progress bar now also shown when processing locally
  * Memory summary now adds estimated memory of R session (#69)

* 0.8.3
  * Support `rettype` for function calls where return type is known (#59)
  * Reduce memory requirements by processing results when we receive them
  * Fix a bug where cleanup, `log_worker` flag were not working for SGE/SLURM

* 0.8.2
  * Fix a bug where never-started jobs are not cleaned up
  * Fix a bug where tests leave processes if port binding fails (#60)
  * Multicore no longer prints worker debug messages (#61)

* 0.8.1
  * Fix performance issues for a high number of function calls (#56)
  * Fix bug where multicore workers were not shut down properly (#58)
  * Fix default templates for SGE, LSF and SLURM (misplaced quote)

* 0.8.0
  * Templates changed: `clustermq:::worker` now takes only master as argument
  * Fix a bug where copies of `common_data` are collected by gc too slowly (#19)
  * Creating `workers` is now separated from `Q`, enabling worker reuse (#45)
  * Objects in the function environment must now be `export`ed explicitly (#47)
  * Messages on the master are now processed in threads (#42)
  * Added `multicore` qsys using the `parallel` package (#49)
  * New function `Q_rows` using data.frame rows as iterated arguments (#43)
  * Jobs will now be submitted as array if possible
  * Job summary will now report max memory as reported by `gc` (#18)

* 0.7.0
  * Initial release on CRAN
