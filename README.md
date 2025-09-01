<p align="center">
  <img src="https://github.com/MrGovindDubey/Dooms-AI-Plasmoid/blob/Master/plasmoids/org.doomsai.chat/contents/logo.png?raw=true" alt="DOOMS AI Logo" width="128" height="128" />
</p>
<h1 align="center">DOOMS AI — Plasmoid </h1>
<p align="center">Local, private, beautiful AI chat for KDE Plasma.</p>

<p align="center">
  <a href="https://github.com/MrGovindDubey/Dooms-AI-Plasmoid/stargazers">
    <img alt="Stars" src="https://img.shields.io/github/stars/MrGovindDubey/Dooms-AI-Plasmoid?style=for-the-badge" />
  </a>
  <a href="https://github.com/MrGovindDubey/Dooms-AI-Plasmoid/issues">
    <img alt="Issues" src="https://img.shields.io/github/issues/MrGovindDubey/Dooms-AI-Plasmoid?style=for-the-badge" />
  </a>
  <img alt="Platform" src="https://img.shields.io/badge/Platform-KDE%20Plasma-1D99F3?style=for-the-badge" />
  <img alt="Privacy" src="https://img.shields.io/badge/Local-Private%20%26%20Offline-43A047?style=for-the-badge" />
</p>

<p align="center"><b>Local-first • Offline-capable • Uncensored • No cloud required</b></p>

---

## Table of Contents
- Features
- Quick Start
- Install
- Add to Desktop/Panel
- Usage
- Screenshots
- Development
- Privacy
- Troubleshooting
- Roadmap
- Support
- Credits & License

---

## Features
- Sleek chat UI with connection status and progress-based setup
- Small instruction panel during initialization (privacy, performance, roadmap)
- Local-first: your conversations stay on your machine
- Keyboard-friendly input (Enter send, Shift+Enter newline)
- Archive panel to save, search, and clear chats
- One-click GitHub access from the header

## Quick Start
```bash
git clone https://github.com/MrGovindDubey/Dooms-AI-Plasmoid.git
cd Dooms-AI-Plasmoid
```
Install the plasmoid:
```bash
# Plasma 6
kpackagetool6 --type Plasma/Applet --install plasmoids/org.doomsai.chat
# Plasma 5 (alternative tools)
kpackagetool5 --type Plasma/Applet --install plasmoids/org.doomsai.chat
# or
plasmapkg2 --type plasma/applet --install plasmoids/org.doomsai.chat
```
If needed, refresh the cache:
```bash
kbuildsycoca6 || kbuildsycoca5
```

## Add to Desktop/Panel
- Right-click your desktop → Add Widgets
- Search for "Dooms AI — Chat"
- Drag it to your desktop or a panel

## Usage
- On first run you’ll see setup with progress steps (Initialize → Engine → Service → Intelligence → Ready)
- The instruction panel appears during setup and disappears when ready
- Type a message and press Enter to send (Shift+Enter for newline)
- Open the Archive from the header to save, search, or clear conversations

## Screenshots
Place screenshots under `docs/images/` and reference them here:

<p align="center">
  <img src="docs/images/screenshot-setup.png" alt="Setup Progress" width="720" />
</p>
<p align="center">
  <img src="docs/images/screenshot-chat.png" alt="Chat UI" width="720" />
</p>

Note: Add your logo image at `docs/images/logo.png` (recommended 512×512 PNG with transparent background). The README header will render it automatically.

## Development
- UI lives in plain HTML/CSS/JS:
  - `plasmoids/org.doomsai.chat/contents/ui/chat.html`
  - `plasmoids/org.doomsai.chat/contents/ui/assets/chat.css`
  - `plasmoids/org.doomsai.chat/contents/ui/assets/chat.js`
- Quick demo (opens with a sample message): open `chat.html?demo=1` in a browser
- Rapid iteration: re-install with `kpackagetool[5|6] --upgrade plasmoids/org.doomsai.chat`

## Privacy
- Designed to be local-first; no cloud dependency by default
- You control data retention via the Archive and your filesystem

## Troubleshooting
- Widget not visible after install → run `kbuildsycoca6` or `kbuildsycoca5`
- Upgrading from older versions → `kpackagetool[5|6] --upgrade` or completely remove and reinstall
- Styles/scripts missing → verify files in `contents/ui/assets/` and paths in `chat.html`

## Roadmap
- Faster responses and optional web access
- Performance tuning across a range of hardware
- Extended archive features (export/share)

## Support
If you like this project, a star helps power the next release:

https://github.com/MrGovindDubey/Dooms-AI-Plasmoid ⭐

## Credits & License
Author: Mr Govind

License: To be determined. If you plan to contribute, open an issue to discuss licensing or include a license header in your PR.
