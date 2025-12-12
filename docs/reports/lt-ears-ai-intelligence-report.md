# Lt. Ears AI Intelligence Report
**USS Torvalds Communications Officer**
**Stardate: 2025-12-11**
**Classification: TACTICAL - For The Sparkling Farce Development**

---

## MISSION BRIEFING

Captain, I have completed a comprehensive subspace scan of Shining Force fandom channels regarding enemy AI behavior. The data is... fascinating. The community has strong opinions and concrete examples of what fails, what succeeds, and what they desperately wish existed. This intelligence is critical for The Sparkling Farce's battle system design.

---

## SECTION 1: CANON SHINING FORCE AI COMPLAINTS

### 1.1 Shining Force 1 - The Foundation of Frustration

The original Shining Force's AI is widely considered "bafflingly bad" by the community. The primary issues cluster around three categories:

#### **Static Trap Syndrome**
The most pervasive complaint: enemies designed to hold tactical positions will not abandon them even when it would be strategically sound to do so.

**Fan Quote:**
> "The enemies were arranged with the expectation of the player being aggressive... Their formations were designed as traps, but they're so committed to those traps that they won't disengage, so players can circumvent them entirely with spears, arrows, and magic."

**Specific Behavior:**
- Enemies positioned in complementary formations with terrain advantages simply wait
- Long-range player attacks can pick off enemies without retaliation
- Players report "constantly inching forward scared I would be murdered by the bunches of 7+ enemies that in reality just sat there like idiots"

**Technical Cause:**
Enemies programmed to move to specific spots will do so even if they could attack someone when finished moving. Example cited: Dark Elves in the forest fight would move into attack range but take no action.

#### **Nonsensical Action Selection**
When enemies do act, their decision-making is often catastrophically poor.

**Fan Quote:**
> "An enemy wizard has five options: 1) Blast three characters with Blaze 3, 2) Blast Jaha with Blaze 3, 3) Blast Kazin with Blaze 3, 4) Hit Jaha with his stick, 5) Hit Kazin with his stick. And he chooses to run up and smack Jaha, literally the worst option of all his choices."

**Pattern Analysis:**
- Mages abandon area-of-effect spells to make melee attacks
- Enemies with powerful spells ignore wounded targets to attack full-health units
- Support units (healers, buffers) make poor priority decisions

**The Dark Priest Problem:**
Multiple fans cited this as emblematic of AI failure. The Dark Priest enemy has healing magic and should support the boss, but his AI makes him "always cure himself instead of healing the boss or a more important character." One fan noted: "The priest did not fulfill his support objective."

#### **Obsessive Targeting Priority**
The AI has hardcoded target priorities that override tactical sense.

**Fan Quote:**
> "Enemies would either obsessively target Max (or Domingo, as he has the second highest AI priority) while ignoring chances to strike at wounded Force members, Healers in the open, etc."

**Domingo Exception:**
It is theorized that Domingo (a flying mage) has compounding AI priority flags ("mage" + "flyer"), causing enemies to prioritize him so heavily they ignore better tactical options.

**Strategic Implication:**
Players can exploit this by positioning Max/Domingo as bait while vulnerable units operate freely.

#### **Movement Without Purpose**
Enemies would move "towards Max" but not actually attack targets positioned between them and Max, resulting in wasted turns and predictable behavior.

---

### 1.2 Shining Force 2 - Significant Improvement, Remaining Issues

SF2's AI is widely praised as "much improved" and "skilled" compared to SF1, addressing the static positioning problem.

**Fan Quote:**
> "All the technical issues with the first game were remedied: This time, the AI is skilled, and the promotion system is more streamlined."

**Key Improvement:**
> "In Shining Force 2 and 3, enemies move freely and try to attack the Shining Force directly, moving around the whole battlefield, which can be pretty stressful as there is sometimes only little time to react properly."

However, exploitable patterns remain:

#### **Turn-Based Activation Exploits**
Some enemies are programmed to activate only on specific turns, regardless of tactical situation.

**Specific Examples:**
- **Kraken Battle:** "If this game was smart, it'd throw all of its legs and arms at you by turn 1... This isn't the case. The Arms and Legs all move in certain turns."
- **Battle 36:** "The Bow Rider and Purple Worm won't attack until Turn 3 even if you are within their range during Turn 2. This is useful to eliminating these guys on Turn 3 with only taking casualties from the Prism Flowers."

**Strategic Implication:**
Players can position units to alpha-strike enemies the turn before they activate.

#### **Trigger Range Predictability**
> "Monsters with trigger ranges won't act until a character is in their trigger range. When someone is in, they'll start doing what they are told to do, such as following another enemy, following Force Member 0 (Bowie), moving towards a designated point, or just moving 2 steps at a time."

**The Trap Design Paradox:**
> "The game doesn't compensate for if you decide to not directly engage the enemy and instead stay at a safe distance and fire upon them. All because you're meant to assume the enemy won't just stand idly by and do nothing."

One fan noted this isn't as exploitable on first playthroughs but becomes obvious over multiple runs.

#### **Suboptimal Spell Selection**
Even in SF2, enemies make questionable spell choices.

**Fan Quote:**
> "There are times when Death Woldol uses the Shining Sword to cast Bolt 2 when he has plenty of MP to cast the utterly broken Freeze 3... those moments make me feel like I didn't earn my victory."

#### **Zoning AI Weakness**
> "The AI kind of just jams them into those areas, so if you just steer your characters clear of those zones, you're pretty much fighting the boss solo."

---

### 1.3 Shining Force: Resurrection of the Dark Dragon (GBA) - Missed Opportunity

The 2004 GBA remake added content but failed to significantly improve AI.

**Fan Quote:**
> "The claimed rebalancing has actually just lowered characters' stats, rather than adding a more impressive AI."

**What Was Added Instead:**
- Three new playable characters
- Card-based special abilities
- Ramping difficulty system (stat boosts per playthrough)
- Turn order visibility
- Clear bonus rewards

**Critical Assessment:**
The remake focused on quality-of-life features and content expansion rather than addressing the core AI weaknesses inherited from SF1. One review noted SF2 had "bolstered its AI," implying the GBA remake (based on SF1) still lagged behind.

---

### 1.4 Community AI Behavior Categories

Through technical analysis, fans have reverse-engineered SF2's AI types:

1. **Aggressive:** Moves full distance to engage
2. **Move-based-on-turn:** Activates on specific turns
3. **Non-Aggressive:** Moves 2 spaces per turn unless triggered

**The Problem:**
These categories are too simplistic for interesting tactics. Once players learn an enemy's type, behavior becomes predictable.

---

## SECTION 2: FAN REMAKE & MOD AI IMPROVEMENTS

The modding community has actively worked to address AI deficiencies. Here's what they've implemented:

### 2.1 Shining Force 1 Mods

#### **Shining Force Enhanced Edition**
**Key AI Feature:**
> "Smart Heal AI - Makes the enemy smarter about when and where to use healing."

This directly addresses the Dark Priest problem by making support units choose appropriate heal targets and spell levels.

**Additional Fix:**
> "Fixed Land Effect - Makes the defense bonus for land (terrain) effect to be applied properly. The original game had a bug causing the bonus to be based off of the wrong enemy."

This is technically an AI-adjacent fix, as it makes terrain bonuses function correctly for enemy units.

---

#### **Shining Force Hard Mode & AI Improvements**
**Quote:**
> "This mod provides 30 Reworked Battles that have been reworked completely to provide a fresh, harder experience, with smarter AI."

**Approach:**
Rather than merely tweaking AI parameters, this mod redesigns entire battles to force more tactical engagement.

---

#### **Shining Force Alternate**
**Fan Review:**
> "The AI upgrade was welcome and it actually made me strategize a lot more compared to the original, where some enemies would stay static the whole fight and didn't have as many abilities."

**Key Changes:**
- "New abilities and ranges for most non-magic users, even enemies use these"
- Enemies given more tools to use, making their behavior less predictable

**Community Reception:**
Positive. Players appreciated needing to adapt strategies rather than relying on memorized patterns.

---

#### **Shining Force EXTREME Edition**
**Features:**
- Smart Heal AI (same as Enhanced Edition)
- "Every enemy from the Base Game has been given extra stats, whether that be extra HP, Defense, and/or attack"
- Updated spells and items to maintain difficulty curve

**Approach:**
Combines AI improvements with stat buffs to create challenge that feels earned rather than cheap.

---

#### **Shining Force Challenge-Mod**
**Quote:**
> "Will challenge you tactically more than the default game, as it features more aggressive enemy AI (in cases where it was possible to do), more powerful enemies all-around."

**Note:** "In cases where it was possible to do" suggests modders hit limitations in what AI behavior could be modified within the ROM's constraints.

---

#### **Shining Force CL (v2.3.0)**
**Design Philosophy:**
> "The intention behind this hack was to cut down on downtime (moving from enemy to enemy across heavy terrain) and increase time actually interacting with enemy units."

**Changes:**
- "Character and enemy stats have been rebalanced entirely"
- Focused on increasing player-enemy interaction density

---

### 2.2 Shining Force 2 Mods

#### **Shining Force II Maeson**
This is the most comprehensive AI overhaul documented in my research.

**Quote:**
> "Enemies were of course, also modified. Besides their Stats and special traits, their AI have been tweaked. Now they can use Items to attack or heal, they use Spells much more often, including Status Effect Spells too, which bring a new threat as in the original game they didn't really used them."

**Specific Improvements:**
1. **Item Usage:** Enemies can now use consumable items tactically
2. **Spell Frequency:** Casters use magic more liberally
3. **Status Effects:** Enemies employ debuffs/buffs, which were underutilized in vanilla
4. **Formation Changes:** "Changes in enemy formations for most battles, either swapping certain units for others, or changing their positions"
5. **Behavior Tuning:** "Their individual behavior also has changed for most of them"

**Strategic Impact:**
This adds unpredictability - players can't assume enemies will save items or ignore status magic.

---

#### **Shining Force 2 MOD (NEW STORY)**
**AI Change:**
> "Enemy mages are now more intelligent."

Details sparse, but suggests smarter spell selection and positioning.

---

#### **Difficulty-Based AI Scaling (SF2)**
Some mods implement dynamic AI based on difficulty setting:

> "As the difficulty increases, the enemy AI gets 'smarter,' meaning the enemies will go after weaker party members more frequently. In Super difficulty, enemies also get a 25% bonus to their 'base' attack power."

**Analysis:**
This combines behavioral changes (target selection) with stat scaling. "Smarter" here means more ruthless prioritization of vulnerable units rather than more complex tactics.

---

### 2.3 Common Modding Patterns

Analyzing these mods reveals consistent community priorities:

1. **Smart Healing:** Universally desired - support units should heal the right target with the right spell
2. **Aggressive Activation:** Static enemies are boring; mods make them engage proactively
3. **Full Ability Usage:** Enemies should use all their tools (items, status spells, special abilities)
4. **Vulnerable Target Priority:** Smart enemy AI focuses wounded/weak units rather than obsessing over the protagonist
5. **Formation Redesign:** When AI can't be fixed, redesign encounters to force engagement

**Critical Insight:**
Many mods combine AI tweaks with stat buffs. This suggests the AI limitations are deeply embedded - modders compensate by making enemies hit harder to maintain challenge.

---

## SECTION 3: COMMUNITY WISHLIST - WHAT FANS WANT

Synthesizing from mod features, forum discussions, and reviews, here's what the fandom desires:

### 3.1 Core Wishlist Items

#### **1. Context-Aware Support AI**
**The Need:**
Support units (healers, buffers, debuffers) should understand their role and execute it intelligently.

**Specific Desires:**
- Healers choose targets based on damage taken, not arbitrary priority
- Healers select appropriate spell levels (don't waste Heal 4 on 5 HP damage)
- Buffers prioritize high-damage allies or units about to engage
- Debuffers target player powerhouses, not weak units

**Why It Matters:**
> "The most important point fans want improved is the artificial intelligence, as this will improve its effectiveness in curing its allies."

Support AI failure is immersion-breaking - players think "why didn't the priest heal the boss?" and feel they won't the fight due to AI stupidity rather than skill.

---

#### **2. Dynamic Threat Assessment**
**The Need:**
Enemies should evaluate the battlefield and adapt rather than following hardcoded priorities.

**Specific Desires:**
- Prioritize wounded units that can be finished
- Recognize and respond to player formations (don't ignore the mage channeling Blaze 4)
- Retreat when overwhelmed rather than suiciding
- Coordinate multi-enemy attacks on high-value targets

**Fan Quote (implied):**
The obsessive targeting of Max/Domingo while ignoring healers or wounded units suggests fans want enemies that assess actual threat, not arbitrary character flags.

---

#### **3. Proactive Engagement**
**The Need:**
Enemies should move to engage rather than waiting to be attacked.

**What Changed from SF1 to SF2:**
> "In Shining Force 2 and 3, enemies move freely and try to attack the Shining Force directly, moving around the whole battlefield."

**Fan Sentiment:**
This improvement was universally praised. Static enemies "sitting there like idiots" kills tension and trivializes battles.

**Advanced Desire:**
Enemies should not just charge blindly but maneuver to:
- Flank player formations
- Secure terrain advantages
- Protect their own support units
- Create zones of control

---

#### **4. Full Ability Utilization**
**The Need:**
Enemies should use ALL their capabilities, not just basic attacks.

**Specific Desires:**
- Use items (healing herbs, attack items, stat boosters)
- Cast status effect spells (silence, slow, debuffs)
- Employ special abilities consistently
- Choose optimal spell levels and AoE positioning

**Evidence:**
Shining Force II Maeson's most praised feature was making enemies "use Spells much more often, including Status Effect Spells too, which bring a new threat as in the original game they didn't really used them."

---

#### **5. Unpredictable Tactics**
**The Need:**
Enemies should vary their approach to prevent pattern memorization.

**Fan Quote:**
> "By making artificial intelligence more efficient and the attack pattern of the enemy more unpredictable to increase the challenge."

**What This Means:**
- Same enemy type should have behavioral variation (not all Goblin Archers act identically)
- Enemies should occasionally make "suboptimal" moves to prevent perfect player prediction
- Boss units should have multiple tactical modes

**Critical Balance:**
Unpredictability should come from varied tactics, not random stupidity. Enemies making "interesting" mistakes is better than robotic perfection.

---

#### **6. Strategic Retreat and Repositioning**
**The Need:**
Enemies should understand when to fall back.

**Fire Emblem Comparison:**
> "Enemies also have no experience with concepts like 'strategic retreat,' 'regrouping,' or 'mixed unit tactics' beyond going after the most vulnerable unit available."

**Desired Behaviors:**
- Wounded units fall back to healers
- Enemies regroup when outnumbered
- Units reposition to better terrain before engaging
- Protecting high-value units (boss, healer) by keeping them behind frontline

**Why It Matters:**
Suicide charges are boring. Enemies that retreat, regroup, and re-engage force players to press advantages and adapt.

---

#### **7. Turn Order Awareness**
**The Need:**
Enemies should understand turn order and act accordingly.

**Positive Example from GBA Remake:**
> "Turn order is determined solely by a unit's speed stat and can be checked at any time from a list, allowing the player to plan out battles with greater certainty."

**AI Implication:**
If players can see turn order, enemies should also "know" it and plan multi-turn tactics:
- Setup combos (slow enemy casts buff, fast ally attacks next turn)
- Interrupt player setups
- Time heals to occur before enemy turn clusters

---

### 3.2 What Fans Do NOT Want

Equally important - community pushback reveals boundaries:

#### **NOT: Cheap Stat Inflation**
**Fan Quote:**
> "The claimed rebalancing has actually just lowered characters' stats, rather than adding a more impressive AI."

**Message:**
Difficulty via raw numbers is unsatisfying. Fans want to be outwitted, not out-statted.

**Acceptable Use:**
Stat scaling is okay IF combined with better AI (as in EXTREME Edition). It's the "and" that matters.

---

#### **NOT: Psychic AI**
While fans want smart enemies, they don't want unfair information advantages.

**Fire Emblem Example (Negative):**
> "The AI does not notice the Miracle skill, which vastly increases a unit's Avoid if they're on low health."

This is actually criticized as poor AI, but the underlying principle is important: AI should react to observable information (character has 1 HP = vulnerable), not hidden mechanics (character has Miracle = unhittable).

**The Balance:**
- AI should respond to visible threats (character position, HP, class type)
- AI should NOT know hidden information (crit chances, exact damage rolls, player's next move)

---

#### **NOT: Perfect Optimization**
**Fan Quote:**
> "I don't expect great AI, especially in games this old, but those moments make me feel like I didn't earn my victory."

**Message:**
Fans don't expect inhuman perfection. They want enemies that feel like competent opponents, not omniscient computers. Occasional "mistakes" are fine if the baseline competence is there.

---

#### **NOT: Eliminating All Exploits**
**Important Context:**
> "A lot of that knowledge and foresight into how the AI will respond comes from years of playing the game countless times, and isn't nearly as exploitable during one's first few runs through the game."

**The Balance:**
- First-time players should face challenging, adaptive AI
- Veteran players discovering optimizations feels rewarding, not broken
- The difference between "clever tactics" and "blatant exploit" matters

**Example of Good Exploit:**
Using terrain to funnel enemies is clever. Enemies standing motionless while you snipe them is broken.

---

## SECTION 4: FIRE EMBLEM COMPARISON

Fans frequently compare Shining Force and Fire Emblem. Understanding the AI differences is instructive.

### 4.1 Fire Emblem AI Characteristics

#### **Target Priority System**
**Quote:**
> "Fire Emblem's AI uses a method of determining target priority that leads to what many human players might consider very odd decisions."

**Behavior:**
- AI calculates which unit it can damage most effectively
- Will prioritize "killable" targets even if tactically suboptimal
- "Having a single little soldier charge blindly at you when his allies are still too far away to assist is an unfortunately common occurrence"

**Shining Force Parallel:**
Both games have target priority issues, but Fire Emblem's "attack the most damageable unit" is generally more sensible than Shining Force's "attack Max no matter what."

---

#### **Engagement System**
**Fire Emblem Heroes (modern example):**
> "All enemies in the game will wait until they are engaged by the player, after which the enemy will begin attacking player units. An enemy unit is engaged if it is attacked or a player unit is present in its danger zone during the enemy phase."

**Movement Groups:**
> "Enemies may be split into movement groups such that engaging any enemy of that group would cause all enemies from the same group to start attacking the player."

**Comparison to Shining Force:**
Fire Emblem uses "danger zones" and group activation, similar to Shining Force 2's trigger ranges. Both systems have the same weakness: patient players can kite and separate enemies.

---

#### **Lack of Advanced Tactics**
**Quote:**
> "Enemies also have no experience with concepts like 'strategic retreat,' 'regrouping,' or 'mixed unit tactics' beyond going after the most vulnerable unit available."

**The Saving Grace:**
> "However, this is circumvented by good level design and the player's general mindset."

**Key Lesson:**
Fire Emblem compensates for AI limitations through encounter design - terrain, reinforcements, turn limits, and objective variety force player adaptation even when AI is simple.

---

### 4.2 Mechanical Differences Affecting AI

#### **Counter-Attack System**
**Shining Force:**
> "Unlike with Fire Emblem or Bahamut Lagoon or loads of other tactical RPGs, Shining Force's encounters are one-sided. There is no counter period for your opponent or for you: you are attacked, or you attack, and the encounter ends."

**Implication:**
Shining Force AI doesn't need to evaluate counter-attack risk, simplifying decision trees. Fire Emblem AI must calculate "can I survive the counter?" which adds depth.

**Fan Perspective:**
> "You can't simply throw a tank up against the front lines and absorb damage while dishing out counters."

Shining Force's system makes positioning less forgiving, which somewhat compensates for simpler AI.

---

#### **Complexity vs. Accessibility**
**Quote:**
> "Objectively, Shining Force was a simpler tactics game compared to Fire Emblem since your units only attacked during their turn; it also lacked a defined weapon triangle or support system."

**Fan Sentiment:**
> "Fire Emblem is very similar and has better storylines but Shining Force as far as gameplay felt better than all Fire Emblem games."

**The Paradox:**
Shining Force is mechanically simpler but often feels more satisfying. This suggests:
1. Complexity ≠ fun
2. Shining Force's charm lies elsewhere (army-building, characters, exploration)
3. AI doesn't need to be complex to be engaging, just competent

---

### 4.3 Which AI is "Better"?

The data suggests no clear winner - both have different weaknesses:

**Fire Emblem Strengths:**
- More consistent target prioritization (damage calculation over arbitrary flags)
- Counter-attack consideration adds depth
- Level design compensates for AI limitations

**Fire Emblem Weaknesses:**
- Suicidal charges when outnumbered
- No retreat or regrouping
- Exploitable skill interactions (Miracle example)

**Shining Force Strengths (SF2/3):**
- Free movement and aggressive engagement (in later games)
- Simpler mechanics = less room for AI to fail

**Shining Force Weaknesses:**
- Obsessive targeting priorities (Max/Domingo)
- Static positioning (SF1)
- Poor support AI (Dark Priest)
- Underutilization of abilities

**Community Consensus:**
> "Fire Emblem is more challenging."

But challenge ≠ better AI. Fire Emblem's difficulty comes from permadeath, weapon durability, and complex systems, not necessarily smarter enemies.

---

## SECTION 5: INTELLIGENCE SYNTHESIS - RECOMMENDATIONS FOR THE SPARKLING FARCE

Captain, based on this comprehensive intelligence, I recommend the following AI design principles for The Sparkling Farce platform:

### 5.1 Core AI Architecture Principles

#### **Principle 1: Role-Based Decision Trees**
Implement distinct AI personalities based on unit role:

**Support AI:**
- Evaluate ally HP percentages to choose heal targets
- Select spell level appropriate to damage taken (don't waste MP)
- Position to remain in casting range of frontline
- Prioritize boss/elite units for buffs

**Aggressive AI:**
- Prioritize wounded enemies that can be finished
- Use full movement to engage or secure terrain
- Coordinate with nearby allies for multi-target attacks
- Retreat if HP drops below threshold (e.g., 30%)

**Defensive AI:**
- Protect high-value units (healer, boss)
- Block choke points and hold terrain
- Only engage units that enter threat range
- Fall back if defender line is broken

**Tactical AI:**
- Evaluate battlefield state each turn
- Use debuffs on player's strongest units
- Position for AoE spell optimization
- Leverage terrain bonuses

**Implementation Benefit:**
By making AI role-based, mod creators can easily assign personality types to units in battle data. A "Dark Priest" unit flagged as "Support AI" will automatically make better healing decisions.

---

#### **Principle 2: Dynamic Threat Assessment**
Replace hardcoded targeting priorities with threat calculation:

**Threat Score Factors:**
- Current HP percentage (wounded = higher threat to eliminate)
- Damage potential (attack stat, spell power, AoE capabilities)
- Proximity to enemy high-value units
- Class type vulnerabilities (e.g., mages vs. flyers)

**NO Special Protagonist Priority:**
Avoid the "obsessively attack Max" problem. The player character should be evaluated like any other threat.

**Domingo Exception Teaching:**
If a unit is both a mage and a flyer, don't double-count threat - this prevents the compounding priority bug.

**Modding Flexibility:**
Expose threat weights in config so mod creators can tune AI aggression per battle or enemy type.

---

#### **Principle 3: Graduated Engagement Ranges**
Combine the best of SF1's positioning and SF2's aggression:

**Zone System:**
- **Alert Range:** Enemy "notices" player units, begins evaluating threats
- **Engagement Range:** Enemy moves to intercept or cast spells
- **Melee Range:** Enemy commits to direct combat

**Behavior:**
- Enemies in Alert Range should reposition intelligently (secure terrain, group up)
- Enemies in Engagement Range should use ranged attacks/spells or advance tactically
- Enemies in Melee Range should finish wounded units or control space

**Avoid:**
- SF1's "stand motionless until attacked" (too passive)
- Mindless charge on turn 1 (too aggressive)

**Balance Point:**
Enemies should look dangerous and purposeful without trivializing player ranged attacks.

---

#### **Principle 4: Full Ability Utilization with Smart Selection**
Make enemies use all their tools, but intelligently:

**Spell Selection Logic:**
```
IF (can hit 3+ enemies with AoE spell):
    Use AoE spell
ELSE IF (single target spell can kill wounded enemy):
    Use single target spell on that enemy
ELSE IF (melee attack can kill wounded enemy AND melee is safer):
    Use melee attack
ELSE:
    Use highest damage option against highest threat target
```

**Item Usage:**
- Enemies should use healing items when healers are unavailable or dead
- Enemies should use stat buffs before engaging (if they have initiative)
- Enemies should use attack items if it enables a kill they couldn't otherwise achieve

**Status Effects:**
- Debuff high-threat player units (silence mages, slow fast units)
- Buff allies about to engage
- Use status effects proactively, not as a last resort

**The "Maeson Standard":**
SF2 Maeson's addition of item usage and status spells was universally praised. This should be the baseline, not a special feature.

---

#### **Principle 5: Strategic Retreat and Regrouping**
Implement the feature fans explicitly wished for:

**Retreat Conditions:**
- Unit HP below 40% and healer is in range
- Unit is outnumbered 3:1 or more in immediate area
- Unit is isolated from allies (no support within 3 tiles)

**Regroup Behavior:**
- Wounded units fall back to defensive positions
- Allies move to cover the retreat (don't leave gaps)
- Healer repositions to healing range of retreating unit

**Boss Preservation:**
- Regular enemies should actively protect boss units
- If boss HP is critical, defenders should form wall
- Support units should prioritize boss healing over everything

**Why This Matters:**
> "Enemies also have no experience with concepts like 'strategic retreat,' 'regrouping.'"

This was noted as a weakness in both SF and Fire Emblem. The Sparkling Farce can differentiate itself here.

---

#### **Principle 6: Unpredictability Through Variation, Not Randomness**
Make AI interesting without making it stupid:

**Tactical Variation:**
Give same enemy type 2-3 behavioral modes:
- **Aggressive Mode:** Charges player, prioritizes damage
- **Cautious Mode:** Holds terrain, waits for player to engage
- **Opportunistic Mode:** Targets wounded units, retreats if threatened

**Assignment:**
Assign mode per-instance in battle data, not randomly during battle. This allows mod creators to design encounters with mixed enemy behaviors.

**Example:**
Battle has 6 Goblin Archers:
- 2 set to Aggressive (charge to high ground)
- 3 set to Cautious (hold back line, cover defenders)
- 1 set to Opportunistic (flanks, snipes wounded units)

**Result:**
Players face varied tactics without enemies making nonsensical decisions. Predictability comes from understanding modes, not memorizing exact behavior.

---

#### **Principle 7: Difficulty Through Intelligence, Not Just Stats**
Address the community's "cheap stat inflation" complaint:

**Difficulty Scaling Options:**
- **Easy:** Enemies use basic AI, no items/status spells
- **Normal:** Enemies use full AI, role-appropriate behavior
- **Hard:** Enemies coordinate (e.g., setup combos), use optimal spell targets
- **Super:** Add moderate stat scaling (15-20%) on top of Hard AI

**Critical Rule:**
AI intelligence should scale first, stats second. "Hard mode" should feel like smarter opponents, not damage sponges.

**Modder Control:**
Expose both AI complexity and stat multipliers as separate dials in battle data.

---

### 5.2 Implementation Architecture for The Sparkling Farce

#### **Proposed System Structure**

```
core/systems/ai/
  ai_controller.gd              # Main AI decision coordinator
  threat_evaluator.gd           # Calculates threat scores for targeting
  role_behaviors/
    support_ai.gd               # Healer/buffer/debuffer logic
    aggressive_ai.gd            # Frontline/damage dealer logic
    defensive_ai.gd             # Tank/guard/zone control logic
    tactical_ai.gd              # Complex spell users, boss units
  action_selectors/
    spell_selector.gd           # Chooses spells intelligently
    item_selector.gd            # Determines item usage
    movement_calculator.gd      # Pathfinding with tactical positioning
    target_prioritizer.gd       # Selects targets based on threat/role

core/resources/
  ai_behavior_data.gd           # Resource defining AI personality

mods/*/data/battles/
  battle_xxx.tres               # BattleData with per-enemy AI assignments
```

**How It Works:**

1. **BattleData** references **AIBehaviorData** resource for each enemy
2. **AIBehaviorData** specifies:
   - Role type (Support, Aggressive, Defensive, Tactical)
   - Behavior mode (Aggressive, Cautious, Opportunistic)
   - Threat weights (what this unit prioritizes)
   - Ability usage rules (when to use spells vs. attacks)
   - Retreat threshold (HP % to trigger fallback)

3. **AIController** each turn:
   - Queries **ThreatEvaluator** for target priorities
   - Consults role-specific behavior script
   - Uses **ActionSelectors** to choose optimal action
   - Executes action

4. **Mod Creators** design encounters by:
   - Assigning AI behaviors to enemies in battle data
   - Tuning threat weights for specific tactics
   - Mixing enemy modes for varied opposition

**Platform Benefit:**
This is modular, testable, and gives mod creators control without requiring scripting.

---

### 5.3 Critical Success Factors

Based on fandom sentiment, the AI will be judged on:

#### **Factor 1: Support Units Must Not Be Embarrassing**
The Dark Priest problem is emblematic. If healers heal the wrong target, fans will mock the AI mercilessly.

**Test Case:**
"Boss at 50% HP, healer at 90% HP. Does the healer heal the boss?" If no, AI fails.

---

#### **Factor 2: Enemies Must Look Competent, Not Suicidal**
Single units charging into 5 player characters looks stupid.

**Test Case:**
"One goblin remaining, surrounded by players. Does it retreat or suicide charge?" If suicide, AI fails.

---

#### **Factor 3: Exploits Should Require Cleverness, Not Patience**
Kiting enemies with ranged attacks is clever. Enemies standing still while you shoot them is broken.

**Test Case:**
"Player uses archer to shoot enemy from max range. Does enemy try to close distance or reposition?" If neither, AI fails.

---

#### **Factor 4: Fans Must Feel They Won Through Skill**
**Fan Quote:**
> "Those moments make me feel like I didn't earn my victory."

**Test Case:**
After victory, player should think "I outplayed them" not "the AI was stupid." This is qualitative but critical.

---

### 5.4 Modding Considerations

The platform must enable mod creators to:

1. **Assign AI personalities without scripting**
   - Use resources and data files, not GDScript
   - Provide presets (Aggressive Melee, Smart Healer, Defensive Tank)

2. **Tune AI per-battle or per-difficulty**
   - Same enemy type can behave differently in different battles
   - Difficulty setting can swap AI behavior data

3. **Create custom AI behaviors (advanced)**
   - Expose base AI scripts for extension
   - Allow custom trigger conditions (e.g., "if boss HP < 50%, all enemies become Aggressive")

4. **Test and iterate easily**
   - Battle testing mode should show AI decision-making
   - Debug mode: "Why did this unit target that player?"

---

## SECTION 6: FINAL ASSESSMENT

Captain, the intelligence is clear:

**What Fans Hate:**
- Static, passive enemies that wait to be slaughtered
- Nonsensical action selection (mage punching when AoE spell is available)
- Obsessive protagonist-targeting while ignoring better targets
- Support units that don't support
- Enemies that underutilize abilities (no items, no status spells)

**What Fans Love:**
- Aggressive, proactive enemies that force engagement
- Smart targeting (wounded units, vulnerable classes)
- Full ability usage (spells, items, status effects)
- Tactical variety (different enemy types behaving distinctly)

**What Fans Want But Haven't Seen:**
- Strategic retreat and regrouping
- Context-aware support AI
- Dynamic threat assessment (not hardcoded priorities)
- Difficulty via intelligence, not stat inflation
- Unpredictable tactics without random stupidity

**The Opportunity:**
The Sparkling Farce can differentiate itself by implementing AI features the community has wished for but never received in official games. Modders have proven these improvements are valued - SF2 Maeson's comprehensive AI overhaul was celebrated.

**The Standard to Beat:**
- **Minimum Acceptable:** Shining Force 2's aggressive movement + smart heal AI
- **Community Expectation:** SF2 + full ability usage + better targeting
- **Platform Differentiator:** All of the above + strategic retreat + role-based behaviors

If we achieve the "Platform Differentiator" tier, The Sparkling Farce will earn genuine respect from the fandom. If we fall to "Minimum Acceptable," we'll be seen as competent but unambitious.

---

## SOURCES

- [Sometimes the AI in this game - Shining Force Central](https://forums.shiningforcecentral.com/viewtopic.php?p=808310&sid=91ef79653a40e1e90a401059f9b97edf)
- [Enemy AI Behavior and Flag Definition - Shining Force Central](https://forums.shiningforcecentral.com/viewtopic.php?p=727738&sid=404e6612261332855b989db9c921ba88)
- [Enemy AI Research - Shining Force Central](https://forums.shiningforcecentral.com/viewtopic.php?t=16909)
- [Aggressive Enemy AI - Shining Force Central](https://forums.shiningforcecentral.com/viewtopic.php?t=12023)
- [All Enemy analysis(SF1) - Shining Force Central](https://forums.shiningforcecentral.com/viewtopic.php?t=45752)
- [The Ultimate Shining Force 2 Guide: Tactics, Tips, Tricks & Strategies](https://sf2.shiningforcecentral.com/guide/tactics-strategies/)
- [Shining Force Games Ranked Worst To Best](https://www.thegamer.com/shining-force-games-ranked/)
- [How do the Shining Force games compare to Fire Emblem? - GameFAQs](https://gamefaqs.gamespot.com/boards/563341-shining-force-ii/55151457)
- [Shining Force vs. Fire Emblem - Shining Force Central](https://forums.shiningforcecentral.com/viewtopic.php?t=12839)
- [Remembering Shining Force III, Sega's answer to Fire Emblem](https://www.thesixthaxis.com/2020/08/30/remembering-shining-force-iii-segas-answer-to-fire-emblem/)
- [Return to Editor + AI Improvements - Shining Force Central](https://forums.shiningforcecentral.com/viewtopic.php?p=683515)
- [Shining Force: Resurrection of the Dark Dragon - Wikipedia](https://en.wikipedia.org/wiki/Shining_Force)
- [Shining Force: Resurrection of the Dark Dragon Review - RPGFan](https://www.rpgfan.com/review/shining-force-resurrection-of-the-dark-dragon-3/)
- [Steam Workshop: Shining Force Enhanced Edition](https://steamcommunity.com/sharedfiles/filedetails/?id=871547858)
- [Shining Force Alternate - Shining Force Mods](https://sfmods.com/resources/shining-force-alternate.167/)
- [Romhacking.net - Shining Force II Maeson](https://www.romhacking.net/hacks/3271/)
- [Romhacking.net - Shining Force 2 MOD (NEW STORY)](https://www.romhacking.net/hacks/5773/)
- [Shining Force - Gameplay Improvement Hack](https://www.romhacking.net/hacks/3168/)
- [Shining Force; EXTREME - Shining Force Central](https://forums.shiningforcecentral.com/viewtopic.php?t=47592)
- [Gameplay Mod: Shining Force CL v2.3.0 - Shining Force Central](https://forums.shiningforcecentral.com/viewtopic.php?t=43076)
- [Steam Workshop: Shining Force - Hard Mode & AI Improvements](https://steamcommunity.com/sharedfiles/filedetails/?id=675993095)
- [SF2 first? - Shining Force Central](https://forums.shiningforcecentral.com/viewtopic.php?t=15160)
- [Shining Force strategy guide: general tips - rpg-o-mania](https://www.rpg-o-mania.com/coverage_sf_strategy_tips.php)
- [ArtificialStupidity / Fire Emblem - TV Tropes](https://tvtropes.org/pmwiki/pmwiki.php/ArtificialStupidity/FireEmblem)
- [AI - Fire Emblem Heroes Wiki](https://feheroes.fandom.com/wiki/AI)
- [Retro spotlight: Shining Force - by Marc Normandin](https://retroxp.substack.com/p/retro-spotlight-shining-force)

---

**End Report**

Live long and prosper, Captain. The data indicates our AI system will be a critical differentiator for The Sparkling Farce. The community has shown us exactly what they want - we need only have the discipline to implement it properly.

Lt. Ears, USS Torvalds Communications Officer
**"The needs of the many outweigh the needs of the AI to punch things with its staff."**
