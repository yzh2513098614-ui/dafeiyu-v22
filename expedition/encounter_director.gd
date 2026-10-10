extends RefCounted
## Roll once per signal, with visible warning before the player accepts combat.
static func inspect(state, id: String, kind: String) -> String:
	var key: String="event_"+id
	if state.run.known.has(key): return str(state.run.known[key])
	var roll: int=state.rng.randi_range(0,99)
	var empty_cut:=maxi(10,30-int(state.run.trace)/5)
	var output:=kind
	if roll<empty_cut: output="empty"
	elif roll<empty_cut+10: output="resource"
	state.run.known[key]=output
	return output

static func extraction_risk(state, id: String) -> bool:
	var key: String="exit_risk_"+id
	if state.run.known.has(key): return bool(state.run.known[key])
	var threshold:=clampi(int(state.run.trace)-15,0,65)
	var risk: bool=state.rng.randi_range(0,99)<threshold
	state.run.known[key]=risk
	return risk

static func members(state, id: String, kind: String) -> Array:
	var key: String="group_"+id
	if state.run.known.has(key):return state.run.known[key].duplicate()
	var output: Array=[kind]
	# Counts are rolled once when identified, then shown before accepting combat.
	# High Trace changes new encounters; it never adds actors to an ongoing fight.
	if int(state.run.trace)>=25:
		output.append({"guardian":"injector","hallucination":"berserker","berserker":"hallucination","injector":"guardian"}.get(kind,"hallucination"))
	if int(state.run.trace)>=65:output.append("guardian" if kind!="guardian" else "hallucination")
	state.run.known[key]=output.duplicate()
	return output
