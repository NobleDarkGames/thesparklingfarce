Background Music
Format: OGG, MP3, or WAV

Place music tracks here. The platform looks for specific filenames.

LAYERED MUSIC SYSTEM:
The AudioManager supports up to 3 layers per track for dynamic music:
  - Base layer:   track_name.ogg (always plays)
  - Attack layer: track_name_layer1.ogg or track_name_l1.ogg (combat intensity)
  - Boss layer:   track_name_layer2.ogg or track_name_l2.ogg (boss battles)

All layer files must be identical length for synchronization.

EXPECTED MUSIC TRACKS:
----------------------
battle_theme.ogg        - Standard battle music
victory_fanfare.ogg     - Plays on battle victory screen
defeat_theme.ogg        - Plays on party defeat screen

OPTIONAL/RECOMMENDED:
--------------------
main_menu.ogg           - Main menu theme (if maps don't specify music)
town_theme.ogg          - Town/shop exploration
overworld_theme.ogg     - Overworld map exploration
boss_battle.ogg         - Boss encounter music
church_theme.ogg        - Church/save point ambiance

Maps and cinematics can specify any music track by name.
Higher priority mods can override tracks from lower priority mods.
