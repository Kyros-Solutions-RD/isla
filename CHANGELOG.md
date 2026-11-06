# Changelog

## 1.1.10 — 2026-11-05

- VoiceOver names every icon button in the notch by what it does: lyrics, join a meeting, open Calendar, fewer or more minutes, reset, play the focus sound, new note, delete, restart, faster or slower, bigger or smaller text. Before, some were read by their symbol (“bubble”, “circle”, “trash can”).
- Task checkboxes are read as the task and whether it is completed.

## 1.1.9 — 2026-11-05

![The AI tab with agents at work and local models](website/assets/app/glass-agents.jpg)

- Fixes leaving the Teleprompter tab touching the microphone: if the microphone permission had never been answered, macOS asked for it and Isla froze until you replied, even if you never used “Follow voice”. Now the microphone is only used while Follow voice is on.
- The website shows the AI tab, with new screenshots of every tab.

## 1.1.8 — 2026-11-05

- Two things at once, like the Dynamic Island: when a second activity is going on (an agent working while music plays, a timer and a download…), it splits off into a small bubble beside the island with the song's cover, the agent's icon or a progress ring. Click the bubble to open its tab. You can turn it off in Settings › Live Activities.

## 1.1.7 — 2026-11-05

- An agent that finishes and exits (a one-shot run, a closed terminal) no longer just disappears: it stays in the AI tab for ten minutes as **Ended**, and the island says it is done.
- The AI apps you have open show as named chips, and when LM Studio or Ollama is running with no model loaded, a button opens it.
- A tab with a lot to show can no longer push the notch's header up under the camera.

## 1.1.6 — 2026-11-05

- The menu bar menu lists the agents at work or waiting, with their state; click one to bring its app forward. It also opens the AI tab.
- ⌘0 switches to the tenth tab, after ⌘1…⌘9.
- VoiceOver reads the notch header by name (Nook, AI, Shelf… Keep open, Settings) instead of describing the icons, and reads each agent with its tool, model, state, current step and folder.

## 1.1.5 — 2026-11-05

- The Settings window is named after the pane you are in, like System Settings.
- In the AI tab, a long session title keeps its room: the badge shortens to the model, since the icon already shows the tool.
- Empty states in every tab come out of the notch line by line, like the Nook's cards.
- The welcome tour introduces AI Agents.

## 1.1.4 — 2026-11-05

- More battery savings, measured tab by tab: the Focus tab with a timer running went from about 39 % of a core to under 2 %, and a timer around the closed notch from about 10 % to under 1.5 %.
- The stopwatch only redraws while it runs, and timer rings no longer animate a change too small to see every second.
- Downloads of unknown size spin their ring with Core Animation instead of redrawing the notch.

## 1.1.3 — 2026-11-05

- Much lighter on the battery: the notch's animations (the agents' dots, the halo and the music equalizer) now run on Core Animation. With an agent working or music playing and the notch closed, Isla went from about 12 % of a core to about 0.2 %, and the open AI tab from about 45 % to under 2 %.
- An agent waiting for your permission, an answer or a dialog now shows as **Needs you**, with the reason and what it asked for, and the island lets you know right away. Codex approvals count too.
- The AI tab shows how big each session's context is when you point at its model.
- Optional sound when an agent finishes or needs you, in Settings › AI Agents.

## 1.1.2 — 2026-11-05

- New **AI Agents** widget for the Nook: the agents at work, their project, state and time at a glance, next to your music and weather. Click it to open the AI tab. Add it in Settings › Nook & Widgets.
- The Tasks progress bar now matches the rest of the notch and stays empty until you finish something.

## 1.1.1 — 2026-11-05

- The AI tab shows the model each session uses, when it started and how long it has been working or waiting.
- Codex sessions now show whether a turn is running, what Codex is doing (the command it runs or the file it edits) and how much of its 5-hour usage limit is used.
- Local models list the running servers under the title, and the context size moved to the tooltip, so nothing gets cut.
- Folder names stay readable: when space is short, the AI tab shows just the project.
- Lists in the notch (AI, Calendar, Tasks, Focus and Notes) fade out at the edges instead of being cut off.

## 1.1.0 — 2026-11-05

- New **AI** tab: the coding agents running on your Mac, in Terminal or in their own app, with the folder each one works in, how long it has been running and whether it is working, waiting or needs you. It also shows what each agent is doing right now and its activity over the last minute.
- Editors built around an agent, such as Antigravity and Cursor, appear with their open project, and the AI apps you have open are one click away.
- Local models: see which models Ollama and LM Studio keep in memory, how much memory they use and when they unload.
- While an agent works, its icon and project appear around the closed notch. When it finishes or stops to ask you something, the island lets you know, and a dot on the AI tab shows it too.
- Settings › AI Agents turns the tab, the notch activity and the alerts on or off, and lets you add any other agent by its command name. No new permissions: Isla only looks at your own processes, and nothing leaves your Mac.

## 1.0.5 — 2026-11-05

- The Updates section in Settings › About is now fully translated.
- Settings › Privacy explains what to do when Accessibility looks switched on in System Settings but doesn't apply to Isla.
- Confirmed on a real Mac: permissions granted to Isla stay granted across updates.

## 1.0.4 — 2026-11-05

- The Nook now opens like the Dynamic Island: a touch of bounce, and the cards come out of the notch one after another.
- Tabs slide in from the side you picked, and the tab icons light up under the pointer.
- Live activities emerge from the camera toward each side.
- A new song swaps the cover with a soft blur, and the notch swells when you drag a file onto it.
- Permissions you grant to 1.0.3 or later stay granted after every update.

## 1.0.3 — 2026-11-05

- Isla now keeps Accessibility and its other permissions across updates. Builds are signed with a stable identity instead of a different one each time. Because the identity changes once, macOS asks for Isla’s permissions one last time after installing 1.0.3: allow Calendar, Reminders, Location and the rest again from the Nook or Settings › Privacy, and turn Accessibility off and on for Isla in System Settings.
- The welcome tour and Settings › Privacy update each permission as soon as you allow it, without reopening them.
- The weather card shows the next hours under the current temperature.

## 1.0.2 — 2026-11-05

- Fixes Isla not opening: versions 1.0.0 and 1.0.1 closed right after launch on every Mac. If you installed one of them, download Isla again from isla.kyrosrd.com.
- The welcome window, Settings, AirDrop and Quick Look now come to the front with keyboard focus.
- Closing the welcome window early no longer leaves Calendar, Weather, Bluetooth and update checks off until the next launch.
- Every build is now opened and checked before it is published.

## 1.0.1 — 2026-11-05

![The new installer: Isla floats on the horizon, the dotted path of the sun leads to Applications](website/assets/app/installer.jpg)

- A new illustrated installer: drag Isla onto the Caribbean dusk to install, with first-launch help in English and Spanish.
- The app now shows its new icon. Version 1.0.0 shipped with the previous one.
- Clearer first-launch steps for macOS 26: System Settings › Privacy & Security › Open Anyway.

## 1.0.0 — 2026-11-05

First public release.

![The Nook in Liquid Glass with Now Playing, Up Next and Weather](website/assets/app/glass-home.jpg)

- Notch panel for every display, with Liquid Glass or Classic Black, three sizes and an island on displays without a notch.
- Nook with configurable widgets: Now Playing, Up Next, Weather, Focus, Battery & Devices, Shortcuts, Shelf and Quick Note.
- Now Playing for any app in the system Now Playing session, with synced lyrics and AppleScript fallback for Music and Spotify.
- Shelf with drag and drop, AirDrop, sharing and on-device conversions, plus the shake-to-open Pocket.
- Clipboard history with search, filters, pins and auto-paste.
- Calendar with meeting links, Tasks synced with Reminders, Notes, Mirror, Teleprompter with voice follow and Shortcuts.
- Pomodoro, countdown timers, stopwatch and generated focus sounds.
- Live activities for music, charging, Bluetooth devices, volume and brightness, downloads, meetings, timers and Caps Lock.
- Optional replacement for the system volume and brightness overlay.
- Terminal tab powered by SwiftTerm, Quick Actions (keep awake, color picker, capture to Shelf, lock screen, dark mode), Quick Look on the Shelf and synced lyrics under the island.
- Automatic updates through Sparkle, signed with EdDSA and served from isla.kyrosrd.com.
- New app icon.
- English and Spanish.
