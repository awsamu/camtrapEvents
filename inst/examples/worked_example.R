################################################################################
##  camtrapEvents: worked example
##
##  Runs on the bundled `waterhole` dataset, so it reproduces without any
##  external files. Because that dataset carries ground truth in `true_group`,
##  every claim below can be checked rather than taken on trust.
################################################################################

library(camtrapEvents)
data(waterhole)

dem   <- c("males", "females", "juveniles")
truth <- length(unique(waterhole$true_group))

cat("records:", nrow(waterhole),
    "| stations:", length(unique(waterhole$station)),
    "| species:", length(unique(waterhole$species)),
    "| TRUE encounters:", truth, "\n\n")

## ---------------------------------------------------------------------------
## 1. How close does each rule get to the truth?
## ---------------------------------------------------------------------------
cat("=== 30-minute threshold ===\n")
for (r in c("time_only", "running_max", "any_change")) {
  ev <- independent_events(
    waterhole, "datetime", "station", "species",
    threshold = 30, rule = r,
    metadata  = if (r == "time_only") NULL else dem,
    count     = "group_size", filter = TRUE
  )
  cat(sprintf("  %-12s %4d events (bias %+5.1f%%)   %4.0f individuals\n",
              r, nrow(ev), 100 * (nrow(ev) - truth) / truth, sum(ev$n_new)))
}

cat("\nNote that the individual count is identical under every rule. Splitting a\n",
    "burst moves animals between events but cannot change how many distinct\n",
    "animals were inferred present. Encounter counts are rule-dependent;\n",
    "individual counts are not.\n\n", sep = "")

## ---------------------------------------------------------------------------
## 2. Why summing group size is the wrong way to count individuals
## ---------------------------------------------------------------------------
ev <- independent_events(waterhole, "datetime", "station", "species",
                         threshold = 30, rule = "any_change", metadata = dem,
                         count = "group_size", filter = TRUE)
cat("=== counting individuals, any_change at 30 min ===\n")
cat(sprintf("  sum(n_new)        %5.0f   <- each animal counted once\n", sum(ev$n_new)))
cat(sprintf("  sum(group_size)   %5.0f   <- double-counts animals already present\n",
            sum(ev$group_size)))
cat(sprintf("  events with no new animal: %d of %d (%.1f%%)\n\n",
            sum(ev$n_new == 0), nrow(ev), 100 * mean(ev$n_new == 0)))

## ---------------------------------------------------------------------------
## 3. Sensitivity: report the choice rather than asserting it
## ---------------------------------------------------------------------------
s <- independence_sensitivity(
  waterhole, "datetime", "station", "species",
  thresholds = c(0, 15, 30, 60, 120), metadata = dem, count = "group_size"
)
cat("=== event totals by configuration ===\n")
print(s$overall, row.names = FALSE)

cat("\n=== inflation over the time-only rule, by species, 30 min ===\n")
print(s$inflation[s$inflation$threshold == 30, ], row.names = FALSE)

cat("\nInflation is largest for the species with the largest groups. That is the\n",
    "signature of observation noise being converted into events, and it is why\n",
    "`any_change` biases between-species comparisons.\n", sep = "")

## ---------------------------------------------------------------------------
## 4. Categorical metadata
## ---------------------------------------------------------------------------
## `any_change` also accepts non-numeric metadata, such as behaviour or an
## individual ID. `running_max` cannot, since it needs a count to compare.
beh <- independent_events(waterhole, "datetime", "station", "species",
                          threshold = 30, rule = "any_change",
                          metadata = "behaviour", filter = TRUE)
cat(sprintf("\nusing behaviour as the metadata: %d events\n", nrow(beh)))
