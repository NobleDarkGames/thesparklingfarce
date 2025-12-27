# The Day I Found the Force: A Die-Hard SF Fan Discovers The Sparkling Farce

**Stardate 2025.360** | *Personal Log, Justin, Civilian Aboard USS Torvalds*

---

I was doing my usual morning scroll through r/ShiningForce - you know, the daily ritual where I tell myself "maybe today someone will announce SF4" and then I cry into my coffee - when I saw a post that made me do a literal double-take.

"The Sparkling Farce: A Modding Platform for Shining Force Fans"

My first thought? Here we go again. Another fan project that promises the world and delivers a couple of sprites and an apology post six months later. We have all been there. The abandoned GitHub repos. The "life got in the way" updates. The ROM hack that corrupts your save file at Chapter 5.

I have been burned before. We all have.

But something made me click through anyway. Maybe it was the mention of "SF2-authentic Caravan." Maybe it was "1,282 automated tests." Maybe I just have a problem. Probably that last one.

---

## "Show Me, Don't Tell Me"

The first thing I noticed in the announcement was that they led with links. Demo on itch.io. GitHub repo. Videos of actual gameplay. Videos of creating content.

That is... not normal for fan projects.

Usually you get concept art and a Discord invite. Maybe a GDD that reads like someone's fever dream. The boldest ones might show you a tileset they definitely did not trace from existing sprites.

But these folks? They dropped receipts. The demo actually ran. The town worked. The shops worked with that SF2-style "Who can equip this?" flow. The Caravan followed you around on the overworld like Bowie's mobile HQ. And then - then - they showed you the battle screen.

Damage at impact. HP bar draining in real-time. One session for the full exchange - attack, double attack, counter. Just like SF2.

I may have made an undignified noise.

---

## Down the Rabbit Hole (AKA My Git Clone Era)

OK, so the demo looked legit. But demos can be smoke and mirrors. I needed to see if there was actually something under the hood.

```bash
git clone [repo]
cd sparklingfarce
```

First shock: The thing is 108,918 lines of GDScript. That is not a weekend project. That is not "I started this in college and never finished." That is serious engineering work.

Second shock: The test suite. 1,282 test functions. Fifty test files. They were not kidding about automated testing. For context, some commercial games ship with fewer tests than this fan project has.

Third shock - and this is where my skeptic brain started melting - the architecture actually makes sense.

```
core/           # Platform code - battle systems, shop logic, save/load
mods/           # ALL game content lives here
  demo_campaign/   # Their demo (same priority as user mods)
  your_mod/     # Your content (higher priority overrides base)
```

"The game is just a mod." I read that in the announcement and thought it was marketing speak. It is not. The demo campaign uses the exact same mod system that you would use to make your own game. There is no hardcoded content. The platform does not care whether it is loading "their" game or "your" game.

As a modder who has been hex-editing ROMs since the Clinton administration, this hit different.

---

## The Combat Calculator Made Me Feel Things

I am going to get a little nerdy here. Bear with me.

When I opened `core/systems/combat_calculator.gd`, I found this:

```gdscript
## Calculate counter chance based on defender's class
## SF2 uses class-based rates (1/4, 1/8, 1/16, 1/32) not agility
## Returns: Counter chance percentage (0-50)
static func calculate_counter_chance(defender_stats: UnitStats) -> int:
```

That comment. "SF2 uses class-based rates not agility." Someone actually knows how SF2 combat works. Not "I played it once and it felt right" - they documented the actual mechanics.

Counter rates by class. Terrain defense bonuses. Level-difference XP scaling. Formation XP for nearby allies. Double attack rates by class. All of it is there, and all of it is moddable.

Want different formulas? You can swap in your own `CombatFormulaBase` without touching the core engine. Want to make a tactical RPG that plays nothing like Shining Force? You can do that too.

This is what respect for the source material looks like.

---

## The Caravan Actually Exists

Every fan project talks about implementing the Caravan. Very few actually do it. It is complicated - you need party management, item storage, overworld following behavior, map visibility logic, service menus...

They built all of it.

```
CaravanController.gd - 930 lines
caravan_follower.gd
caravan_data.gd
caravan_main_menu.gd
caravan_depot_panel.gd
```

The Caravan follows your party using a breadcrumb trail pattern. It spawns on overworld maps and despawns in towns (because that is what churches are for - this is not my opinion, it is SF2 canon). It has party management with the hero locked to slot 0. It has unlimited depot storage.

There is even support for mods to register custom Caravan services. Want to add a fortune teller to your wagon? You can do that without touching engine code.

I am not crying, you are crying.

---

## The Cinematic System Is Absurd (Complimentary)

The cinematic system has 23 command types:

- Dialog with portraits and emotions
- Camera movement, following, and shake
- Entity spawning, movement, and facing
- Fade transitions
- Party member management (recruit, remove, rejoin)
- Item grants
- Scene changes
- And more

All of it is defined in JSON. No code required. Here is an actual cinematic from their demo:

```json
{
  "commands": [
    {"type": "set_backdrop", "params": {"map_id": "opening_cinematic_map"}},
    {"type": "camera_follow", "target": "actor_1"},
    {"type": "fade_screen", "params": {"fade_type": "in", "duration": 1.0}},
    {"type": "dialog_line", "params": {
      "character_id": "vt5pq759",
      "text": "What an amazing opening cinematic!"
    }},
    {"type": "move_entity", "target": "actor_1", "params": {"path": [[10.0, 9.0]]}}
  ]
}
```

You want to make that chicken in Granseal tell its life story? You can do that. You want an hour-long cutscene with full camera work and party drama? You can do that too. With a visual editor. In the Godot plugin.

Twenty-two visual editors. One hundred percent resource coverage. I counted.

---

## The "What If" List

As I dug through the code, I kept thinking about what this could mean:

**What if** we could finally play all those "Shining Force but with MY characters" scenarios we have been daydreaming about since 1994?

**What if** the SF community could share campaigns like the Fire Emblem community shares ROM hacks?

**What if** someone actually made that SF1/SF2 crossover with the REAL ending to the Max storyline?

**What if** we got a total conversion that is basically "Shining Force but it's Star Trek and instead of Centaurs you have Klingons"?

(That last one is definitely not something I am already planning. Definitely not.)

---

## The Concerns (Because I Am Still a Skeptic)

Look, I have to be honest. This project is not finished. The demo is a proof of concept, not a polished game. The "full base game content" section on their roadmap says "not yet started."

And 108K lines of code with three people maintaining it is... a lot. Open source projects can struggle with bus factor issues. If the main dev gets hit by a meteor, what happens?

But here is the thing - they built the hard parts first. The mod system works. The combat works. The Caravan works. The editors work. What is left is content creation, which is the whole point of a modding platform.

You do not need them to finish a campaign. You can make your own. Today. Right now. That is the entire pitch.

---

## The Verdict: Shields Up, But Optimistically

I have been hurt before. We all have. The announcement graveyards of r/ShiningForce are full of projects that never shipped.

But The Sparkling Farce is different. It is not promising a finished game - it is delivering working tools. The code is there. The tests are there. The demo runs. The editors exist.

Is it perfect? No. Is the demo campaign a masterpiece? No, it is placeholder content with developer art, exactly as advertised.

But is this the first SF modding platform that feels like it could actually become something real? Something the community could rally around and build on for years?

Yeah. Yeah, I think it might be.

I am going to keep watching this project. I might even start messing around with the editors. And if six months from now they have abandoned it and broken my heart like every other fan project...

...well, at least the code is open source. Someone can pick it up. That is more than we have ever had before.

*May your fire forever burn like Kiwi's breath.*

---

**Justin out.**

*P.S. - If anyone wants to collaborate on a Shining Force campaign set aboard a starship, hit me up. I already have ideas for how Domingo would work in zero gravity.*
