#' R worker submitted as cluster job
#'
#' Do not call this manually, the master will do that
#'
#' @param master   The master address (tcp://ip:port)
#' @param timeout  Time until worker shuts down without hearing from master
#' @param ...      Catch-all to not break older template values (ignored)
#' @param verbose  Whether to print debug messages
worker = function(master, timeout=600, ..., verbose=TRUE) {
    if (!verbose)
        message = function(...) invisible(NULL)

    message("Master: ", master)
    if (length(list(...)) > 0)
        warning("Arguments ignored: ", paste(names(list(...)), collapse=", "))

    # connect to master
    zmq_context = rzmq::init.context()
    socket = rzmq::init.socket(zmq_context, "ZMQ_REQ")
    rzmq::set.send.timeout(socket, as.integer(timeout * 1000)) # msec

    # send the master a ready signal
    rzmq::connect.socket(socket, master)
    rzmq::send.socket(socket, data=list(id="WORKER_UP",
                      pkgver=utils::packageVersion("clustermq")))
	message("WORKER_UP to: ", master)

    fmt = "%i in %.2fs [user], %.2fs [system], %.2fs [elapsed]"
    start_time = proc.time()
    counter = 0
    common_data = NA
    token = NA

    while(TRUE) {
        events = rzmq::poll.socket(list(socket), list("read"), timeout=timeout)
        if (events[[1]]$read) {
            tic = proc.time()
            msg = rzmq::receive.socket(socket)
            delta = proc.time() - tic
            message(sprintf("> %s (%.3fs wait)", msg$id, delta[3]))
        } else
            stop("Timeout reached, terminating")

        switch(msg$id,
            "DO_SETUP" = {
                if (!is.null(msg$redirect)) {
                    data_socket = rzmq::init.socket(zmq_context, "ZMQ_REQ")
                    rzmq::connect.socket(data_socket, msg$redirect)
                    rzmq::send.socket(data_socket, data=list(id="WORKER_UP"))
                    message("WORKER_UP to redirect: ", msg$redirect)
                    msg = rzmq::receive.socket(data_socket)
                }
                need = c("id", "fun", "const", "export", "rettype", "common_seed", "token")
                if (setequal(names(msg), need)) {
                    common_data = msg[setdiff(need, c("id", "export", "token"))]
                    list2env(msg$export, envir=.GlobalEnv)
                    token = msg$token
                    message("token from msg: ", token)
                    rzmq::send.socket(socket, data=list(id="WORKER_READY",
                                      token=token))
                } else {
                    msg = paste("wrong field names for DO_SETUP:",
                                setdiff(names(msg), need))
                    rzmq::send.socket(socket, data=list(id="WORKER_ERROR", msg=msg))
                }
            },
            "DO_CHUNK" = {
                if (!identical(token, msg$token)) {
                    msg = paste("mismatch chunk & common data", token, msg$token)
                    rzmq::send.socket(socket, send.more=TRUE,
                        data=list(id="WORKER_ERROR", msg=msg))
                    message("WORKER_ERROR: ", msg)
                    break
                }

                tic = proc.time()
                result = tryCatch(
                    do.call(work_chunk, c(list(df=msg$chunk), common_data)),
                    error = function(e) e)
                delta = proc.time() - tic

                if ("error" %in% class(result)) {
                    rzmq::send.socket(socket, send.more=TRUE,
                        data=list(id="WORKER_ERROR", msg=conditionMessage(result)))
                    message("WORKER_ERROR: ", conditionMessage(result))
                    break
                } else {
                    message("completed ", sprintf(fmt, length(result$result),
                        delta[1], delta[2], delta[3]))
                    send_data = c(list(id="WORKER_READY", token=token), result)
                    rzmq::send.socket(socket, send_data)
                    counter = counter + length(result$result)
                }
            },
            "WORKER_WAIT" = {
                message(sprintf("waiting %.2fs", msg$wait))
                Sys.sleep(msg$wait)
                rzmq::send.socket(socket, data=list(id="WORKER_READY", token=token))
            },
            "WORKER_STOP" = {
                break
            }
        )
    }

    run_time = proc.time() - start_time

    message("shutting down worker")
    rzmq::send.socket(socket, data = list(
        id = "WORKER_DONE",
        time = run_time,
        mem = 200 + sum(gc()[,6]),
        calls = counter
    ))

    message("\nTotal: ", sprintf(fmt, counter, run_time[1], run_time[2], run_time[3]))
}
