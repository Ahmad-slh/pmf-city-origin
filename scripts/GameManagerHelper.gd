extends Node


signal effect_added(team_id, effect_type)
signal effect_removed(team_id, effect_type)
signal effects_changed(team_id)
signal effects_show(team_id)

var core_card_effect_data

# أرقام أنواع التأثيرات الأساسية
enum EffectType {
	
	# -----------Good Effects ----------------
	SECOND_CHANCE_BATTLE,
	PROTECT_INVESTED_SECTOR,
	EXTRA_DICE_ROLL,
	CHOOSE_NEXT_DICE_NUMBER,
	CONTROL_OPPONENT_DIRECTION,
	ROLL_TWICE_CHOOSE_BEST,
	CHOOSE_NEXT_STARTING_TEAM,
	DOUBLE_INVESTMENT_LOCK_SECTOR,
	RECOVER_LOST_SECTOR,
	GOOD_BLOCK_INVESTMENT_NEXT_ROUND,
	
	
	# ---------Bad Effects-------------------
	OPPONENT_ANSWERS_FIRST_NEXT_BATTLE, # 1 - الخصم يجيب أولا في المعركة القادمة
	BLOCK_INVESTMENT_NEXT_ROUND,        # 1 - منع الاستثمار في الجولة القادمة
	CANCEL_ONE_INVESTMENT,              # 2 - إلغاء استثمار واحد
	BLOCK_POSITIVE_CARDS_NEXT_ROUND,    # 3 - منع استخدام البطاقات الإيجابية
	SKIP_NEXT_DICE_ROLL,                # 4 - تخطي رمية النرد / الخصم يلعب رميتين
	OPPONENT_ROLLS_TWICE_BEFORE_YOU, #  7 - الفريق المنافس يلعب مرتين متتاليتين
	FREEZE_TEAM_NEXT_ROUND,             # 5 - تجميد الفريق في الجولة القادمة
	#OPPONENT_CONTROLS_YOUR_DIRECTION,   # 6 - الخصم يتحكم باتجاه الحركة	
	EXTRA_TURN,                          # 8 - دور إضافي
	TRANSFER_ONE_OWNED_SECTOR_TO_OPPONENT,  # 12 - التخلي عن قطاع للفريق الثاني		
	BLOCK_ENERGY_INVESTMENT_TWO_ROUNDS, # 13 - منع الاستثمار في قطاع الطاقة لجولتين
	BLOCK_EDUCATION_INVESTMENT_TWO_ROUNDS, #  14  ممنوع الاستثمار في قطاع التعليم لجولتين  
	BLOCK_BATTLE_NEXT_ROUND,            # 16 - منع دخول المعركة القادمةBLOCK_BATTLE_NEXT_ROUND=16,            # 16 - منع دخول المعركة القادمة
	OPPONENT_CONTROLS_YOUR_DIRECTION,  #  10 الفريق الخصم يتحكم بمسار الحركة في الجولة القادمة

	# ------- تأثيرات أضيفت لاحقا -------
	# تضاف في نهاية التعداد حتى لا تتغير أرقام التأثيرات السابقة
	IGNORE_NEXT_BAD_CARD,                   # جيد - تجاهل أول بطاقة سيئة قادمة
	TEMPORARY_IMMUNITY,                     # جيد - حصانة من كل البطاقات السيئة جولة كاملة
	IGNORE_FIRST_SECTOR_LOSS_OR_PENALTY,    # جيد - تجاهل أول خسارة قطاع أو عقوبة
	BLOCK_STORED_POSITIVE_CARDS_NEXT_ROUND  # سيئ - منع استخدام البطاقات الإيجابية المخزنة

}


# تصنيف التأثير: جيد أو سيئ
enum EffectCategory {
	GOOD, # تأثير إيجابي
	BAD   # تأثير سلبي
}

# نخزن فيها أين وقع الحدث، في شارع أم في قطاع، لنستخدمه لاحقا
# في ال BoardBackground
var last_effect_source_type := ""


# أين يتم تنفيذ التأثير داخل اللعبة
enum EffectHandler {
	DICE,        # ينفذ داخل سكربت حجر النرد
	BATTLE,      # ينفذ داخل سكربت المعركة
	MOVEMENT,    # ينفذ داخل سكربت حركة اللاعب
	INVESTMENT,  # ينفذ داخل نظام الاستثمار أو القطاعات
	CARDS,       # ينفذ داخل نظام البطاقات
	TURN_SYSTEM, # ينفذ داخل GameManager أو نظام الأدوار
	SECTOR       # ينفذ داخل نظام القطاعات
}


# متى ينتهي التأثير
enum EffectTriggerType {
	NEXT_BATTLE,        # ينتهي بعد أول معركة
	NEXT_TURN,          # ينتهي بعد الدور أو الجولة القادمة
	OPPONENT_ONE_ROLL,  # ينتهي بعد رمية واحدة من الخصم
	OPPONENT_TWO_ROLLS, # ينتهي بعد رميتين من الخصم
	UNTIL_USED,         # يبقى حتى يتم استخدامه
	PERMANENT           # يبقى حتى نهاية اللعبة
}


var team_effects := {}


var effects_data := {

   #--------------Good Effects -----------------------
 #0 - الخصم يجيب أولا في المعركة القادمة
EffectType.SECOND_CHANCE_BATTLE: {
	"Id":0,
	"type": EffectType.SECOND_CHANCE_BATTLE,
	"category": EffectCategory.GOOD,
	"handler": EffectHandler.BATTLE,
	"trigger_type": EffectTriggerType.NEXT_BATTLE,
	"name": "",
	"description": "ستمنح فرصة أخرى في المعركة القادمة"
},

EffectType.PROTECT_INVESTED_SECTOR: {
	"Id":1,
	"type": EffectType.PROTECT_INVESTED_SECTOR,
	"category": EffectCategory.GOOD,
	"handler": EffectHandler.BATTLE,
	"trigger_type": EffectTriggerType.NEXT_BATTLE,
	"name": "",
	"description": ""
},

EffectType.EXTRA_DICE_ROLL: {
	"Id":4,
	"type": EffectType.EXTRA_DICE_ROLL,
	"category": EffectCategory.GOOD,
	"handler": EffectHandler.BATTLE,
	"trigger_type": EffectTriggerType.NEXT_BATTLE,
	"name": "",
	"description": ""
},

EffectType.CHOOSE_NEXT_DICE_NUMBER: {
	"Id":5,
	"type": EffectType.CHOOSE_NEXT_DICE_NUMBER,
	"category": EffectCategory.GOOD,
	"handler": EffectHandler.BATTLE,
	"trigger_type": EffectTriggerType.NEXT_BATTLE,
	"name": "",
	"description": ""
},

EffectType.CONTROL_OPPONENT_DIRECTION: {
	"Id":6,
	"type": EffectType.CONTROL_OPPONENT_DIRECTION,
	"category": EffectCategory.GOOD,
	"handler": EffectHandler.BATTLE,
	"trigger_type": EffectTriggerType.NEXT_BATTLE,
	"name": "",
	"description": ""
},
EffectType.ROLL_TWICE_CHOOSE_BEST: {
	"Id":9,
	"type": EffectType.ROLL_TWICE_CHOOSE_BEST,
	"category": EffectCategory.GOOD,
	"handler": EffectHandler.BATTLE,
	"trigger_type": EffectTriggerType.NEXT_BATTLE,
	"name": "",
	"description": ""
},
EffectType.CHOOSE_NEXT_STARTING_TEAM: {
	"Id":11,
	"type": EffectType.CHOOSE_NEXT_STARTING_TEAM,
	"category": EffectCategory.GOOD,
	"handler": EffectHandler.BATTLE,
	"trigger_type": EffectTriggerType.NEXT_BATTLE,
	"name": "",
	"description": ""
},
EffectType.DOUBLE_INVESTMENT_LOCK_SECTOR: {
	"Id":12,
	"type": EffectType.DOUBLE_INVESTMENT_LOCK_SECTOR,
	"category": EffectCategory.GOOD,
	"handler": EffectHandler.BATTLE,
	"trigger_type": EffectTriggerType.NEXT_BATTLE,
	"name": "",
	"description": ""
},
EffectType.RECOVER_LOST_SECTOR: {
	"Id":13,
	"type": EffectType.RECOVER_LOST_SECTOR,
	"category": EffectCategory.GOOD,
	"handler": EffectHandler.BATTLE,
	"trigger_type": EffectTriggerType.NEXT_BATTLE,
	"name": "",
	"description": ""
},
EffectType.GOOD_BLOCK_INVESTMENT_NEXT_ROUND: {
	"Id":14,
	"type": EffectType.GOOD_BLOCK_INVESTMENT_NEXT_ROUND,
	"category": EffectCategory.GOOD,
	"handler": EffectHandler.BATTLE,
	"trigger_type": EffectTriggerType.NEXT_BATTLE,
	"name": "",
	"description": ""
},




#   --------------Bad Effects -----------------------
# 0 - الخصم يجيب أولا في المعركة القادمة
EffectType.OPPONENT_ANSWERS_FIRST_NEXT_BATTLE: {
	"Id":110,
	"type": EffectType.OPPONENT_ANSWERS_FIRST_NEXT_BATTLE,
	"category": EffectCategory.BAD,
	"handler": EffectHandler.BATTLE,
	"trigger_type": EffectTriggerType.NEXT_BATTLE,
	"name": "الخصم يجيب أولا",
	"description": "في المعركة القادمة ضد فريقك، يجيب الخصم أولا"
},

# 1 - منع الاستثمار في الجولة القادمة
EffectType.BLOCK_INVESTMENT_NEXT_ROUND: {
	"Id":120,
	"type": EffectType.BLOCK_INVESTMENT_NEXT_ROUND,
	"category": EffectCategory.BAD,
	"handler": EffectHandler.INVESTMENT,
	"trigger_type": EffectTriggerType.NEXT_TURN,
	"name": "منع الاستثمار",
	"description": "لا يستطيع الفريق الاستثمار في الجولة القادمة"
},

# 2 - إلغاء استثمار واحد
EffectType.CANCEL_ONE_INVESTMENT: {
	"Id":130,
	"type": EffectType.CANCEL_ONE_INVESTMENT,
	"category": EffectCategory.BAD,
	"handler": EffectHandler.INVESTMENT,
	"trigger_type": EffectTriggerType.UNTIL_USED,
	"name": "إلغاء استثمار واحد",
	"description": "تم إلغاء استثمار واحد من استثمارات الفريق "
},
# --  التخلي عن قطاع للفريق الثاني -12 
EffectType.TRANSFER_ONE_OWNED_SECTOR_TO_OPPONENT: {
	"Id":220,
	"type": EffectType.TRANSFER_ONE_OWNED_SECTOR_TO_OPPONENT,
	"category": EffectCategory.BAD,
	"handler": EffectHandler.INVESTMENT,
	"trigger_type": EffectTriggerType.UNTIL_USED,
	"name": "التخلي عن قطاع للفريق الثاني",
	"description": "تم إلغاء استثمار واحد من استثمارات الفريق ومنحه للفريق الاخر "
},

# 3 - منع استخدام البطاقات الإيجابية
EffectType.BLOCK_POSITIVE_CARDS_NEXT_ROUND: {
	"Id":160,
	"type": EffectType.BLOCK_POSITIVE_CARDS_NEXT_ROUND,
	"category": EffectCategory.BAD,
	"handler": EffectHandler.CARDS,
	"trigger_type": EffectTriggerType.NEXT_TURN,
	"name": "منع البطاقات الإيجابية",
	"description": "لا يستطيع الفريق استخدام البطاقات الإيجابية في الجولة القادمة"
},

# 4 - تخطي رمية النرد / الخصم يلعب رميتين
EffectType.SKIP_NEXT_DICE_ROLL: {
	"Id":180,
	"type": EffectType.SKIP_NEXT_DICE_ROLL,
	"category": EffectCategory.BAD,
	"handler": EffectHandler.DICE,
	"trigger_type": EffectTriggerType.OPPONENT_TWO_ROLLS,
	"name": "تخطي رمية النرد",
	"description": "لن يستطيع الفريق رمي حجر النرد في دوره القادم"
},


# 7 - تخطي رمية النرد / الخصم يلعب رميتين
EffectType.OPPONENT_ROLLS_TWICE_BEFORE_YOU: {
	"Id":170,
	"type": EffectType.OPPONENT_ROLLS_TWICE_BEFORE_YOU,
	"category": EffectCategory.BAD,
	"handler": EffectHandler.DICE,
	"trigger_type": EffectTriggerType.OPPONENT_TWO_ROLLS,
	"name": "المنافس يلعب مرتين",
	"description": "الفريق المنافس سيحصل على دورين متتاليين قبلكم"
},
# 5 - تجميد الفريق في الجولة القادمة
EffectType.FREEZE_TEAM_NEXT_ROUND: {
	"Id":150,
	"type": EffectType.FREEZE_TEAM_NEXT_ROUND,
	"category": EffectCategory.BAD,
	"handler": EffectHandler.TURN_SYSTEM,
	"trigger_type": EffectTriggerType.NEXT_TURN,
	"name": "تجميد الفريق",
	"description": "يتجمد الفريق ولا يستطيع الحركة في الجولة القادمة"
},

# 6 - الخصم يتحكم باتجاه الحركة
EffectType.OPPONENT_CONTROLS_YOUR_DIRECTION: {
	"Id":200,
	"type": EffectType.OPPONENT_CONTROLS_YOUR_DIRECTION,
	"category": EffectCategory.BAD,
	"handler": EffectHandler.MOVEMENT,
	"trigger_type": EffectTriggerType.UNTIL_USED,
	"name": "الخصم يتحكم بالاتجاه",
	"description": "في الحركة القادمة، يتحكم الخصم باتجاه حركة الفريق"
},

#16 - منع دخول المعركة القادمة
EffectType.BLOCK_BATTLE_NEXT_ROUND: {
	"Id":260,
	"type": EffectType.BLOCK_BATTLE_NEXT_ROUND,
	"category": EffectCategory.BAD,
	"handler": EffectHandler.BATTLE,
	"trigger_type": EffectTriggerType.NEXT_BATTLE,
	"name": "منع المعركة",
	"description": "لا يستطيع الفريق دخول معركة في الجولة القادمة"
},

# 8 - دور إضافي
EffectType.EXTRA_TURN: {
	# لا توجد بطاقة شارع بهذا التأثير، لذلك لا يوجد رقم بطاقة يقابله.
	# الرقم 210 كان يخص بطاقة BLOCK_STORED_POSITIVE_CARDS_NEXT_ROUND،
	# فكان وصف الدور الإضافي يظهر بنص بطاقة أخرى تماما.
	# القيمة -1 تعني: استخدم الوصف العام المكتوب هنا.
	"Id":-1,
	"type": EffectType.EXTRA_TURN,
	"category": EffectCategory.GOOD,
	"handler": EffectHandler.TURN_SYSTEM,
	"trigger_type": EffectTriggerType.UNTIL_USED,
	"name": "دور إضافي",
	"description": "يحصل الفريق على دور إضافي"
},

#13  -ممنوع الاستثمار في قطاع الطاقة
EffectType.BLOCK_ENERGY_INVESTMENT_TWO_ROUNDS: {
	"Id":230,
	"type": EffectType.BLOCK_ENERGY_INVESTMENT_TWO_ROUNDS,
	"category": EffectCategory.BAD,
	"handler": EffectHandler.TURN_SYSTEM,
	"trigger_type": EffectTriggerType.UNTIL_USED,
	"name": "قطاع الطاقة",
	"description": " ممنوع الاستثمار في قطاع الطاقة جولتين متتاليتين"
},

# --------- تأثيرات أضيفت لاحقا -----------------
# "Id" هنا هو رقم البطاقة المقابلة داخل StreetCardsData

# جيد - تجاهل أول بطاقة سيئة في الجولة القادمة
EffectType.IGNORE_NEXT_BAD_CARD: {
	"Id":3,
	"type": EffectType.IGNORE_NEXT_BAD_CARD,
	"category": EffectCategory.GOOD,
	"handler": EffectHandler.CARDS,
	"trigger_type": EffectTriggerType.UNTIL_USED,
	"name": "تجاهل بطاقة سيئة",
	"description": "يمكن تجاهل أول بطاقة حدث سيئة تسحب في الجولة القادمة"
},

# جيد - حصانة كاملة من البطاقات السيئة خلال الجولة القادمة
EffectType.TEMPORARY_IMMUNITY: {
	"Id":8,
	"type": EffectType.TEMPORARY_IMMUNITY,
	"category": EffectCategory.GOOD,
	"handler": EffectHandler.CARDS,
	"trigger_type": EffectTriggerType.NEXT_TURN,
	"name": "حصانة مؤقتة",
	"description": "لا تؤثر أي بطاقة سلبية على الفريق خلال الجولة القادمة"
},

# جيد - تجاهل أول خسارة قطاع أو عقوبة
EffectType.IGNORE_FIRST_SECTOR_LOSS_OR_PENALTY: {
	"Id":10,
	"type": EffectType.IGNORE_FIRST_SECTOR_LOSS_OR_PENALTY,
	"category": EffectCategory.GOOD,
	"handler": EffectHandler.CARDS,
	"trigger_type": EffectTriggerType.UNTIL_USED,
	"name": "درع الحماية",
	"description": "تجاهل أول خسارة قطاع أو عقوبة تفرض على الفريق"
},

# سيئ - منع استخدام البطاقات الإيجابية المخزنة
EffectType.BLOCK_STORED_POSITIVE_CARDS_NEXT_ROUND: {
	"Id":210,
	"type": EffectType.BLOCK_STORED_POSITIVE_CARDS_NEXT_ROUND,
	"category": EffectCategory.BAD,
	"handler": EffectHandler.CARDS,
	"trigger_type": EffectTriggerType.NEXT_TURN,
	"name": "تعطيل البطاقات المخزنة",
	"description": "لا يستطيع الفريق استخدام بطاقاته الإيجابية المخزنة في الجولة القادمة"
},

 # 14 # ممنوع الاسنثمار في قطاع التعليم
EffectType.BLOCK_EDUCATION_INVESTMENT_TWO_ROUNDS: {
	"Id":240,
	"type": EffectType.BLOCK_EDUCATION_INVESTMENT_TWO_ROUNDS,
	"category": EffectCategory.BAD,
	"handler": EffectHandler.TURN_SYSTEM,
	"trigger_type": EffectTriggerType.UNTIL_USED,
	"name": "قطاع التعليم",
	"description": "ممنوع الاستثمار في قطاع التعليم لجولتين"
}
}



func get_effect_type_from_name(effect_name: String):
	match effect_name:
		#	-----------------	 Good Effects----------
		"SECOND_CHANCE_BATTLE":
			return EffectType.SECOND_CHANCE_BATTLE
		
		#	----------- BAD Effects	 ------------
		"OPPONENT_ANSWERS_FIRST_NEXT_BATTLE":
			return EffectType.OPPONENT_ANSWERS_FIRST_NEXT_BATTLE
		"BLOCK_INVESTMENT_NEXT_ROUND":
			return EffectType.BLOCK_INVESTMENT_NEXT_ROUND
		"CANCEL_ONE_INVESTMENT":
			return EffectType.CANCEL_ONE_INVESTMENT
		"BLOCK_POSITIVE_CARDS_NEXT_ROUND":
			return EffectType.BLOCK_POSITIVE_CARDS_NEXT_ROUND
		"SKIP_NEXT_DICE_ROLL":
			return EffectType.SKIP_NEXT_DICE_ROLL
		"FREEZE_TEAM_NEXT_ROUND":
			return EffectType.FREEZE_TEAM_NEXT_ROUND
		"OPPONENT_CONTROLS_YOUR_DIRECTION":
			return EffectType.OPPONENT_CONTROLS_YOUR_DIRECTION
		"BLOCK_BATTLE_NEXT_ROUND":
			return EffectType.BLOCK_BATTLE_NEXT_ROUND
		"EXTRA_TURN":
			return EffectType.EXTRA_TURN
		_:
			return null


# ======================================================
# اسم الدالة: get_card_id_for_effect
# وظيفتها:
# تحويل نوع التأثير إلى رقم البطاقة المقابلة له.
#
# مهم جدا:
# StreetCardsData.get_card_by_effect تبحث برقم البطاقة "id"
# وأرقام البطاقات هي 0..17 للبطاقات الجيدة و 110..270 للسيئة،
# بينما قيم EffectType هي ترتيب داخل التعداد 0..22.
# لذلك تمرير EffectType مباشرة كان يرجع بطاقة لا علاقة لها بالتأثير.
# الحقل "Id" داخل effects_data هو الجسر الصحيح بين الاثنين.
# ======================================================
func get_card_id_for_effect(effect_type: int) -> int:
	if not effects_data.has(effect_type):
		return -1

	return int(effects_data[effect_type].get("Id", -1))


func get_effect_card(effect_type: int) -> Dictionary:
	return StreetCardsData.get_card_by_effect(get_card_id_for_effect(effect_type))


func get_effect_name(effect_type: int) -> String:
	var card = get_effect_card(effect_type)
	var card_name: String = str(card.get("name", ""))

	if card_name == "":
		card_name = str(get_effect_data(effect_type).get("name", ""))

	return card_name


# وصف البطاقة نفسها، بدون أي وصف خاص بفريق معين
func get_effect_card_description(effect_type: int) -> String:
	var card = get_effect_card(effect_type)
	var desc: String = str(card.get("description", ""))

	# بعض التأثيرات لا تقابلها بطاقة، فنستخدم وصفها العام
	if desc == "":
		desc = str(get_effect_data(effect_type).get("description", ""))

	return desc


# ======================================================
# اسم الدالة: get_effect_description
# وظيفتها:
# وصف التأثير كما يعرض لفريق معين.
# إذا كان للفريق وصف تنفيذي مخزن (ما حدث فعليا) نرجعه،
# وإلا نرجع وصف البطاقة.
#
# team_id يمرر من المستدعي، لأن الاعتماد على GameManager.current_team
# كان يعرض تأثيرات الفريق صاحب الدور داخل لوحة الفريق الآخر.
# ======================================================
func get_effect_description(effect_type: int, team_id: int = -1) -> String:
	if team_id < 0:
		team_id = GameManager.current_team

	var effect_desc := get_team_effect_description(team_id, effect_type)

	if effect_desc != "":
		return effect_desc

	return get_effect_card_description(effect_type)


func get_team_effect_description(team_id, effect_id) -> String:
	if not team_effects.has(team_id):
		return ""

	if not team_effects[team_id].has(effect_id):
		return ""

	var effect = team_effects[team_id][effect_id]
	var desc: String = str(effect.get("description", ""))

	return desc


#func get_effect_handler(effect_type: EffectType) -> EffectHandler:
	#return effects_data[effect_type]["handler"]


#func get_effect_trigger_type(effect_type: EffectType) -> EffectTriggerType:
	#return effects_data[effect_type]["trigger_type"]


func is_good_effect(effect_type: int) -> bool:
	if not effects_data.has(effect_type):
		return false
	return effects_data[effect_type]["category"] == EffectCategory.GOOD


func is_bad_effect(effect_type: int) -> bool:
	if not effects_data.has(effect_type):
		return false
	return effects_data[effect_type]["category"] == EffectCategory.BAD


# ======================================================
# اسم الدالة: find_first_effect_of_category
# وظيفتها:
# إرجاع أول تأثير لدى الفريق من تصنيف معين، أو -1 إذا لا يوجد.
#
# البطاقات التي تطلب من اللاعب "اختيار" عقوبة أو مكافأة تستخدم
# هذه الدالة بدل واجهة اختيار، تماما كما تختار
# apply_cancel_investment_effect_if_needed أول قطاع مملوك.
# ======================================================
func find_first_effect_of_category(team_id: int, category: int) -> int:
	if not team_effects.has(team_id):
		return -1

	for effect_type in team_effects[team_id].keys():
		if not effects_data.has(effect_type):
			continue
		if effects_data[effect_type]["category"] == category:
			return effect_type

	return -1


# نقل تأثير من فريق إلى آخر مع الحفاظ على بياناته
func move_effect(from_team: int, to_team: int, effect_type: int) -> bool:
	if not has_effect(from_team, effect_type):
		return false

	var data: Dictionary = get_team_effect_data(from_team, effect_type).duplicate(true)
	remove_effect(from_team, effect_type)
	add_effect(to_team, effect_type, data)
	return true


func setup_effects(team_ids: Array) -> void:
	team_effects.clear()

	for team_id in team_ids:
		team_effects[team_id] = {}



func add_effect(team_id: int, effect_type: int, effect_data: Dictionary = {}) -> void:
	
	# إذا لم يكن للفريق جدول تأثيرات، ننشئ له جدول جديد
	if not team_effects.has(team_id):
		team_effects[team_id] = {}

	# حماية إضافية: إذا كانت بيانات الفريق ليست Dictionary نعيد إنشاءها
	if typeof(team_effects[team_id]) != TYPE_DICTIONARY:
		team_effects[team_id] = {}

	# منع تكرار نفس التأثير على نفس الفريق
	if team_effects[team_id].has(effect_type):
		team_effects[team_id].erase(effect_type)
		print("التأثير موجود مسبقًا للفريق: ", team_id)
		#return

	# إذا لم يتم إرسال بيانات البطاقة، ننشئها فارغة
	if not effect_data.has("card_data"):
		effect_data["card_data"] = {}

	# الوصف التنفيذي للحدث
	# هذا الوصف ليس من البطاقة الأصلية، بل مما حدث فعليًا في اللعبة
	if not effect_data.has("description"):
		effect_data["description"] = ""

# تخزين التأثير داخل جدول الفريق
	team_effects[team_id][effect_type] = effect_data

	# إرسال إشارات لتحديث الواجهة
	effect_added.emit(team_id, effect_type)
	#_refresh_side_cotroll_panels(team_id)
	effects_show.emit(team_id)
	
	# طباعة جدول التأثيرات للفحص
	debug_print_team_effects()		
func has_effect(team_id: int, effect_type: int) -> bool:
	if not team_effects.has(team_id):
		return false

	return team_effects[team_id].has(effect_type)

var old_effects:={}
var temp_old_effects

func remove_effect(team_id: int, effect_type: int) -> void:
	if not team_effects.has(team_id):
		return
	
	#temp_old_effects =  team_effects[team_id][effect_type]["card_data"]["id"]
	#
	#if not old_effects.has(team_id):
		#old_effects[team_id] = {}
	#print(old_effects)	
			
	if team_effects[team_id].has(effect_type):
		#if team_effects[team_id].get(effect_type)==0:
		#if temp_old_effects==3:
			#old_effects[team_id][effect_type]=team_effects[team_id][effect_type]
			#team_effects[team_id].erase(effect_type)
			#return
				
		team_effects[team_id].erase(effect_type)
		#effects_changed.emit(team_id)
		
			# إرسال إشارات لتحديث الواجهة
		#effect_added.emit(team_id, effect_type)
		#effects_show.emit(team_id)
		debug_print_team_effects()
		#print("تم حذف التأثير من الفريق: ", team_id, " التأثير: ", effect_type)


func get_team_effect_data(team_id: int, effect_type: int) -> Dictionary:
	if not has_effect(team_id, effect_type):
		return {}

	return team_effects[team_id][effect_type]

func get_team_id_from_effect(effect_type: int) -> int:
	
	if has_effect(1, effect_type):
		return 1
	if has_effect(2, effect_type):
		return 2
	return -1
	
func set_team_effect_data(team_id: int, effect_type: int, effect_data: Dictionary) -> void:
	if not team_effects.has(team_id):
		team_effects[team_id] = {}

	team_effects[team_id][effect_type] = effect_data
	
func get_effect_data(effect_type: EffectType) -> Dictionary:

	if not effects_data.has(effect_type):
		print("Effect type غير موجود داخل effects_data: ", effect_type)
		return {}

	return effects_data[effect_type]
	


func get_team_effects_text(team_id: int) -> String:
	if not team_effects.has(team_id):
		return "لا يوجد حدث حاليا"

	if team_effects[team_id].is_empty():
		return "لا يوجد حدث حاليا"

	var text := ""
	
	#var card = StreetCardsData.get_card_by_effect("SECOND_CHANCE_BATTLE")
	#print(card.get("description", ""))

	for effect_type in team_effects[team_id]:
		# السطر الأول: وصف البطاقة نفسها
		var card_desc := get_effect_card_description(effect_type)

		# السطر الثاني: ما حدث فعليا لهذا الفريق، وإلا الوصف العام للتأثير
		# نمرر team_id حتى لا نقرأ تأثيرات الفريق الآخر
		var live_desc := get_team_effect_description(team_id, effect_type)
		if live_desc == "":
			live_desc = str(get_effect_data(effect_type).get("description", ""))

		text += "• " + card_desc + "\n"

		# لا نكرر نفس الجملة مرتين إذا تطابق وصف البطاقة مع الوصف العام
		if live_desc != "" and live_desc != card_desc:
			text += live_desc + "\n"

		text += "\n"

	return text
func debug_print_team_effects() -> void:
	print("\n========== TEAM EFFECTS TABLE ==========")

	if team_effects.is_empty():
		print("لا يوجد أي تأثيرات")
		print("========================================\n")
		return

	#print("TEAM_ID | EFFECT_ID | EFFECT_NAME | DATA")
	#print("----------------------------------------")
	
	#print("=================")
	#print("* ",team_effects)
	#print("=================")
	for team_id in team_effects.keys():
		#print("team id=", team_id)
		for effect_type in team_effects[team_id].keys():
			
			#print("effect_type=", effect_type)
			var effect_info = get_effect_data(effect_type)
			var effect_name = effect_info.get("name", "Unknown")
			var effect_data = team_effects[team_id][effect_type]
			var card_data = effect_data.get("card_data")
			# card_data قد تكون فارغة أو null، فلا نقرأ منها مباشرة
			var TypeId = card_data.get("id", -1) if typeof(card_data) == TYPE_DICTIONARY else -1
			# الوصف يطلب بنوع التأثير وبرقم الفريق، وليس برقم البطاقة
			var description = get_effect_description(effect_type, team_id)
			var team_effect_desc = get_team_effect_description(team_id,effect_type)
			
			#print("* description=",description)
			#print("** description=",effect_data.get("description"))
			#print("*** team_effect_desc=",team_effect_desc)
			#print("**** effect_data=",effect_data)

			print(
				team_id, " | ",
				effect_type, " | ",
				TypeId, " | ",
				effect_name, " | ",
				description
			)

#---------------------

# ======================================================
# اسم الدالة: reduce_temporary_effects
# وظيفتها:
# إنقاص عداد الجولات لتأثيرات فريق واحد فقط: الفريق الذي بدأ دوره.
#
# سابقا كانت تنقص العداد للفريقين معا في كل تبديل دور، فكان كل تأثير
# يفقد نقطتين في الجولة الواحدة وينتهي في نصف المدة المكتوبة على البطاقة:
#   - تأثير "جولتين متتاليتين" كان يستمر جولة واحدة فقط
#   - تأثير "الجولة القادمة" بقيمة 2 كان ينتهي قبل أن يبدأ مفعوله أصلا
#
# المعنى الآن:
# display_turns_left = عدد أدوار هذا الفريق قبل أن ينتهي التأثير
#   1 = ينتهي عند بداية دور الفريق القادم
#   2 = يبقى فعالا خلال دور الفريق القادم
#   3 = يبقى فعالا خلال دورين قادمين
# ======================================================
func reduce_temporary_effects(team_id: int) -> void:

	if not team_effects.has(team_id):
		return

	# keys() ترجع نسخة، لذلك الحذف أثناء المرور آمن
	for effect_type in team_effects[team_id].keys():
		var effect_data: Dictionary = team_effects[team_id][effect_type]

		if not effect_data.has("display_turns_left"):
			continue

		effect_data["display_turns_left"] -= 1

		if effect_data["display_turns_left"] <= 0:
			team_effects[team_id].erase(effect_type)

func _refresh_side_cotroll_panels(p_team_id:int)->void:
	# إرسال إشارات لتحديث الواجهة
	effects_show.emit(p_team_id)

# ======================================================
# اسم الدالة: set_effect_display_turns
# وظيفتها:
# تغيير عدد الجولات المعروض لتأثير معين
# ======================================================
func set_effect_display_turns(team_id: int, effect_type: int, turns: int) -> void:

	if not has_effect(team_id, effect_type):
		return

	team_effects[team_id][effect_type]["display_turns_left"] = turns

	effects_changed.emit(team_id)	
