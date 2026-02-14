# Changelog

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
