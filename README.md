# Click Links Continued

**Click Links Continued** is a lightweight World of Warcraft addon that makes supported URLs clickable in chat so you can copy, save, and share them. Right-click supported WoW hyperlinks to generate **Wowhead URLs**, copy IDs, or save them to the **Link Journal**.

A continued and maintained fork of **Click Links** with modern API handling, multi-client support, localization, and optional link sharing.

## Features

### Clickable links in chat

- Detects `http://`, `https://`, `www.example.com`, and domain-style URLs.
- Supports email addresses and IP addresses, including optional ports and paths.
- Works with many Say, Yell, Party, Raid, Guild, Officer, whisper, Battle.net, system-style, and addon-generated messages.
- Battleground and other protected message sources depend on the WoW client.
- Clicking a detected URL opens a selectable popup for **Ctrl+C** copying.

### Wowhead right-click integration

Right-click supported chat hyperlinks, including:

- Items, spells, quests, achievements, and currencies
- Profession/trade and enchant links
- Supported Questie quest links

Available actions include:

- **Copy Wowhead URL** — generate a copyable Wowhead link
- **Copy Wowhead ID** — copy the linked numeric ID
- **Save to ClickLinks Journal** — store the generated URL
- **Save as Favourite** — keep the Wowhead link in favourites

Wowhead database selection varies by supported client. Not every link type is available on every client.

### Link Journal

- Persists saved and clicked links between sessions.
- Reopens links in the copy popup.
- Searches saved entries.
- Marks and unmarks favourites.
- Filters: **All, Favourites, Wowhead, Websites, Discord, History**.
- Sorts: **Recent, Oldest, Title, Copies**.
- Exports links where supported.
- Removes individual entries and clears unpinned entries with confirmation.
- Limits history growth by removing older eligible entries; favourites are protected from routine cleanup.

### Optional link sharing

- Disabled by default; enable it explicitly.
- Sends saved Journal links through **Party, Raid, or Guild** addon messages.
- Incoming links require **accept** or **reject**; they are not saved automatically.
- Includes basic URL validation.

### Minimap and version checking

- Optional LibDataBroker/LibDBIcon minimap button to toggle the Journal.
- Saves minimap button position and visibility.
- Checks addon versions through supported group communications and provides a non-repeating update reminder.

### Localization

Uses **AceLocale-3.0** with English fallback. Locale files are provided for:

| Language | Locale |
|---|---|
| English | `enUS` |
| German | `deDE` |
| Spanish (Spain) | `esES` |
| Spanish (Mexico) | `esMX` |
| French | `frFR` |
| Italian | `itIT` |
| Portuguese (Brazil) | `ptBR` |
| Russian | `ruRU` |
| Korean | `koKR` |
| Japanese | `jaJP` |
| Simplified Chinese | `zhCN` |
| Traditional Chinese | `zhTW` |

All 12 locale files have matching keys. Some secondary Wowhead menu labels may still appear in English.

### Supported WoW client families

Separate TOC files target:

- Retail
- Classic Era
- Burning Crusade Classic
- Wrath of the Lich King Classic
- **Wrath Titan Reforged (China)**
- Cataclysm Classic
- Mists of Pandaria Classic
- Forever client

The Wrath TOC retains **both** `30405` (regular Wrath) and `38002` (Titan Reforged). Actual compatibility depends on client builds and Blizzard APIs.

## Slash commands

Both `/cl` and `/clicklinks` are supported.

| Command | Action |
|---|---|
| `/cl` or `/cl help` | Show available commands |
| `/cl version` or `/cl ver` | Print installed version |
| `/cl journal` or `/cl log` | Toggle Link Journal |
| `/cl minimap` | Toggle minimap button |
| `/cl sharing on` | Enable sharing |
| `/cl sharing off` | Disable sharing |
| `/cl share <ID> PARTY` | Share a Journal entry with your party |
| `/cl share <ID> RAID` | Share a Journal entry with your raid |
| `/cl share <ID> GUILD` | Share a Journal entry with your guild |
| `/cl accept` | Accept a pending incoming link |
| `/cl reject` | Reject a pending incoming link |

## Installation

Install through [CurseForge](https://www.curseforge.com/wow/addons/click-links-continued), or manually:

1. Download the addon archive.
2. Extract the **ClickLinks** folder to your WoW client's `Interface/AddOns/` directory.
3. Ensure the addon files are directly inside `Interface/AddOns/ClickLinks/`.
4. Enable the addon in WoW's AddOns menu.

## SavedVariables

Settings and Journal data are stored locally in `ClickLinksDB`.

## Notes

- Some protected or specially formatted Blizzard UI text cannot be rewritten by chat filters.
- Link availability and Wowhead database selection can differ between WoW clients.
- The addon is designed for low overhead and includes ElvUI chat compatibility handling.

## Credits

- **Original addon:** Click Links by tannerng
- **Continued and maintained fork:** Milestorme
