class_name Minigame
extends Control

## Shared table shell: bet controls, auto-play, the result line, per-table
## upgrades, and the RTP cap.
##
## ## How returns are capped
##
## A table's declared `base_rtp` is the exact return of its payout table with
## no upgrades. Upgrades add to `rtp_budget()`, and `effective_rtp()` clamps
## base + budget to GameManager.MAX_EFFECTIVE_RTP (0.99).
##
## The extra return is paid as a stake refund on a losing round, sized so that
##
##     base_rtp + loss_probability * refund_chance == effective_rtp
##
## holds exactly. That identity is why every table declares both `base_rtp` and
## the true probability of a zero payout: they are load-bearing constants, not
## documentation, and tools/verify_balance.py re-derives both from the tables.
##
## Nothing else may touch returns. The per-table `solace` upgrade pays EXP on a
## loss precisely so that it sits outside this identity — it used to add refund
## chance on top of the cap, which put every table in the game over 100% RTP.

const AUTO_DELAY := 0.35
const HARD_BET_CAP := 1e15
## Safety net on the refund roll. The binding case is Higher/Lower on its most
## favourable card, where the loss rate drops to 0.154 and the required refund
## reaches 0.455 — anything lower would silently pay less than the displayed
## RTP. BalanceAudit asserts this never binds for any table.
const MAX_REFUND_CHANCE := 0.60
const UI_REFRESH := 0.10

var game_id := "game"
var game_name := "Game"
var game_icon := "chip"
var base_rtp := 0.95
## Short line under the title explaining how the table pays.
var rules_text := ""

var bet: float = 10.0
var last_wager: float = 0.0
var last_fraction: float = 0.0
var busy := false
var auto := false

var board: VBoxContainer
var result_label: Label
var result_icon: TextureRect
var bet_label: Label
var bet_share_label: Label
var play_button: Button
var auto_button: Button
var odds_label: Label

var _upgrade_box: VBoxContainer
var _bet_initialised := false
var _upgrades_dirty := true
var _ui_accum := 0.0


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_shell()
	_build_board(board)
	_sync_bet()
	_refresh_controls()
	GameUpgrades.changed.connect(_mark_upgrades_dirty)
	GameManager.skill_points_changed.connect(func(_p): _mark_upgrades_dirty())


## The chips balance changes every single frame (the floor pays continuously),
## so this used to run a full control refresh 18 times a frame — once per table
## in the tab container, visible or not. Polling on a throttle while visible
## costs a fraction of that and looks identical.
func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_ui_accum += delta
	if _ui_accum < UI_REFRESH:
		return
	_ui_accum = 0.0
	if _upgrades_dirty:
		_refresh_upgrades()
	_sync_bet()
	_refresh_controls()


func _mark_upgrades_dirty() -> void:
	_upgrades_dirty = true


# --- layout ----------------------------------------------------------------

func _build_shell() -> void:
	var root := UIKit.vbox(12)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 16
	root.offset_top = 12
	root.offset_right = -16
	root.offset_bottom = -12
	add_child(root)

	var header := UIKit.hbox(12)
	header.add_child(UIKit.icon(game_icon, 34))
	var title_col := UIKit.vbox(0)
	title_col.add_child(UIKit.title(game_name, 25))
	if not rules_text.is_empty():
		title_col.add_child(UIKit.label(rules_text, 12, UIKit.DIM))
	header.add_child(title_col)
	header.add_child(UIKit.spacer())
	odds_label = UIKit.label("", 13, UIKit.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	header.add_child(odds_label)
	root.add_child(header)
	root.add_child(UIKit.separator())

	var body := UIKit.hbox(16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var left := UIKit.vbox(12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var board_well := UIKit.well(UIKit.PANEL_SUNK, 12)
	board_well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board = UIKit.vbox(10)
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_well.add_child(board)
	left.add_child(board_well)

	var result_panel := UIKit.panel(UIKit.PANEL_HI, 10, 1)
	var result_row := UIKit.hbox(10)
	result_row.alignment = BoxContainer.ALIGNMENT_CENTER
	result_icon = UIKit.icon("", 24)
	result_icon.visible = false
	result_row.add_child(result_icon)
	result_label = UIKit.label("Place your bet.", 19, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_row.add_child(result_label)
	result_panel.add_child(result_row)
	left.add_child(result_panel)

	left.add_child(_build_bet_row())

	var actions := UIKit.hbox(12)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	play_button = UIKit.primary_button("PLAY", 22, UIKit.GOLD)
	play_button.custom_minimum_size = Vector2(210, 56)
	play_button.pressed.connect(_on_play_pressed)
	actions.add_child(play_button)
	auto_button = UIKit.icon_button("clock", "AUTO", 17, UIKit.GREEN)
	auto_button.custom_minimum_size = Vector2(160, 56)
	auto_button.pressed.connect(_on_auto_pressed)
	actions.add_child(auto_button)
	left.add_child(actions)

	body.add_child(left)
	body.add_child(_build_upgrade_panel())
	root.add_child(body)
	_refresh_auto_button()


func _build_upgrade_panel() -> Control:
	var panel := UIKit.panel(UIKit.PANEL, 12, 1)
	panel.custom_minimum_size = Vector2(300, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := UIKit.vbox(8)
	col.add_child(UIKit.icon_row("skill", "Table Upgrades", 16, UIKit.GOLD, 20))
	col.add_child(UIKit.wrapped("Bought with skill points. Reset on prestige.", 11, UIKit.DIM))
	var scroll := UIKit.scroll()
	_upgrade_box = UIKit.vbox(6)
	_upgrade_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_upgrade_box)
	col.add_child(scroll)
	panel.add_child(col)
	return panel


func _refresh_upgrades() -> void:
	_upgrades_dirty = false
	if _upgrade_box == null:
		return
	# queue_free() alone is deferred, so the old rows would still be laid out
	# for the rest of the frame and the panel would visibly jump.
	for child in _upgrade_box.get_children():
		_upgrade_box.remove_child(child)
		child.queue_free()

	for d in GameUpgrades.defs_for(game_id):
		var id := String(d["id"])
		var rank := GameUpgrades.level(game_id, id)
		var max_rank := int(d["max"])
		var owned := rank > 0
		var row := UIKit.panel(UIKit.PANEL_HI if owned else UIKit.PANEL, 8, 1)
		var inner := UIKit.vbox(4)

		var head := UIKit.hbox(6)
		head.add_child(UIKit.icon(String(d["icon"]), 20,
			Color.WHITE if owned else Color(1, 1, 1, 0.45)))
		var title := UIKit.label(String(d["name"]), 13, UIKit.TEXT if owned else UIKit.DIM)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		head.add_child(title)
		head.add_child(UIKit.label("%d/%d" % [rank, max_rank], 12, UIKit.DIM))
		inner.add_child(head)
		inner.add_child(UIKit.label(String(d["effect_label"]), 11, UIKit.CYAN))

		var bar := UIKit.progress_bar(UIKit.GOLD, 4)
		bar.value = float(rank) / float(max_rank)
		inner.add_child(bar)

		var buy: Button
		if GameUpgrades.maxed(game_id, id):
			buy = UIKit.button("MAXED", 12, UIKit.GOLD)
			buy.disabled = true
		else:
			buy = UIKit.button("%d SP" % GameUpgrades.cost(game_id, id), 12, UIKit.GOLD)
			buy.disabled = not GameUpgrades.can_buy(game_id, id)
			buy.pressed.connect(_buy_upgrade.bind(id))
		buy.custom_minimum_size = Vector2(0, 28)
		inner.add_child(buy)

		row.add_child(inner)
		_upgrade_box.add_child(row)


func _buy_upgrade(id: String) -> void:
	if GameUpgrades.buy(game_id, id):
		_mark_upgrades_dirty()
		_refresh_controls()
		_sync_bet()


func _build_bet_row() -> Control:
	var panel := UIKit.panel(UIKit.PANEL, 10, 1)
	var col := UIKit.vbox(6)

	var top := UIKit.hbox(8)
	top.add_child(UIKit.icon("chip", 22))
	bet_label = UIKit.numeral("10", 22, UIKit.GOLD)
	top.add_child(bet_label)
	top.add_child(UIKit.spacer())
	bet_share_label = UIKit.label("", 12, UIKit.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	top.add_child(bet_share_label)
	col.add_child(top)

	var row := UIKit.hbox(6)
	var min_button := UIKit.button("MIN", 14, UIKit.BLUE)
	min_button.custom_minimum_size = Vector2(56, 34)
	min_button.pressed.connect(_min_bet)
	row.add_child(min_button)
	for entry in [["/10", 0.1], ["/2", 0.5], ["x2", 2.0], ["x10", 10.0]]:
		var b := UIKit.button(String(entry[0]), 14)
		b.custom_minimum_size = Vector2(52, 34)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_scale_bet.bind(float(entry[1])))
		row.add_child(b)
	var max_button := UIKit.button("MAX", 14, UIKit.GOLD)
	max_button.custom_minimum_size = Vector2(56, 34)
	max_button.pressed.connect(_max_bet)
	row.add_child(max_button)
	col.add_child(row)

	panel.add_child(col)
	return panel


# --- betting ---------------------------------------------------------------

func max_bet() -> float:
	var soft := maxf(10.0, GameManager.chips * GameManager.max_bet_fraction()
		* GameUpgrades.bet_multiplier(game_id))
	return minf(soft, HARD_BET_CAP)


func _scale_bet(factor: float) -> void:
	bet = clampf(bet * factor, 1.0, maxf(max_bet(), 1.0))
	_sync_bet()
	AudioManager.play_click()


func _max_bet() -> void:
	bet = maxf(floorf(max_bet()), 1.0)
	_sync_bet()
	AudioManager.play_click()


func _min_bet() -> void:
	bet = 1.0
	_sync_bet()
	AudioManager.play_click()


func _sync_bet() -> void:
	var ceiling := maxf(max_bet(), 1.0)
	if not _bet_initialised:
		bet = clampf(10.0, 1.0, ceiling)
		_bet_initialised = true
	bet = clampf(bet, 1.0, ceiling)
	if bet > 1000.0:
		bet = floorf(bet)
	if bet_label != null:
		bet_label.text = Fmt.chips(bet)
	if bet_share_label != null:
		bet_share_label.text = "%s of your %s ceiling" % [
			Fmt.percent(bet / ceiling, 0), Fmt.chips(ceiling)]


func bet_fraction() -> float:
	return clampf(bet / maxf(max_bet(), 1.0), 0.0, 1.0)


func can_afford_bet() -> bool:
	return GameManager.chips >= bet and bet >= 1.0


func _refresh_controls() -> void:
	if play_button != null:
		play_button.disabled = busy or not can_afford_bet()
	if odds_label != null:
		odds_label.text = "Return to player  %s" % Fmt.percent(effective_rtp(), 2)


# --- the RTP identity ------------------------------------------------------

## Every upgrade path that can lift returns, summed before the clamp. Anything
## not in here must not be able to change what a table pays.
func rtp_budget() -> float:
	return GameManager.rtp_bonus() + GameUpgrades.rtp_bonus(game_id)


func effective_rtp() -> float:
	return minf(base_rtp + rtp_budget(), GameManager.MAX_EFFECTIVE_RTP)


func fortune_refund_chance(loss_probability: float) -> float:
	if loss_probability <= 0.0:
		return 0.0
	var deficit := maxf(effective_rtp() - base_rtp, 0.0)
	return clampf(deficit / loss_probability, 0.0, MAX_REFUND_CHANCE)


func _roll_fortune(loss_probability: float) -> bool:
	return randf() < fortune_refund_chance(loss_probability)


# --- round flow ------------------------------------------------------------

func _on_play_pressed() -> void:
	if busy:
		return
	AudioManager.play_click()
	_start_round()


func _start_round() -> void:
	busy = true
	_refresh_controls()
	await play_once()
	busy = false
	_refresh_controls()


func _on_auto_pressed() -> void:
	auto = not auto
	_refresh_auto_button()
	AudioManager.play_click()
	if auto and not busy:
		_run_auto()


func _refresh_auto_button() -> void:
	if auto_button == null:
		return
	auto_button.text = "AUTO ON" if auto else "AUTO"
	auto_button.add_theme_color_override("font_color", UIKit.GREEN if auto else UIKit.TEXT)


func _run_auto() -> void:
	busy = true
	_refresh_controls()
	while auto and is_inside_tree():
		if not can_afford_bet():
			set_result("Not enough chips for that bet.", UIKit.RED, "lock")
			AudioManager.play_error()
			auto = false
			_refresh_auto_button()
			break
		await play_once()
		if not auto or not is_inside_tree():
			break
		await wait(AUTO_DELAY * GameManager.auto_delay_multiplier()
			* GameUpgrades.auto_multiplier(game_id))
	busy = false
	_refresh_controls()


func stop_auto() -> void:
	auto = false
	_refresh_auto_button()


func _exit_tree() -> void:
	auto = false


## Take the stake. Records the bet as a fraction of the table ceiling so EXP
## stays scale-invariant as the numbers inflate.
func wager(amount: float) -> bool:
	var fraction := bet_fraction()
	if not GameManager.spend_chips(amount):
		AudioManager.play_error()
		return false
	last_wager = amount
	last_fraction = fraction
	GameManager.record_wager(game_id, amount, fraction)
	if not auto or Settings.auto_spin_sfx:
		AudioManager.play_spin()
	return true


## Settle a round. `loss_probability` must be the true probability that this
## table pays nothing, or the refund is mis-sized and the declared RTP is a lie.
func finish_round(payout: float, loss_probability: float, is_jackpot: bool = false) -> float:
	var credited := payout
	var refunded := false
	if payout <= 0.0 and _roll_fortune(loss_probability):
		credited = last_wager
		refunded = true
	if credited > 0.0:
		GameManager.add_chips(credited, not refunded)
	GameManager.record_result(payout, last_wager, is_jackpot)

	if payout <= 0.0:
		GameManager.record_loss_solace(game_id, last_fraction)

	if refunded:
		set_result("Close one - stake refunded.", UIKit.BLUE, "check")
		FX.float_text(self, "REFUND", UIKit.BLUE, size * 0.5, 24)
		if not auto or Settings.auto_spin_sfx:
			AudioManager.play_refund()
	elif payout > 0.0 and last_wager > 0.0:
		if not auto or Settings.auto_spin_sfx:
			AudioManager.play_win(payout / last_wager)
	return credited


## Settle a tie that returns the stake.
##
## A push is not a loss, so it must not roll for a refund — the old code called
## finish_round(0, ...) on a push *and* handed the stake back, which paid the
## player twice and is part of why several tables sat above 100% RTP. A push
## also leaves a win streak intact rather than breaking it.
func settle_push(message: String = "Push - stake returned.") -> void:
	GameManager.add_chips(last_wager, false)
	set_result(message, UIKit.BLUE, "check")
	if not auto or Settings.auto_spin_sfx:
		AudioManager.play_refund()


func wait(seconds: float) -> void:
	if not is_inside_tree():
		return
	var scaled := maxf(seconds * GameManager.speed_multiplier()
		* GameUpgrades.speed_multiplier(game_id), 0.01)
	if Settings.fast_animations:
		scaled = minf(scaled, 0.02)
	await get_tree().create_timer(scaled).timeout


func set_result(text: String, color: Color = UIKit.TEXT, icon: String = "") -> void:
	if result_label == null:
		return
	result_label.text = text
	result_label.add_theme_color_override("font_color", color)
	if result_icon != null:
		result_icon.texture = Icons.tex(icon)
		result_icon.visible = not icon.is_empty()


func celebrate(amount: float, multiplier: float) -> void:
	if not Settings.show_float_text:
		return
	var color := UIKit.tier_color(multiplier)
	var prefix := "+"
	if multiplier >= 50.0:
		prefix = "BIG WIN  +"
		if Settings.screen_shake:
			FX.shake(self, 10.0)
	FX.float_text(self, prefix + Fmt.chips(amount), color, size * Vector2(0.5, 0.42), 32)


static func weighted_pick(entries: Array, rng: RandomNumberGenerator = null) -> Variant:
	var total := 0.0
	for e in entries:
		total += float(e[1])
	var roll := (rng.randf() if rng != null else randf()) * total
	for e in entries:
		roll -= float(e[1])
		if roll <= 0.0:
			return e[0]
	return entries[entries.size() - 1][0]


# --- overridden per table --------------------------------------------------

func _build_board(_container: VBoxContainer) -> void:
	pass


func play_once() -> void:
	pass
