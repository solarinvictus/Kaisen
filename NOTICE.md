# Kaisen source notice

Kaisen 1.0.20 — 2026-10-14.
Original Lua implementation generated for the user's HorizonXI setup.
Distributed under GNU GPL version 3 or, at your option, any later version.
The complete GPL v3 license is in LICENSE; all runtime source is included.

The visual theme is adapted from the Renkei UI created earlier in this project
under GPL-3.0-or-later. Kaisen does not depend on Renkei or Deeps.

Technical references consulted for packet layouts, message meanings and Ashita
API conventions:

- https://github.com/atom0s/XiPackets/tree/main/world/server/0x0028
- https://github.com/Windower/Resources/blob/master/resources_data/action_messages.lua
- https://github.com/AshitaXI/Ashita-v4beta/tree/main/addons/libs/annotations/SDK
- https://github.com/relliko/Deeps

Kaisen uses an original accounting engine and decoder implementation informed
by those public protocol/API references. No Deeps executable or source file is
redistributed. The panel uses native drawn shapes. The job-icon artwork is distributed from XIUI, as detailed below.
No endorsement by Square Enix, HorizonXI, Ashita or those projects is implied.


## XIUI job icons

The PNG files in assets/jobs/FFXI, Classic and FFXIV-1 are unmodified files from
https://github.com/tirem/XIUI/tree/main/XIUI/assets/jobs
Revision: 4493ec0963abadf69a0c7d9a9d76e3ce4e45c90a
Retrieved: 2026-10-14. XIUI is distributed under GPL v3 (see bundled LICENSE).
The texture-loader conventions follow XIUI's libs/texturemanager.lua.

XIUI's supplied credit files are preserved alongside the icons:
- Classic: SirZerick, https://www.twitch.tv/sirzerick
- FFXIV-1: Final Fantasy XIV (Square Enix) and Tylas11, https://github.com/Tylas11
Original game imagery remains the property of its respective rights holders.
These assets are included for this user's FFXI UI; no endorsement is implied.
