# camtrapEvents 0.2.0

Adds the distinction between counting *encounters* and counting *individuals*.

* `independent_events()` gains an `n_new` column: individuals seen at each event
  that were not already counted earlier in the same burst. Summing `n_new` over
  independent records counts each animal exactly once, which is the correct
  numerator for an individual-based relative abundance index. Taking the group
  size of each split event instead double-counts animals that were already
  present.
* `independent_events()` gains a `min_increase` argument controlling how far a
  count must exceed the running maximum before it counts as evidence of a new
  individual under `rule = "running_max"`. The default of 1 preserves previous
  behaviour; raising it guards against miscounting by +/-1.
* Documentation gains an "Events versus individuals" section explaining when to
  use `event_id` and when to use `n_new`.

Note for users of 0.1.0: event flagging is unchanged at `min_increase = 1`, so
existing results are unaffected.

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
