# Changelog

## 1.15.0

- Stabilize linked scaling edits with atomic neighbor propagation, nondecreasing bonuses, fixed slider ranges and data-only refreshes during dragging. Lay out controls from desired visibility and refresh once after opening.
- Regroup recording, detection, alerts, chat and map settings; align settings labels and window-option insets. Clarify sound conditions, add an explicit sound preview and fix the keybinding launcher guard.
- Remove the unrelated explanatory footer from Statistics results.
- Compact player cards with all fields visible in two columns, one name heading, and direct Watch, Ignore, and Copy actions. Duel durations have separate fields; battleground cards use only the selected match.
- Center the main window title and version without a subtitle, move Settings beside the close button, use shared Theme tooltips near the cursor, and anchor the settings scrollbar.
- Connect search controls, copy-dialog fonts and scrolling, banner fonts, map pins, minimap pins and the encounter-strip tooltip to the shared Theme providers; preserve class colors during appearance refreshes.
- Rebuild nameplate settings with three category tabs, compact unfilled Theme sections, paired threshold/bonus sliders, a responsive preview column, and Rivals-local brass swords restored from the original artwork. Temporarily hide manual-marker controls without clearing their saved settings.
- Add attacker scaling based on cached, deduplicated damage episodes and retain confirmed-kill scaling for defeated players. Threshold configuration stays visible before an icon is selected.
- Keep player names in their class color in expanded fight rows, while result labels retain their event colors.
- Use shared Theme controls and upper tabs for settings, show the former advanced settings directly, and explain less obvious options with tooltips.
- Remove separate per-player marker hiding. Ignore refreshes markers and the encounter strip immediately and also suppresses general encounter alerts, while retaining history.
- Add 30 stable, localized fight-pattern descriptions, with qualification rules in tooltips. Show the busiest recorded sighting hour as a range and explain its source.
- Add optional Sintezza Perf developer measurements for rivals history and map.
- Retain up to 1,000 recent opponent observations with a bounded index for updates and oldest-record eviction.
- Combine nameplate events and data changes into one queued marker refresh, and stop minimap scans after filling the visible pin limit.
- Preserve readable full-fight damage-meter participants after a death, including fights with a PvE finishing blow, without adding recap damage twice.
- Tie delayed recap retries to the latest death and prevent a pending combat snapshot from attaching to a later death. Cancel pending damage snapshots when clearing battleground history.

## 1.14.0

- The version appears next to the title in the settings window.
- The PvP history window shows the version beside the title.
- Marker preview and kill-based scaling use shared section headings.
- Left-clicking the minimap icon opens or closes the window.
- Connected window scale, opacity, and layer to the shared Theme settings. The WoW AddOns settings launcher uses the shared Theme helper.
- Updated the project logo and in-game addon icon.
- Enable OpenMap projection and map callbacks when the required functions are available.

## 1.13.7

- Localized the encounter bar tooltip, watched enemy banner, and remaining labels in the chat reports.

## 1.13.6

- Faction icons in the duel history use the shared crest art from Sintezza Theme.

## 1.13.5

- Added a themed hint for marker size thresholds.

## 1.13.4

First public release baseline for WoW Forever 1.60.1.

- World PvP journal and opponent summaries with confirmed kills and grouped fight episodes.
- Separate battleground and duel histories, with duel summaries by player and class.
- Full character names in duels and recovery of missing opponent details when available.
- World-map fight markers, configurable nameplate marks, and watchlist alerts.
- Per-character CSV import and export, record counts, and data maintenance.
- Shared Sintezza Theme with English and Russian interface.
