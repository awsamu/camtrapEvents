# camtrapEvents 0.1.0

First release.

* `independent_events()` collapses camera-trap records into independent
  detection events using a time threshold plus, optionally, record-level
  metadata. Three rules: `time_only` (the conventional fixed-threshold filter),
  `any_change` (any metadata difference opens a new event, as used in Awini et
  al. 2026) and `running_max` (only a count exceeding the running maximum for
  the current burst opens a new event).
* `compare_to` selects whether the time gap is measured from the previous
  record or the last retained event, matching the semantics of
  `camtrapR::recordTable(deltaTimeComparedTo = ...)`.
* `independence_sensitivity()` runs the threshold-by-rule grid and returns
  overall counts, per-species counts, and per-species inflation relative to the
  pure time rule.
* Returns `independent`, `event_id` and `burst_id` so dependent records can be
  aggregated back onto their event.
* Base R only, no hard dependencies.
