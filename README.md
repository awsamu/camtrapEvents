# camtrapEvents

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.21628401.svg)](https://doi.org/10.5281/zenodo.21628401)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Metadata-aware independence filtering for camera-trap data**

Camera traps fire repeatedly on the same animal, so raw records are not
statistically independent. Almost every published study handles this with a
fixed time threshold: a record starts a new detection event only if it falls
more than *k* minutes after the previous one at the same station for the same
species. This is what `camtrapR::recordTable(minDeltaTime = ...)`, Camelot,
Camera Base and Wild.ID all implement.

A time threshold alone cannot tell the difference between **one animal that
lingers** and **new individuals arriving**. Baboons and warthogs may hold
station at a waterhole for an hour; a duiker crosses the frame in four seconds.
The same threshold means something different for each, and no single value fixes
that, because the problem is not the value but the fact that time is the only
information being used.

`camtrapEvents` lets the independence decision also use the metadata you already
recorded when tagging images: group size, age and sex counts, behaviour, or
individual ID.

```r
independent_events(
  records,
  datetime  = "Photo.Date.Time",
  station   = "Sampling.Unit.Name",
  species   = "species",
  threshold = 30,
  rule      = "running_max",
  metadata  = c("Adult.Male", "Adult.Female", "Juvenile", "Unknown.Adult"),
  count     = "Number.of.Animals"
)
```

## Installation

```r
# install.packages("remotes")
remotes::install_github("awsamu/camtrapEvents")
```

## The three rules

| Rule | A record inside the time window starts a new event when... | Metadata type |
|---|---|---|
| `time_only` | never | none |
| `any_change` | any metadata column differs from the previous record | numeric or categorical |
| `running_max` | a numeric column exceeds the running maximum for the current burst | numeric only |

`time_only` reproduces the conventional filter, and is the right choice when
metadata is absent or unreliable.

`any_change` is the most permissive. It is the rule used in Awini et al. (2026).
Because it responds to decreases as well as increases, and to a return to a
composition already seen, it can count observer miscounting as biology. In the
Mole National Park data it inflates event totals by 19% overall at a 60-minute
threshold, but that inflation is not evenly spread: it is 31% for *Kobus kob*
and 0% for 15 of 28 species. Any inflation that tracks group size becomes a bias
correlated with sociality in downstream indices such as RAI.

`running_max` is the recommended rule where age and sex counts are available. A
record opens a new event only if some count rises **above everything already
seen in that burst**, which is evidence of individuals not previously counted. A
count that falls, or returns to a value already seen, is not. This roughly
halves the inflation and removes its dependence on oscillating counts.

## Reporting sensitivity

The filter is a researcher degree of freedom, and it is rarely justified from
data. `independence_sensitivity()` runs the grid so you can report the choice
rather than assert it:

```r
s <- independence_sensitivity(
  records,
  datetime = "Photo.Date.Time", station = "Sampling.Unit.Name",
  species  = "species",
  thresholds = c(0, 15, 30, 60, 120),
  metadata = c("Adult.Male", "Adult.Female", "Juvenile", "Unknown.Adult")
)

s$overall     # event totals per rule x threshold
s$by_species  # the same, per species
s$inflation   # % increase of each rule over time_only, per species
```

`s$inflation` is the diagnostic that matters. If the extra events concentrate in
your gregarious species, say so in the paper.

## Relationship to camtrapR

`camtrapEvents` is not a replacement for [camtrapR](https://jniedballa.github.io/camtrapR/),
which covers image management, species identification workflows, occupancy and
SECR inputs. It addresses one step camtrapR treats as purely temporal.

| | camtrapR | camtrapEvents |
|---|---|---|
| Time threshold | `minDeltaTime` | `threshold` |
| Reference point | `deltaTimeComparedTo` | `compare_to` |
| Station vs camera grouping | `camerasIndependent` | `station` |
| Metadata-conditional independence | not available | `rule` + `metadata` |
| Threshold sensitivity reporting | not available | `independence_sensitivity()` |

`camtrapEvents` takes a plain data frame, so it runs on the output of
`camtrapR::recordTable(minDeltaTime = 0)`, a Camelot export, or a Camera Trap
Data Package `observations` table.

## Example data with known ground truth

Real camera-trap data can never tell you which rule is right. When forty
photographs of kob arrive over twenty minutes, nobody knows whether that was one
herd standing about or three herds passing through.

The bundled `waterhole` dataset does know, because the groups were placed
deliberately and `true_group` records which arrival each photograph belongs to:

```r
data(waterhole)
truth <- length(unique(waterhole$true_group))   # 670 encounters

#> time_only     584 events (bias -12.8%)   2046 individuals
#> running_max   677 events (bias  +1.0%)   2046 individuals
#> any_change    741 events (bias +10.6%)   2046 individuals
```

Two things to notice. `running_max` lands within 1% of the truth here, while a
time-only rule misses 13% of encounters and `any_change` invents 11%. And the
individual count is **identical under all three rules**: splitting a burst moves
animals between events but cannot change how many distinct animals were inferred
present.

Per-species inflation over the time-only rule tracks group size exactly as the
mechanism predicts:

| Species | Mean group | `running_max` | `any_change` |
|---|---|---|---|
| *Panthera pardus* | 1 | +1.3% | +2.0% |
| *Tragelaphus scriptus* | 2 | +9.3% | +14.6% |
| *Kobus kob* | 6 | +19.1% | +42.6% |
| *Papio anubis* | 8 | +36.0% | +51.8% |

`inst/examples/worked_example.R` runs all of this end to end.

The data are simulated. The survey that motivated this package, in Mole National
Park, Ghana, cannot be released because it contains precise locations of
threatened species, so `waterhole` was generated from parameters measured on it:
a 2.83% frame-to-frame composition change rate, a 1,182-minute median gap between
bursts, 6.63 records per burst, and a 14.1-minute mean burst duration. See
`data-raw/make_waterhole.R`.

## Whatever you choose, state it

Threshold, rule and reference point are three separate decisions and none of
them is a default. A methods section should read something like:

> Detections were considered independent if separated by more than 30 minutes
> from the previous record of the same species at the same station, or if the
> count of any age or sex class exceeded the maximum already observed within
> that sequence (`camtrapEvents` v0.2.0, `rule = "running_max"`,
> `compare_to = "last_record"`). Event totals under alternative thresholds and
> rules are given in Table S1.

## Citation

Two DOIs, used for different purposes:

- **Concept DOI** `10.5281/zenodo.21628401` always resolves to the latest
  release. This is what the badge above points to, and what `citation()` returns.
- **Version DOIs** pin a specific release. Cite these in a manuscript so readers
  get the exact code you ran: v0.2.0 is
  [`10.5281/zenodo.21639726`](https://doi.org/10.5281/zenodo.21639726),
  v0.1.0 is `10.5281/zenodo.21628402`.

If you use `camtrapEvents`, please cite the software and the original
application:

> Awini, S., Cabeza, M., Goded, S., Mahama, A. & Annorbah, N.N.D. (2026)
> Tourism alters mammal behaviour and juvenile distribution in a West African
> protected area. *Oryx*. doi:10.1017/S0030605325102500

## Licence

MIT
