# Asset-free regression for the original debug routine's adjacent-dead-seat bug.
extends SceneTree

class Seat extends Node:
	var socket_number: int
	var health_current: int

func _initialize():
	var driver = load(OS.get_cmdline_user_args()[0])
	var players := []
	for pair in [[2, 1], [3, 0], [1, 0], [0, 1]]:
		var seat := Seat.new()
		seat.socket_number = pair[0]; seat.health_current = pair[1]
		players.append(seat)
	var alive: Array = driver._live_targets(players)
	if alive.map(func(p): return p.socket_number) != [2, 0] or players.size() != 4:
		printerr("Adjacent dead seats were selected or the source list was changed"); quit(1); return
	players[0].health_current = 0
	if driver._live_targets(players).map(func(p): return p.socket_number) != [0]:
		printerr("A newly dead seat remained eligible"); quit(1); return
	players[3].health_current = 0
	if not driver._live_targets(players).is_empty():
		printerr("All-dead table has an eligible target"); quit(1); return
	for player in players: player.free()
	if not driver._live_targets(players).is_empty():
		printerr("A freed seat remained eligible"); quit(1); return
	print("PASS local targets: adjacent dead, changed health, all-dead and freed seats; source unchanged")
	quit()
