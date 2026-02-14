# ClickLinksContinued – Full Code Review & Recommendations

## Scope reviewed
- Core addon logic (`ClickLinks.lua`)
- TOC packaging for all client variants (`ClickLinks*.toc`)
- Localization consistency across all locale files (`Locales/*.lua`)

## Executive summary
The addon is generally solid and production-ready: URL handling is defensive, hook safety is considered, localization coverage is complete, and TOC versions are consistent. The biggest improvement opportunity is **cross-version API compatibility hardening** around addon-message APIs and version parsing.

---

## What is working well
1. **Robust chat safety wrappers** for Retail "secret" values via guarded string operations (`pcall` wrappers and pre-check flow).  
2. **Thoughtful hook resiliency** around `SetItemRef`, including recursion protection and re-hook support for UI replacement addons.  
3. **Journal normalization and trimming** avoids sparse-table and unbounded-growth problems in SavedVariables.  
4. **Localization completeness** appears strong with no missing keys across provided locales.

---

## Findings & recommendations

### 1) High: Addon-message API is hard-coded to `C_ChatInfo` without fallback
**Evidence**
- `C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)` is called directly.
- `C_ChatInfo.SendAddonMessage(...)` is called directly for guild/group sends.

**Risk**
On some client branches, global API variants (`RegisterAddonMessagePrefix`, `SendAddonMessage`) may be expected or safer. A direct call can break version-sync behavior if `C_ChatInfo` is unavailable or nil in that environment.

**Recommendation**
Create compatibility wrappers once, then use wrappers everywhere:
- `local RegisterPrefix = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix`
- `local SendAddon = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage`
- Guard with `if type(RegisterPrefix) == "function" then ... end`

---

### 2) Medium: `VersionToNumber` assumes `ver` is always a string
**Evidence**
- `local a, b, c = ver:match(...)` with no `tostring`/type guard.

**Risk**
If malformed addon payloads (or future API changes) pass non-string/nil values, this can throw and interrupt event handling.

**Recommendation**
Normalize input first:
```lua
ver = tostring(ver or "")
```
and return 0 for non-matching content as currently done.

---

### 3) Medium: URL detection likely includes trailing punctuation in copied links
**Evidence**
- URL patterns broadly use `%S+`, which captures non-whitespace suffixes.

**Risk**
Chat text like `https://example.com).` can produce clickable URLs containing `)` or `.` at the end, reducing copy accuracy.

**Recommendation**
After match, trim trailing punctuation in `formatURL` (or a dedicated sanitizer), e.g. strip common chat-adjacent suffixes `.,;:!?)` while preserving valid URL characters.

---

### 4) Medium: `ItemRefTooltip:SetHyperlink` hook has no defensive call to original handler
**Evidence**
- Else branch calls `OriginalSetHyperlink(self, link)` directly.

**Risk**
If another addon mutates/replaces this function path unexpectedly, unguarded errors can break hyperlink interactions.

**Recommendation**
Wrap the delegated call in `pcall` (or verify function type first) and fail open gracefully.

---

### 5) Low: `_CL_IsRuntimeDisabled()` is currently dead configuration surface
**Evidence**
- Function always returns `false` and is checked in multiple hot paths.

**Risk**
Not a runtime bug, but adds cognitive overhead and implies a feature toggle that no longer exists.

**Recommendation**
Either remove it entirely (simplify flow) or reintroduce a visible user setting/slash command to control it.

---

### 6) Low: Journal row deletion removes first URL match by value, not stable identity
**Evidence**
- Right-click deletion searches backward for matching `url` text and removes first found.

**Risk**
With duplicate URLs, users may delete a different timestamped entry than expected.

**Recommendation**
Bind UI rows to source index (or unique entry id/timestamp pair) and remove by exact identity.

---

## Suggested implementation order
1. Add chat API compatibility wrappers (Finding #1).  
2. Harden `VersionToNumber` input normalization (Finding #2).  
3. Improve URL sanitizer for trailing punctuation (Finding #3).  
4. Add defensive guard around `OriginalSetHyperlink` delegation (Finding #4).  
5. Cleanup/refactor low-priority maintainability items (#5 and #6).

---

## Validation run during review
- Localization key parity check across `Locales/*.lua` vs `enUS` baseline: no missing/extra keys.
- TOC version consistency check across all client TOCs: all at `2.0.4`.
