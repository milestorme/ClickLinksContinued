
## 2.1.1
- Performance: Optimized URL pattern processing loop (no behavior changes)
- Performance: Reduced global lookups in message handling

## 2.1.0

### Fixed
- Prevented Communities/Guild frame candidate iteration from stopping early when intermediate frame paths are missing, so fallback message frames are still discovered for URL hooking.
- Isolated Communities/Guild hook probing behind a protected call path so login-time chat `AddMessage` hooks (including Guild MOTD URL clickability) continue initializing even if Communities UI frames are not ready yet.

## 2.0.9
— Duplicate formatURL()
— Broken _CL_SafeFind() / _CL_SafeMatch() nesting 
— Pre-check always passes for messages with a period 

## 2.0.8

### Fixed
- ElvUI: fix links appearing 3x in chat with only the first clickable 

## 2.0.7

### Fixed
- Resolved `ADDON_ACTION_FORBIDDEN` error when using **Copy Character Name** from chat.
- Replaced global `SetItemRef` override with secure `hooksecurefunc` to prevent Blizzard UI taint.
- Eliminated unintended interaction with protected `CopyToClipboard()` calls.

## 2.0.6

### Fixed
- Ensured `ClickLinksDB` is safely initialized before copy box positioning logic.
- Minor pattern detection correction for `www.` pre-check.

### Added
- Support for bare domains (e.g. `google.com`) to automatically convert into clickable links.
- Expanded chat filter coverage to include all known `CHAT_MSG_*` events across Classic → Retail.
- Safe cross-client chat filter registration using `pcall` to prevent missing-event errors.

### Changed
- Reworked URL copy popup to match KillOnSight-style draggable copy box (auto-focus + preselected text)
- Copy popup now uses tooltip-style backdrop for solid, consistent background
- Improved frame layering (`DIALOG` strata) to ensure popup appears above UI elements
- Standardized backdrop tiling to match addon visual style

### Improved
- Removed forced re-highlight on text change (prevents cursor lock issues)
- Removed auto-hide on focus loss (prevents popup closing while dragging)
- Added close button to copy popup for better UX
- Hardened chat hook initialization to prevent potential nil-call errors
- Copy popup position now persists across reloads and logout
- Minor internal cleanup for stability and consistency
- Improved trailing punctuation handling for URLs (now excludes accidental quotes and brackets)
- Journal now prevents duplicate entries:
  - Clicking an already-saved URL removes the old entry and re-adds it as the newest.
- Re-registers chat filters on login for improved compatibility with UI mods.
- Strengthened string safety checks for Retail 12.x "secret" chat values.
- Improved `www.` detection pre-check consistency.

### Internal
- Minor hook safety adjustments for load-order stability

## 2.0.5
**Fixes**
- Added addon-message API compatibility fallbacks for cross-client version sync.
- Hardened version parsing for malformed/non-string addon payloads.
- Trimmed trailing punctuation from clickable URL payloads while preserving visible punctuation in chat.
- Added defensive fallback handling when delegating non-URL hyperlink clicks.
- Simplified chat/message hooks by removing dead runtime-disable branches.
- Made journal right-click deletion deterministic by row identity (index+timestamp+url).

## 2.0.4
**Fixes**
- Restored literal pipe characters in copied/stored URLs to avoid double-escaping.
- Allowed two-part versions like 1.2 to compare correctly for update warnings.

## 2.0.3
**Fixes**
- Fixed ClickLinks copy popup not opening when ElvUI is enabled.
- Reworked hyperlink click handling to hook SetItemRef safely (ElvUI-compatible).
- Fixed stack overflow / recursion from SetItemRef re-wrapping.
- Non-URL links (player/item/spell/etc.) now pass through untouched.
- Added recursion guards to prevent conflicts when other addons replace SetItemRef.

## 2.0.2
**Retail / All Versions**
- Removed PvP auto-disable logic entirely (no longer needed on Retail 12.x).
- ClickLinks now operates normally inside battlegrounds and arenas.
- Journal entries now display URLs in Blizzard-style hyperlink blue.
- Internal cleanup: removed unused PvP settings, runtime flags, slash commands, and locale keys.
- Fixed URL copy popup not opening with ElvUI by hooking hyperlink clicks at SetItemRef (more robust than ItemRefTooltip:SetHyperlink).

## 2.0.1a
- Added icon
- Fixed journal not saving on Titan Reforged

## 2.0.1
- Auto-disable ClickLinks processing in battlegrounds/arenas and safely skip Retail 12.x "secret" chat values.

## 2.0.0
- Added support for Midnight

## 1.1.9
- Shortened tooltip strings for narrow tooltips
- Improved non-English tooltip layout
- Added full translations for all major locales
- Added TOC locale metadata
- No functional changes

## 1.1.8
- Added multi-language support
- Client compatibility updates
