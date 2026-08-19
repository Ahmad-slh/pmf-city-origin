extends Node
#-----------------------
# هذا الملف وظيفته فقط تحديد نوع البطاقة:
#إذا البطاقة جيدة → اذهب إلى GoodEffects
#إذا البطاقة سيئة → اذهب إلى BadEffects
#-----------------------
func apply_card_effect(card_data: Dictionary, team_id: int, board = null) -> void:
	var card_type = card_data.get("type", "")
	var effect_name = card_data.get("effect", "NONE")

	if effect_name == "NONE":
		print("لا يوجد تأثير لهذه البطاقة")
		return

	if card_type == "GOOD":
		# تأثير "منع البطاقات الإيجابية": تعرض البطاقة كالمعتاد
		# لكن لا ينفذ تأثيرها طوال مدة العقوبة
		if GameManagerHelper.has_effect(
			team_id,
			GameManagerHelper.EffectType.BLOCK_POSITIVE_CARDS_NEXT_ROUND
		):
			print("الفريق ", team_id, " ممنوع من استخدام البطاقات الإيجابية حاليا")
			return

		GoodEffects.apply(effect_name, team_id, board, card_data)

	elif card_type == "BAD":
		# بطاقات الحماية تلغي مفعول البطاقة السيئة قبل تنفيذها
		if _bad_card_was_ignored(team_id):
			return

		BadEffects.apply(effect_name, team_id, board, card_data)

	else:
		print("نوع البطاقة غير معروف: ", card_type)


# ======================================================
# اسم الدالة: _bad_card_was_ignored
# وظيفتها:
# فحص بطاقات الحماية الثلاث قبل تنفيذ أي بطاقة سيئة.
#
# الترتيب مقصود:
# 1. الحصانة المؤقتة أولا، لأنها لا تستهلك فتحفظ البطاقات الأخرى
# 2. ثم "تجاهل بطاقة سيئة" وهي الأقل قيمة
# 3. وأخيرا "درع الحماية" لأنه يغطي خسارة القطاع أيضا،
#    فلا نستهلكه إلا إذا لم يوجد غيره
# ======================================================
func _bad_card_was_ignored(team_id: int) -> bool:

	# إذا كانت البطاقات المخزنة معطلة فلا يمكن استخدام أي حماية
	if not GoodEffects.can_use_stored_good_cards(team_id):
		return false

	if GameManagerHelper.has_effect(
		team_id,
		GameManagerHelper.EffectType.TEMPORARY_IMMUNITY
	):
		GameManagerHelper.remove_effect(
			team_id,
			GameManagerHelper.EffectType.TEMPORARY_IMMUNITY
		)
		print("الفريق ", team_id, " محصن ضد البطاقات السيئة هذه الجولة")
		return true

	if GameManagerHelper.has_effect(
		team_id,
		GameManagerHelper.EffectType.IGNORE_NEXT_BAD_CARD
	):
		GameManagerHelper.remove_effect(
			team_id,
			GameManagerHelper.EffectType.IGNORE_NEXT_BAD_CARD
		)
		print("الفريق ", team_id, " تجاهل البطاقة السيئة")
		return true

	if GameManagerHelper.has_effect(
		team_id,
		GameManagerHelper.EffectType.IGNORE_FIRST_SECTOR_LOSS_OR_PENALTY
	):
		GameManagerHelper.remove_effect(
			team_id,
			GameManagerHelper.EffectType.IGNORE_FIRST_SECTOR_LOSS_OR_PENALTY
		)
		print("الفريق ", team_id, " استخدم درع الحماية ضد العقوبة")
		return true

	return false
