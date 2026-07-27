#' Flag independent detection events in camera-trap data
#'
#' Camera traps fire repeatedly on the same animal or group, so raw records are
#' not statistically independent. The near-universal remedy is a fixed time
#' threshold: a record starts a new event only if it falls more than \code{k}
#' minutes after the previous one at the same station for the same species.
#'
#' A time threshold alone cannot distinguish an animal that lingers in front of
#' the camera from the arrival of new individuals. Species that loiter, such as
#' baboons or warthogs at a waterhole, are collapsed into a single event no
#' matter how long they stay or how the group changes, while the same threshold
#' applied to a transient species behaves quite differently. \code{independent_events()}
#' therefore lets the independence decision use record-level metadata (group
#' size, sex and age counts, behaviour, individual ID) in addition to time.
#'
#' @param data A data frame of camera-trap records, one row per detection.
#' @param datetime Name of the date-time column. Either \code{POSIXct}, or
#'   character parsed with \code{format}.
#' @param station Name of the column identifying the camera or station.
#'   Independence is assessed within station.
#' @param species Name of the species column. Independence is assessed within
#'   species. Pass \code{NULL} to pool all species.
#' @param threshold Time threshold in minutes. A gap strictly greater than
#'   \code{threshold} always starts a new event.
#' @param rule How metadata is used inside the time window:
#'   \describe{
#'     \item{\code{"time_only"}}{Metadata ignored. The conventional fixed-threshold
#'       filter, equivalent to \pkg{camtrapR}'s \code{minDeltaTime}.}
#'     \item{\code{"any_change"}}{A record starts a new event if ANY column in
#'       \code{metadata} differs from the preceding record. Works with numeric or
#'       categorical metadata. This is the rule used in Awini et al. (2026).
#'       Note that it is triggered by decreases as well as increases, so with
#'       noisy counts it can inflate event totals for gregarious species; see
#'       \code{vignette("choosing-a-rule")} and \code{independence_sensitivity()}.}
#'     \item{\code{"running_max"}}{A record starts a new event only if a numeric
#'       metadata column, or \code{count}, EXCEEDS the running maximum already
#'       observed within the current burst. Interprets only an increase above
#'       everything seen so far as evidence of previously uncounted individuals.
#'       Robust to frame-to-frame miscounting of a moving group. Requires numeric
#'       \code{metadata}.}
#'   }
#' @param metadata Character vector of column names carrying the metadata used
#'   by \code{rule}. Ignored when \code{rule = "time_only"}.
#' @param count Optional name of a total group-size column, used by
#'   \code{"running_max"} in addition to \code{metadata}, and used to compute
#'   \code{n_new}. If absent, group size falls back to the sum of numeric
#'   \code{metadata}.
#' @param min_increase How far a count must exceed the running maximum before it
#'   counts as evidence of a new individual, under \code{"running_max"}. The
#'   default of 1 accepts any increase. Raise it where tagging is noisy: a rise
#'   from 3 to 4 animals is exactly what a miscount looks like, whereas a rise
#'   from 3 to 7 is not. Ignored by the other rules.
#' @param compare_to Reference point for the time gap:
#'   \describe{
#'     \item{\code{"last_record"}}{Gap measured from the previous record, retained
#'       or not. A burst ends only after \code{threshold} elapses with no records
#'       at all. Default, and the behaviour of most published filters.}
#'     \item{\code{"last_independent"}}{Gap measured from the last retained event,
#'       subdividing long bursts at fixed intervals.}
#'   }
#'   Equivalent to \pkg{camtrapR}'s \code{deltaTimeComparedTo}.
#' @param format Format string used to parse \code{datetime} when it is character.
#' @param tz Time zone used for parsing. Defaults to \code{"UTC"}.
#' @param filter If \code{TRUE}, return only independent records. If \code{FALSE}
#'   (default), return all records with the flag columns added.
#'
#' @return \code{data} with four columns added:
#'   \describe{
#'     \item{\code{independent}}{logical, \code{TRUE} for an independent event}
#'     \item{\code{event_id}}{integer, consecutive event number within station and species}
#'     \item{\code{burst_id}}{integer, the time-defined burst the record belongs to}
#'     \item{\code{n_new}}{numeric, individuals seen at this event that were not
#'       already counted earlier in the same burst; \code{NA} when no group size
#'       is available}
#'   }
#'   Row order is preserved.
#'
#' @section Events versus individuals:
#' These are different units and the package reports both. A group of three
#' animals passing together is one encounter containing three individuals, not
#' three encounters; treating it as three is the pseudo-replication that
#' independence filtering exists to prevent. But three animals arriving
#' separately within the window are three encounters, and a time-only rule
#' wrongly merges them.
#'
#' Use \code{event_id} for anything that counts encounters, such as diel activity
#' patterns or occupancy. Use \code{n_new} for anything that counts animals, such
#' as an individual-based relative abundance index. Summing \code{n_new} over
#' independent records gives the number of distinct individuals, counting each
#' animal exactly once even where a rule has split a burst:
#'
#' \preformatted{
#' ev <- independent_events(recs, ..., filter = TRUE)
#' sum(ev$n_new)            # distinct individuals
#' nrow(ev)                 # encounters
#' }
#'
#' Taking the group size of each split event instead would double-count the
#' animals that were already present.
#'
#' @section Choosing a rule:
#' \code{"time_only"} is the safe default when metadata is unreliable or absent.
#' \code{"running_max"} is recommended when age and sex counts are available,
#' because it responds to evidence of new individuals but not to counting noise.
#' \code{"any_change"} is the most permissive and should be reported alongside
#' \code{independence_sensitivity()} output so readers can see how much of the
#' event total depends on it.
#'
#' Whichever is chosen, state the threshold, the rule and \code{compare_to}
#' explicitly in the methods: these three choices are not interchangeable and
#' materially change event totals, especially for gregarious species.
#'
#' @references
#' Awini, S., Cabeza, M., Goded, S., Mahama, A. & Annorbah, N.N.D. (2026)
#' Tourism alters mammal behaviour and juvenile distribution in a West African
#' protected area. \emph{Oryx}. \doi{10.1017/S0030605325102500}
#'
#' @examples
#' recs <- data.frame(
#'   station  = "CAM01",
#'   species  = "Kobus kob",
#'   datetime = as.POSIXct("2021-06-02 08:00:00", tz = "UTC") +
#'                60 * c(0, 5, 10, 15, 90),
#'   females  = c(3, 5, 2, 3, 1),
#'   juveniles = c(0, 0, 1, 1, 0)
#' )
#'
#' # Conventional time-only filter: two events.
#' independent_events(recs, "datetime", "station", "species",
#'                    threshold = 30, rule = "time_only")$independent
#'
#' # running_max: also flags the rise to 5 females and the first juvenile.
#' independent_events(recs, "datetime", "station", "species",
#'                    threshold = 30, rule = "running_max",
#'                    metadata = c("females", "juveniles"))$independent
#'
#' @seealso \code{\link{independence_sensitivity}}
#' @export
independent_events <- function(data,
                               datetime,
                               station,
                               species      = NULL,
                               threshold    = 30,
                               rule         = c("running_max", "any_change", "time_only"),
                               metadata     = NULL,
                               count        = NULL,
                               min_increase = 1,
                               compare_to   = c("last_record", "last_independent"),
                               format       = "%Y-%m-%d %H:%M:%S",
                               tz           = "UTC",
                               filter       = FALSE) {

  rule       <- match.arg(rule)
  compare_to <- match.arg(compare_to)

  if (!is.data.frame(data)) stop("`data` must be a data frame.", call. = FALSE)
  if (nrow(data) == 0L)     stop("`data` has no rows.", call. = FALSE)
  if (!is.numeric(threshold) || length(threshold) != 1L || is.na(threshold) ||
      threshold < 0) {
    stop("`threshold` must be a single non-negative number of minutes.", call. = FALSE)
  }
  if (!is.numeric(min_increase) || length(min_increase) != 1L ||
      is.na(min_increase) || min_increase < 1) {
    stop("`min_increase` must be a single number >= 1.", call. = FALSE)
  }

  need <- c(datetime, station, species, count,
            if (rule != "time_only") metadata)
  missing_cols <- setdiff(need, names(data))
  if (length(missing_cols)) {
    stop("Column(s) not found in `data`: ", paste(missing_cols, collapse = ", "),
         call. = FALSE)
  }

  if (rule != "time_only" && !length(metadata)) {
    stop("`rule = \"", rule, "\"` requires `metadata` column names.", call. = FALSE)
  }

  ## --- date-times -----------------------------------------------------------
  tt <- data[[datetime]]
  if (is.character(tt) || is.factor(tt)) {
    tt <- as.POSIXct(trimws(as.character(tt)), format = format, tz = tz)
  }
  if (!inherits(tt, "POSIXct")) {
    stop("`", datetime, "` must be POSIXct or character parseable with `format`.",
         call. = FALSE)
  }
  if (all(is.na(tt))) {
    stop("No values in `", datetime, "` could be parsed. Check `format`.",
         call. = FALSE)
  }
  n_bad <- sum(is.na(tt))
  if (n_bad) {
    warning(n_bad, " record(s) have an unparseable date-time and are each ",
            "treated as a separate event.", call. = FALSE)
  }

  ## --- metadata matrix ------------------------------------------------------
  meta <- NULL
  if (rule != "time_only") {
    meta <- data[, metadata, drop = FALSE]
    if (rule == "running_max") {
      not_num <- metadata[!vapply(meta, is.numeric, logical(1))]
      if (length(not_num)) {
        stop("`rule = \"running_max\"` needs numeric `metadata`; these are not: ",
             paste(not_num, collapse = ", "),
             ". Use `rule = \"any_change\"` for categorical metadata.",
             call. = FALSE)
      }
      meta <- as.matrix(meta)
      storage.mode(meta) <- "numeric"
    } else {
      ## any_change compares as character so factors, logicals and numbers
      ## all behave predictably.
      meta <- as.matrix(as.data.frame(lapply(meta, as.character),
                                      stringsAsFactors = FALSE))
    }
  }

  tot <- if (!is.null(count)) as.numeric(data[[count]]) else NULL

  ## Group size used to infer how many individuals were newly seen. Prefer an
  ## explicit count column; otherwise fall back to the sum of numeric metadata.
  size <- tot
  if (is.null(size) && length(metadata) &&
      all(vapply(data[, metadata, drop = FALSE], is.numeric, logical(1)))) {
    size <- rowSums(data[, metadata, drop = FALSE])
  }

  ## --- grouping -------------------------------------------------------------
  keys <- list(as.character(data[[station]]))
  if (!is.null(species)) keys <- c(keys, list(as.character(data[[species]])))
  grp <- do.call(paste, c(keys, sep = "\r"))

  independent <- logical(nrow(data))
  burst_id    <- integer(nrow(data))
  event_id    <- integer(nrow(data))
  n_new       <- rep(NA_real_, nrow(data))

  for (rows in split(seq_len(nrow(data)), grp)) {
    res <- .flag_one_group(
      times        = tt[rows],
      meta         = if (is.null(meta)) NULL else meta[rows, , drop = FALSE],
      total        = if (is.null(tot))  NULL else tot[rows],
      size         = if (is.null(size)) NULL else size[rows],
      threshold    = threshold,
      rule         = rule,
      compare_to   = compare_to,
      min_increase = min_increase
    )
    independent[rows] <- res$independent
    burst_id[rows]    <- res$burst
    event_id[rows]    <- res$event
    n_new[rows]       <- res$n_new
  }

  data$independent <- independent
  data$event_id    <- event_id
  data$burst_id    <- burst_id
  data$n_new       <- n_new

  if (filter) data[data$independent, , drop = FALSE] else data
}


#' Internal worker: flag one station x species group
#'
#' Sequential by construction, because whether a record opens a new event
#' depends on the running state of the burst it belongs to. Written as an
#' explicit loop so the rule is auditable line by line.
#'
#' @noRd
.flag_one_group <- function(times, meta, total, size, threshold, rule,
                            compare_to, min_increase = 1) {

  n <- length(times)
  ord <- order(times, method = "radix")   # ties keep input order
  t_s <- times[ord]
  m_s <- if (is.null(meta))  NULL else meta[ord, , drop = FALSE]
  c_s <- if (is.null(total)) NULL else total[ord]
  s_s <- if (is.null(size))  NULL else size[ord]

  indep <- logical(n)
  burst <- integer(n)
  ## running maximum group size within the current burst, recorded after each
  ## record; used below to infer how many individuals were newly seen
  bmax  <- rep(NA_real_, n)
  indep[1] <- TRUE
  burst[1] <- 1L
  if (!is.null(s_s)) bmax[1] <- s_s[1]

  if (n > 1L) {
    max_meta  <- if (rule == "running_max") m_s[1, ] else NULL
    max_total <- if (rule == "running_max" && !is.null(c_s)) c_s[1] else NULL
    last_indep_time <- t_s[1]
    b <- 1L
    run_size <- if (is.null(s_s)) NA_real_ else s_s[1]

    for (i in 2:n) {

      ref <- if (compare_to == "last_record") t_s[i - 1] else last_indep_time
      gap <- as.numeric(difftime(t_s[i], ref, units = "mins"))

      new_burst <- is.na(gap) || gap > threshold

      if (new_burst) {
        indep[i] <- TRUE
        b <- b + 1L
        if (rule == "running_max") {
          max_meta  <- m_s[i, ]
          if (!is.null(c_s)) max_total <- c_s[i]
        }
        ## new burst: the running group-size maximum restarts
        if (!is.null(s_s)) run_size <- s_s[i]
      } else {
        ## isTRUE() so that NA metadata is treated as "no evidence of a new
        ## individual" rather than propagating NA into the flag.
        indep[i] <- switch(
          rule,
          time_only   = FALSE,
          any_change  = isTRUE(any(m_s[i, ] != m_s[i - 1, ])),
          running_max = isTRUE(any(m_s[i, ] >= max_meta + min_increase)) ||
                        isTRUE(!is.null(c_s) && c_s[i] >= max_total + min_increase)
        )
        if (!is.null(s_s)) run_size <- max(run_size, s_s[i], na.rm = TRUE)
        if (rule == "running_max") {
          ## The running maximum absorbs every record in the burst, retained or
          ## not. This is what stops a value already seen from re-triggering.
          max_meta <- pmax(max_meta, m_s[i, ])
          if (!is.null(c_s)) max_total <- max(max_total, c_s[i])
        }
      }

      burst[i] <- b
      bmax[i]  <- run_size
      if (indep[i]) last_indep_time <- t_s[i]
    }
  }

  ## Every record carries the id of the event it belongs to, so dependent
  ## records can be aggregated back onto their event.
  event <- cumsum(indep)

  ## ------------------------------------------------------------------------
  ## Individuals newly seen at each event.
  ##
  ## A group of three animals passing together is ONE encounter containing
  ## three individuals, not three encounters. But if a rule splits a burst,
  ## naively taking the group size of each resulting event double-counts the
  ## animals that were already there. The defensible quantity is the increment:
  ## how far the running maximum group size rose during this event relative to
  ## where it stood when the event opened. Summing this over events recovers the
  ## number of distinct individuals, counting each animal exactly once.
  ## ------------------------------------------------------------------------
  n_new_s <- rep(NA_real_, n)
  if (!is.null(s_s)) {
    starts <- which(indep)                    # events are consecutive runs, so
    ends   <- c(starts[-1L] - 1L, n)          # each run ends before the next
    ev_max     <- bmax[ends]
    ev_burst   <- burst[starts]
    prev_max   <- c(0, ev_max[-length(ev_max)])
    prev_burst <- c(NA_integer_, ev_burst[-length(ev_burst)])
    ## only carry the previous maximum forward within the same burst
    base    <- ifelse(!is.na(prev_burst) & ev_burst == prev_burst, prev_max, 0)
    n_new_s <- rep(ev_max - base, times = ends - starts + 1L)
  }

  ## back to caller's row order
  out <- list(independent = logical(n), burst = integer(n),
              event = integer(n), n_new = numeric(n))
  out$independent[ord] <- indep
  out$burst[ord]       <- burst
  out$event[ord]       <- event
  out$n_new[ord]       <- n_new_s
  out
}
