## Tests for independent_events(). Base fixtures build one station x species
## group at controlled spacings and metadata values.

mk <- function(mins, ...) {
  data.frame(
    station  = "CAM01",
    species  = "sp1",
    datetime = as.POSIXct("2021-01-01 00:00:00", tz = "UTC") + mins * 60,
    ...,
    stringsAsFactors = FALSE
  )
}

flag <- function(d, ...) {
  independent_events(d, "datetime", "station", "species", ...)$independent
}

test_that("a single record is always independent", {
  d <- mk(0, adults = 1)
  expect_true(flag(d, threshold = 30, rule = "time_only"))
})

test_that("a gap beyond the threshold always starts a new event", {
  d <- mk(c(0, 45), adults = c(1, 1))
  expect_equal(flag(d, threshold = 30, rule = "time_only"), c(TRUE, TRUE))
  expect_equal(flag(d, threshold = 30, rule = "running_max",
                    metadata = "adults"), c(TRUE, TRUE))
})

test_that("a gap exactly equal to the threshold is not a new event", {
  d <- mk(c(0, 30), adults = c(1, 1))
  expect_equal(flag(d, threshold = 30, rule = "time_only"), c(TRUE, FALSE))
})

test_that("identical records inside the window are dependent under every rule", {
  d <- mk(c(0, 5), adults = c(2, 2))
  for (r in c("time_only", "any_change", "running_max")) {
    expect_equal(flag(d, threshold = 30, rule = r, metadata = "adults"),
                 c(TRUE, FALSE), info = r)
  }
})

test_that("running_max ignores a fall and a return to a value already seen", {
  ## The counting-noise case: 5 -> 3 -> 5 is one group, not three.
  d <- mk(c(0, 5, 10), adults = c(5, 3, 5))
  expect_equal(flag(d, threshold = 30, rule = "running_max",
                    metadata = "adults"), c(TRUE, FALSE, FALSE))
  expect_equal(flag(d, threshold = 30, rule = "any_change",
                    metadata = "adults"), c(TRUE, TRUE, TRUE))
})

test_that("running_max flags a rise above the burst maximum", {
  d <- mk(c(0, 5, 10), adults = c(3, 3, 7))
  expect_equal(flag(d, threshold = 30, rule = "running_max",
                    metadata = "adults"), c(TRUE, FALSE, TRUE))
})

test_that("running_max responds to any one metadata column", {
  d <- mk(c(0, 5), adults = c(4, 4), juveniles = c(0, 1))
  expect_equal(flag(d, threshold = 30, rule = "running_max",
                    metadata = c("adults", "juveniles")), c(TRUE, TRUE))
})

test_that("any_change works with categorical metadata but running_max does not", {
  d <- mk(c(0, 5), behaviour = c("passing", "drinking"))
  expect_equal(flag(d, threshold = 30, rule = "any_change",
                    metadata = "behaviour"), c(TRUE, TRUE))
  expect_error(flag(d, threshold = 30, rule = "running_max",
                    metadata = "behaviour"), "numeric")
})

test_that("count is honoured by running_max alongside metadata", {
  d <- mk(c(0, 5), adults = c(2, 2), n_animals = c(2, 9))
  expect_equal(flag(d, threshold = 30, rule = "running_max",
                    metadata = "adults", count = "n_animals"),
               c(TRUE, TRUE))
})

test_that("compare_to changes how long bursts are subdivided", {
  ## Records every 5 min for an hour, identical metadata.
  d <- mk(seq(0, 60, by = 5), adults = 1)
  expect_equal(sum(flag(d, threshold = 30, rule = "time_only",
                        compare_to = "last_record")), 1L)
  expect_equal(sum(flag(d, threshold = 30, rule = "time_only",
                        compare_to = "last_independent")), 2L)
})

test_that("independence is assessed within station and within species", {
  d <- rbind(
    data.frame(station = "A", species = "x",
               datetime = as.POSIXct("2021-01-01 00:00:00", tz = "UTC"),
               adults = 1, stringsAsFactors = FALSE),
    data.frame(station = "B", species = "x",
               datetime = as.POSIXct("2021-01-01 00:05:00", tz = "UTC"),
               adults = 1, stringsAsFactors = FALSE),
    data.frame(station = "A", species = "y",
               datetime = as.POSIXct("2021-01-01 00:05:00", tz = "UTC"),
               adults = 1, stringsAsFactors = FALSE)
  )
  ## All three are in different groups, so all are independent.
  expect_equal(flag(d, threshold = 30, rule = "time_only"),
               c(TRUE, TRUE, TRUE))
})

test_that("row order is preserved and unsorted input is handled", {
  d <- mk(c(45, 0), adults = c(1, 1))
  expect_equal(flag(d, threshold = 30, rule = "time_only"), c(TRUE, TRUE))

  d2 <- mk(c(5, 0), adults = c(2, 2))
  ## The record at t=0 is the first chronologically, so it is the event.
  expect_equal(flag(d2, threshold = 30, rule = "time_only"), c(FALSE, TRUE))
})

test_that("event_id groups dependent records onto their event", {
  d <- mk(c(0, 5, 45), adults = 1)
  out <- independent_events(d, "datetime", "station", "species",
                            threshold = 30, rule = "time_only")
  expect_equal(out$event_id, c(1L, 1L, 2L))
  expect_equal(out$burst_id, c(1L, 1L, 2L))
})

test_that("filter = TRUE returns only independent records", {
  d <- mk(c(0, 5, 45), adults = 1)
  out <- independent_events(d, "datetime", "station", "species",
                            threshold = 30, rule = "time_only", filter = TRUE)
  expect_equal(nrow(out), 2L)
  expect_true(all(out$independent))
})

test_that("threshold = 0 retains everything except exact-duplicate times", {
  d <- mk(c(0, 1, 2), adults = 1)
  expect_equal(flag(d, threshold = 0, rule = "time_only"),
               c(TRUE, TRUE, TRUE))
  d2 <- mk(c(0, 0), adults = 1)
  expect_equal(flag(d2, threshold = 0, rule = "time_only"), c(TRUE, FALSE))
})

test_that("character date-times are parsed with format", {
  d <- data.frame(station = "A", species = "x",
                  datetime = c("21-06-02 08:00:00", "21-06-02 08:05:00"),
                  adults = 1, stringsAsFactors = FALSE)
  expect_equal(
    independent_events(d, "datetime", "station", "species", threshold = 30,
                       rule = "time_only", format = "%y-%m-%d %H:%M:%S")$independent,
    c(TRUE, FALSE)
  )
})

test_that("NA metadata does not propagate into the flag", {
  d <- mk(c(0, 5), adults = c(2, NA))
  expect_false(anyNA(flag(d, threshold = 30, rule = "running_max",
                          metadata = "adults")))
  expect_false(anyNA(flag(d, threshold = 30, rule = "any_change",
                          metadata = "adults")))
})

test_that("informative errors are raised for bad input", {
  d <- mk(c(0, 5), adults = 1)
  expect_error(flag(d, threshold = -1, rule = "time_only"), "non-negative")
  expect_error(independent_events(d, "nope", "station", "species"),
               "not found")
  expect_error(flag(d, threshold = 30, rule = "any_change"), "requires")
  expect_error(independent_events(d[0, ], "datetime", "station", "species"),
               "no rows")
})

test_that("species = NULL pools all species", {
  d <- data.frame(station = "A", species = c("x", "y"),
                  datetime = as.POSIXct("2021-01-01", tz = "UTC") + c(0, 300),
                  adults = 1, stringsAsFactors = FALSE)
  expect_equal(
    independent_events(d, "datetime", "station", species = NULL,
                       threshold = 30, rule = "time_only")$independent,
    c(TRUE, FALSE)
  )
})

test_that("independence_sensitivity returns a coherent grid", {
  d <- mk(c(0, 5, 10, 45, 50), adults = c(2, 3, 2, 1, 1))
  s <- independence_sensitivity(
    d, "datetime", "station", "species",
    thresholds = c(15, 30), metadata = "adults"
  )
  expect_equal(nrow(s$overall), 6L)
  expect_true(all(s$overall$events <= nrow(d)))
  ## time_only can never retain more events than a metadata rule
  for (th in c(15, 30)) {
    base <- s$overall$events[s$overall$rule == "time_only" &
                             s$overall$threshold == th]
    others <- s$overall$events[s$overall$rule != "time_only" &
                               s$overall$threshold == th]
    expect_true(all(others >= base))
  }
  expect_true(!is.null(s$inflation))
})

test_that("event totals decrease monotonically as the threshold increases", {
  set.seed(42)
  n <- 300
  d <- data.frame(
    station  = sample(c("A", "B"), n, TRUE),
    species  = sample(c("x", "y"), n, TRUE),
    datetime = as.POSIXct("2021-01-01", tz = "UTC") +
                 cumsum(sample(c(30, 120, 4000), n, TRUE)),
    adults   = sample(1:5, n, TRUE),
    stringsAsFactors = FALSE
  )
  s <- independence_sensitivity(d, "datetime", "station", "species",
                                thresholds = c(0, 15, 30, 60, 120),
                                rules = "time_only")
  expect_false(is.unsorted(rev(s$overall$events)))
})
