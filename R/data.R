#' Simulated camera-trap records with known ground truth
#'
#' A worked example dataset with the structure of a real camera-trap export and,
#' unusually, a column giving the true answer.
#'
#' Every real camera-trap dataset has the same problem: when forty photographs of
#' kob arrive over twenty minutes, nobody knows whether that was one herd
#' standing about or three herds passing through. That number is unobservable, so
#' no real dataset can show which independence rule is closest to correct.
#'
#' In \code{waterhole} the groups were placed deliberately, so \code{true_group}
#' records which arrival each photograph belongs to. Counting distinct values of
#' \code{true_group} gives the number of encounters a perfect filter would
#' recover. This makes it possible to check any rule against the answer.
#'
#' The data are simulated, not real. They are supplied because the survey that
#' motivated this package, in Mole National Park, Ghana, cannot be released: it
#' contains precise locations of threatened species. Parameters were measured
#' from that survey, so the simulated data share its statistical character: a
#' frame-to-frame composition change rate of 2.83%, a median gap between bursts
#' of 1,182 minutes, 6.63 records per burst, and a mean burst duration of 14.1
#' minutes.
#'
#' Four species span the sociality gradient, from a solitary leopard to baboon
#' troops, so the effect of group size on each rule is visible.
#'
#' @format A data frame with 4,471 rows and 9 columns:
#' \describe{
#'   \item{station}{camera identifier, three stations}
#'   \item{species}{scientific name, four species}
#'   \item{datetime}{POSIXct timestamp of the photograph}
#'   \item{males, females, juveniles}{animals of each class visible in this frame}
#'   \item{group_size}{total animals visible in this frame}
#'   \item{behaviour}{categorical, for demonstrating \code{rule = "any_change"}}
#'   \item{true_group}{ground truth: which arrival this photograph belongs to.
#'     Not available in real data.}
#' }
#'
#' @source Simulated by \code{data-raw/make_waterhole.R}, with parameters
#'   measured from the survey reported in Awini et al. (2026)
#'   \doi{10.1017/S0030605325102500}.
#'
#' @examples
#' data(waterhole)
#'
#' truth <- length(unique(waterhole$true_group))
#' truth
#'
#' # How close does each rule get?
#' for (r in c("time_only", "running_max", "any_change")) {
#'   n <- sum(independent_events(
#'     waterhole, "datetime", "station", "species",
#'     threshold = 30, rule = r,
#'     metadata = if (r == "time_only") NULL else c("males", "females", "juveniles"),
#'     count    = "group_size"
#'   )$independent)
#'   cat(sprintf("%-12s %4d events (truth %d, bias %+.1f%%)\n",
#'               r, n, truth, 100 * (n - truth) / truth))
#' }
"waterhole"
