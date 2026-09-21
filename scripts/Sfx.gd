extends Node

# ======================================================
# Sfx — ناقل المؤثرات الصوتية (Autoload)
# ------------------------------------------------------
# مشغّل AudioStreamPlayer واحد لكل صوت، محمّل مسبقًا عند
# الإقلاع، حتى لا يحدث تقطيع عند أول تشغيل للصوت.
#
# الاستخدام:
#   Sfx.play(Sfx.Sound.DICE_ROLL)
#   Sfx.stop(Sfx.Sound.DICE_ROLL)
#
# ملاحظة تصدير الويب: لا يوجد أي استخدام للخيوط (Threads)
# هنا، فالتحميل المسبق يتم عبر preload وقت التصريف.
# ======================================================

enum Sound {
	DICE_ROLL,       # صوت رمي حجر النرد
	TOKEN_SETTLE,    # صوت استقرار حنظلة على القطاع أو الشارع
	ANSWER_CORRECT,  # صوت الإجابة الصحيحة
	ANSWER_WRONG,    # صوت الإجابة الخاطئة
	BATTLE_START,    # صوت المعركة
	SECTOR_WIN,      # صوت فوز القطاع
	SECTOR_LOSE,     # صوت خسارة القطاع
	EVENT_GOOD,      # صوت حدث جيد
	EVENT_BAD,       # صوت حدث سيئ
	STREET_CRACK,    # صوت لما ينشق الشارع
	GAME_ENTER,      # صوت الدخول للعبة
	FINAL_WIN,       # صوت الفوز النهائي
}

const STREAMS := {
	Sound.DICE_ROLL:      preload("res://assets/audio/sound effects/صوت رمي حجر النرد.wav"),
	Sound.TOKEN_SETTLE:   preload("res://assets/audio/sound effects/صوت استقرار حنظلة على القطاع أو الشارع.wav"),
	Sound.ANSWER_CORRECT: preload("res://assets/audio/sound effects/صوت الإجابة الصحيحة.mp3"),
	Sound.ANSWER_WRONG:   preload("res://assets/audio/sound effects/صوت الإجابة الخاطئة.mp3"),
	Sound.BATTLE_START:   preload("res://assets/audio/battle_start.wav"),
	Sound.SECTOR_WIN:     preload("res://assets/audio/sound effects/صوت فوز القطاع.wav"),
	Sound.SECTOR_LOSE:    preload("res://assets/audio/sound effects/صوت خسارة القطاع.wav"),
	Sound.EVENT_GOOD:     preload("res://assets/audio/sound effects/صوت حدث جيد.mp3"),
	Sound.EVENT_BAD:      preload("res://assets/audio/sound effects/صوت حدث سيئ.mp3"),
	Sound.STREET_CRACK:   preload("res://assets/audio/sound effects/صوت لما ينشق الشارع.mp3"),
	Sound.GAME_ENTER:     preload("res://assets/audio/sound effects/صوت الدخول للعبة.mp3"),
	Sound.FINAL_WIN:      preload("res://assets/audio/sound effects/صوت الفوز النهائي.mp3"),
}

var _players := {}


func _ready() -> void:
	for sound_id in STREAMS:
		var player := AudioStreamPlayer.new()
		player.stream = STREAMS[sound_id]
		player.name = "SfxPlayer_%d" % sound_id
		add_child(player)
		_players[sound_id] = player


# تشغيل الصوت من بدايته. إعادة الاستدعاء تقطع التشغيل السابق
# لنفس الصوت بدل أن تتراكب نسختان منه
func play(sound_id: int) -> void:
	var player: AudioStreamPlayer = _players.get(sound_id)
	if player == null:
		push_warning("Sfx.play: صوت غير معروف %d" % sound_id)
		return
	player.stop()
	player.play()


# إيقاف الصوت فورًا — يستخدم لقص الأصوات الطويلة عند انتهاء
# الحركة المرتبطة بها (مثل صوت النرد عند استقراره)
func stop(sound_id: int) -> void:
	var player: AudioStreamPlayer = _players.get(sound_id)
	if player == null:
		return
	player.stop()


func is_playing(sound_id: int) -> bool:
	var player: AudioStreamPlayer = _players.get(sound_id)
	if player == null:
		return false
	return player.playing


func stop_all() -> void:
	for sound_id in _players:
		_players[sound_id].stop()
