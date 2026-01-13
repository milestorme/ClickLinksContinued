# Click Links Continued

**Click Links Continued** is a lightweight World of Warcraft addon that makes URLs clickable in chat, allowing players to easily open or copy links shared by others.  
This version is a continued and maintained fork with modern API support, an in-game version announcement system, and an optional **Link Journal** that remembers clicked links.

---

## ✨ Features

- 🔗 **Clickable URLs almost everywhere**
  - Websites (`https://`, `http://`)
  - `www.example.com`
  - Email addresses
  - IP addresses (optional ports + paths)
  - Works in normal chat channels *and* many “system/addon output” messages (e.g. Guild MOTD, addon prints)

- 📋 **Copy-friendly link popup**
  - Clicking a link opens a popup with an edit box
  - Easily copy URLs with `Ctrl+C`

- 🧾 **Link Journal (SavedVariables)**
  - Automatically saves clicked links so you can copy them again later
  - Journal entries are clickable (re-opens the copy popup)
  - **Right-click an entry to delete it**
  - **Clear All** button with a confirmation prompt
  - **Cap protection:** when the journal reaches its limit, newest links are kept and oldest links are removed automatically

- 🧭 **Minimap button (LibDBIcon-1.0)**
  - Left-click toggles the Journal window
  - Position + hidden state are saved
  - Toggle with a command if you prefer no minimap icon

- 🔄 **Automatic in-game version checking**
  - Announces your addon version when joining a party or raid
  - Detects newer versions used by group members
  - Displays a **one-time update warning** to avoid spam

- ⚡ **Lightweight & safe**
  - No combat scanning / no performance-heavy loops
  - Safe link handling (won’t corrupt item/spell links)
  - Works across Retail + supported Classic variants (per included TOCs)

---

## 💬 Supported Messages / Channels

Click Links works in nearly all chat types, including:

- Say / Yell
- Party / Raid / Battleground
- Guild / Officer (including Guild MOTD)
- Whispers (including Battle.net)
- Communities
- Many system-style messages and addon “console prints”

> Note: Some Blizzard UI text sources may still be protected or formatted in ways that prevent rewriting. If you find an example that doesn’t convert, open an issue with the exact line.

---

## 🧾 Commands

| Command | Description |
|------|-------------|
| `/clicklinks version` | Prints your installed addon version |
| `/cl version` | Short alias |
| `/cl ver` | Short alias |
| `/cl journal` | Toggle the Link Journal window |
| `/cl minimap` | Toggle the minimap button on/off |

---

## 🛠 Installation

### CurseForge
1. Download from CurseForge (search **Click Links Continued**)  
2. Extract into: `World of Warcraft/_retail_/Interface/AddOns/ClickLinks/`

### Manual / GitHub
1. Download [Release.zip](https://github.com/milestorme/ClickLinks/blob/main/Release.zip)
2. Extract the `ClickLinks` folder into your `Interface/AddOns/` directory
3. Ensure your folder looks like:

```
Interface/AddOns/ClickLinks/
  ClickLinks.toc
  ClickLinks.lua
  Libs/...
```

---

## 📦 SavedVariables

The addon stores settings (and the Journal, if used) in:

- `ClickLinksDB`

---

## 📄 Credits

- Original addon: **Click Links** by tannerng
- Continued & maintained fork: **Milestorme**
