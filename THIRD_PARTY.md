# Dependency provenance

Dependencies are copied unmodified and mapped directly by Rojo. Licenses are included alongside each library. This avoids a dependency on Wally's package API, which the cloud's current egress policy blocked during setup.

| Component | Source revision | License |
| --- | --- | --- |
| Framework Lifecycle, RateLimit, DataSessions, DataController, Packet, and agent conventions | [frrazer/roblox-game-boilerplate](https://github.com/frrazer/roblox-game-boilerplate/tree/00613ca10e8b0fe64c2fd567869ab1c4700af094) | See upstream source; no separate root license was supplied |
| Signal 2.0.3 and Trove 1.8.0 | [Sleitnick/RbxUtil](https://github.com/Sleitnick/RbxUtil/tree/31f9120fca021e3dec275b42bc7047d626962082) | MIT, included in each vendor directory |
| ProfileStore | [MadStudioRoblox/ProfileStore](https://github.com/MadStudioRoblox/ProfileStore/tree/45c9847cbcf1fc260369c50eb335aba7c35aecdd) | Apache 2.0, included |
| Replica | [MadStudioRoblox/Replica](https://github.com/MadStudioRoblox/Replica/tree/9cae236), as vendored by the framework | Apache 2.0, included |
| Roblox Luau type definitions | [JohnnyMorganz/luau-lsp 1.69.0](https://github.com/JohnnyMorganz/luau-lsp/blob/1.69.0/scripts/globalTypes.d.luau) | Official analysis data downloaded by `scripts/prepare.py` |

The supplied place's artwork, UI, audio, and recovered configuration remain the uploaded game's assets. Reconstruction does not recover missing server code or original save data.
