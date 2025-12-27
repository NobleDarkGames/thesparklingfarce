extends Node
## Test for battle defeat -> CampaignManager transition flow
## Verifies that when hero dies, CampaignManager handles the scene transition
## This test runs WITHOUT scene changes to isolate CampaignManager logic

const CAMPAIGN_ID: String = "sandbox:test_campaign"

func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("DEFEAT FLOW TEST - Testing CampaignManager defeat handling")
	print("=".repeat(60))

	# Enable headless mode
	TurnManager.is_headless = true

	# Wait for autoloads to initialize
	await get_tree().create_timer(0.2).timeout

	await _run_test()


func _run_test() -> void:
	# Step 1: Check campaign is registered
	print("\n[TEST] Step 1: Checking campaign is registered...")
	var campaign: Resource = CampaignManager.get_campaign(CAMPAIGN_ID)
	if not campaign:
		print("[FAIL] Campaign '%s' not found in registry" % CAMPAIGN_ID)
		print("Available campaigns: %s" % CampaignManager._campaigns.keys())
		get_tree().quit(1)
		return

	print("[OK] Campaign found: %s" % campaign.campaign_id)

	# Step 2: Set up campaign state WITHOUT starting (no scene change)
	print("\n[TEST] Step 2: Setting up campaign state manually...")
	CampaignManager.current_campaign = campaign

	# Find the battle node
	var battle_node: CampaignNode = campaign.get_node("battle_of_noobs")
	if not battle_node:
		print("[FAIL] Could not find battle_of_noobs node")
		get_tree().quit(1)
		return

	CampaignManager.current_node = battle_node
	print("[OK] current_campaign set to: %s" % campaign.campaign_id)
	print("[OK] current_node set to: %s (type: %s)" % [battle_node.node_id, battle_node.node_type])

	# Step 3: Check if CampaignManager is managing a battle
	print("\n[TEST] Step 3: Checking is_managing_campaign_battle...")
	var is_managing: bool = CampaignManager.is_managing_campaign_battle()
	print("is_managing_campaign_battle() = %s" % is_managing)

	if not is_managing:
		print("[FAIL] CampaignManager should be managing the battle!")
		get_tree().quit(1)
		return

	print("[OK] CampaignManager is managing the battle")

	# Step 4: Check the on_defeat transition target
	print("\n[TEST] Step 4: Checking on_defeat transition...")
	print("Node on_defeat value: '%s'" % battle_node.on_defeat)
	print("Node on_victory value: '%s'" % battle_node.on_victory)

	# Get the transition target for defeat
	var outcome: Dictionary = {"victory": false}
	var target_id: String = battle_node.get_transition_target(outcome, GameState.has_flag)
	print("Transition target for defeat: '%s'" % target_id)

	if target_id.is_empty():
		print("[FAIL] No transition target found for defeat!")
		get_tree().quit(1)
		return

	print("[OK] Defeat transition target: %s" % target_id)

	# Step 5: Verify the target node exists
	print("\n[TEST] Step 5: Verifying target node exists...")
	var target_node: CampaignNode = campaign.get_node(target_id)
	if not target_node:
		print("[FAIL] Target node '%s' not found in campaign!" % target_id)
		get_tree().quit(1)
		return

	print("[OK] Target node found: %s (type: %s)" % [target_node.node_id, target_node.node_type])

	# Step 6: Summary
	print("\n" + "=".repeat(60))
	print("[PASS] All defeat flow logic tests passed!")
	print("  - CampaignManager correctly identifies it's managing a battle")
	print("  - Battle node has valid on_defeat transition: %s" % target_id)
	print("  - Target node exists in campaign")
	print("=".repeat(60))

	get_tree().quit(0)
