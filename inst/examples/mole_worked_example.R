################################################################################
##  Worked example: Mole National Park camera-trap survey, Ghana, 2020-2021
##
##  Reproduces the independence filtering used in Awini et al. (2026, Oryx) and
##  the sensitivity analysis reported in the accompanying software paper.
##
##  Input: a camera-trap export with one row per photograph and columns for
##  station, species, date-time, group size and age/sex counts.
################################################################################

library(camtrapEvents)

input_file <- "survey-export_v3-liboffice.csv"
out_dir    <- "independence_output"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

recs <- read.csv(input_file, stringsAsFactors = FALSE)
recs$species <- trimws(paste(recs$Genus, recs$Species))

## Blank age/sex cells mean "none of this class recorded", i.e. zero.
dem <- c("Unknown.Adult", "Adult.Male", "Adult.Female", "Juvenile")
for (cc in c(dem, "Number.of.Animals")) {
  v <- suppressWarnings(as.numeric(trimws(as.character(recs[[cc]]))))
  v[is.na(v)] <- 0
  recs[[cc]] <- v
}

cat("Records:", nrow(recs),
    "| stations:", length(unique(recs$Sampling.Unit.Name)),
    "| species:",  length(unique(recs$species)), "\n\n")


## ---------------------------------------------------------------------------
## 1. The filter as published in Oryx: 30 min, any change in age/sex counts
## ---------------------------------------------------------------------------

oryx <- independent_events(
  recs,
  datetime   = "Photo.Date.Time",
  station    = "Sampling.Unit.Name",
  species    = "species",
  threshold  = 30,
  rule       = "any_change",
  metadata   = dem,
  compare_to = "last_record",
  format     = "%y-%m-%d %H:%M:%S"
)
cat("Oryx rule (30 min, any_change):", sum(oryx$independent), "events\n")


## ---------------------------------------------------------------------------
## 2. The recommended rule: same threshold, running maximum
## ---------------------------------------------------------------------------

recommended <- independent_events(
  recs,
  datetime  = "Photo.Date.Time",
  station   = "Sampling.Unit.Name",
  species   = "species",
  threshold = 30,
  rule      = "running_max",
  metadata  = dem,
  count     = "Number.of.Animals",
  format    = "%y-%m-%d %H:%M:%S",
  filter    = TRUE
)
cat("Recommended (30 min, running_max):", nrow(recommended), "events\n\n")

write.csv(recommended, file.path(out_dir, "mole_independent_events.csv"),
          row.names = FALSE)


## ---------------------------------------------------------------------------
## 3. Sensitivity across thresholds and rules
## ---------------------------------------------------------------------------

sens <- independence_sensitivity(
  recs,
  datetime   = "Photo.Date.Time",
  station    = "Sampling.Unit.Name",
  species    = "species",
  thresholds = c(0, 15, 30, 60, 120),
  rules      = c("time_only", "running_max", "any_change"),
  metadata   = dem,
  count      = "Number.of.Animals",
  format     = "%y-%m-%d %H:%M:%S"
)

cat("---- Event totals by configuration ----\n")
print(reshape(sens$overall[, c("rule", "threshold", "events")],
              idvar = "threshold", timevar = "rule", direction = "wide"),
      row.names = FALSE)

cat("\n---- Per-species inflation over the pure time rule, 30 min ----\n")
inf30 <- sens$inflation[sens$inflation$threshold == 30, ]
print(head(inf30[order(-inf30$time_only), ], 15), row.names = FALSE)

write.csv(sens$overall,   file.path(out_dir, "sensitivity_overall.csv"),   row.names = FALSE)
write.csv(sens$by_species,file.path(out_dir, "sensitivity_by_species.csv"),row.names = FALSE)
write.csv(sens$inflation, file.path(out_dir, "sensitivity_inflation.csv"), row.names = FALSE)


## ---------------------------------------------------------------------------
## 4. Figure: where the extra events fall
## ---------------------------------------------------------------------------
## The diagnostic plot for the paper. If inflation tracks group size, the rule
## is introducing a bias correlated with sociality.

if (!is.null(inf30) && nrow(inf30)) {
  png(file.path(out_dir, "inflation_by_species.png"),
      width = 1800, height = 1200, res = 200)
  op <- par(mar = c(5, 12, 3, 2))
  d <- inf30[order(inf30$any_change_pct), ]
  barplot(d$any_change_pct, names.arg = d$species, horiz = TRUE, las = 1,
          cex.names = 0.6, xlab = "% increase over pure time rule",
          main = "Extra events created by the metadata rule (30 min)")
  par(op)
  dev.off()
  cat("\nWrote", file.path(out_dir, "inflation_by_species.png"), "\n")
}

writeLines(capture.output(sessionInfo()),
           file.path(out_dir, "session_info.txt"))
