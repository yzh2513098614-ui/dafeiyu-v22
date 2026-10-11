extends SceneTree
## Command-line entry point for the existing RefCounted battle suite.
func _initialize()->void:call_deferred("run")
func run()->void:
 var result:Dictionary=load("res://tools/test_battle.gd").new().run(500)
 var failures:Array=result.failures.duplicate()
 for name in result.targeted:
  if not bool(result.targeted[name].get("pass",false)):failures.append(name)
 print("BATTLE_RULES: ",JSON.stringify(result))
 quit(0 if failures.is_empty() else 1)
