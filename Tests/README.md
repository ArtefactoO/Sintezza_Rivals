# Rivals offline checks

Run from the repository root with Python and Lupa 2.8 using its Lua 5.1 engine.

```powershell
python Tests/run.py
```

The runner compiles production Lua, checks TOC paths and the current changelog version, then exercises the following scenarios.

- **Observations and retention** cover 1,000 retained profiles, tied and missing timestamps, deduplicated encounters, old oversized archives, timestamp updates, CSV invalidation, table replacement, metadata, contacts, and watchlist alerts. The bounded index is checked with streams of 10,000 observations.
- **Minimap and nameplates** cover the visible-pin limit, filtering and pooled pins, plus 50 nameplate and dirty events sharing one queued refresh. Removed plates are released immediately.
- **Combat history** loads production event handlers, the damage collector, history integration and CSV policy. It covers 50 attackers, 20,000 spell rows, death and survival, late recaps, repeat deaths, PvE finishers, pets, inaccessible data, and complete-context round trips.
- **Cards and settings** exercise the English and Russian production UI logic with frame and shared-widget stubs: all-visible cards, copied fields, separate duel durations and map shortcuts, match-scoped battleground totals and recap damage, ignore without history loss, immediate marker/HUD refresh, stable pattern variants, sighting-hour ties, nested class colors, shared settings tabs, scrollbar anchors, and recording-dependent control availability. Nameplate panels are checked at wide and narrow widths and when switching between icon and non-icon styles. These checks do not render WoW frames or establish in-game controller behavior.
- **Ignored encounters** keep observations while suppressing both general and watched-player encounter alerts and sounds.
- **Marker scaling** covers attacker-episode deduplication across recap/meter records, cache invalidation, NPC filtering, old-profile preservation, attacker/defeated availability, threshold ordering and dormant fourth-tier values. UI checks cover three visible categories, retained manual settings, compact unfilled sections and paired shared sliders.
- **Coupled edits and settings** cover atomic upward/downward propagation, 200 bounded edits, non-shrinking size over 1,000 counter values, old decreasing-bonus normalization, stable layout during value edits, unresolved visibility, deferred opening, runtime sound selection/failure/fallback, sound preview while paused, dependent map controls and the keybinding launcher.

Pass `--baseline <prior-Sightings.lua>` and `--baseline-minimap <prior-Minimap.lua>` for differential checks. Pass `--output <report.json>` to save metrics. The prior observation implementation is compared at the same 1,000-record capacity. Equal-age eviction permits a different tied key while preserving the retained timestamps.

The combat checks also use the production Theme record/CSV codec to round-trip 50 participants and 1,000 observations. They verify atomic rejection at 1,001 observations and retain the 100-participant import bound per fight.

The combat fixtures model readable client data. Damage-meter details identify a contributing player by name and class, with GUID resolution using independent identity evidence. Native availability and completeness depend on the game client.

Synthetic timing and traversal counts measure Lua work with native API and rendering stubs. They describe backend scaling. Actual client CPU, allocation costs and rendered FPS require an in-game measurement.
