extends SceneTree
func _initialize() -> void:
	var days: Array=preload("res://scripts/campaign_days.gd").build()
	var file:=FileAccess.open("res://docs/campaign/days.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(days,"\t"))
	var document := "# Все 30 дежурств\n\nЭтот список выгружен из campaign_days.gd: задачи и события действительно используются игрой.\n\n"
	for i in days.size():
		var record: Dictionary=days[i]
		document+="## День %02d · %s\n\n%s\n\n" % [i+1,record.title,record.brief]
		for goal in record.goals:
			document+="- "+str(goal.title)+"."
			if not str(goal.story).is_empty():document+=" "+str(goal.story)
			document+="\n"
		document+="\nНочь: "+str(record.night.text)+"\n\nМинимальная длительность ночной сцены: %d сек.\n\n" % int(record.night.seconds)
	file=FileAccess.open("res://docs/campaign/ALL_30_DAYS.md",FileAccess.WRITE)
	file.store_string(document)
	print("CAMPAIGN_PLAN_EXPORTED ",days.size()," days")
	quit()
