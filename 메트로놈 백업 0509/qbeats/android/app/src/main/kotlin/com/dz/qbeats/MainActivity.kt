package com.dz.qbeats

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private var dnRes: MethodChannel.Result? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      "metronome/vibe",
    ).setMethodCallHandler { call, res ->
      when (call.method) {
        "pulse" -> {
          val ms = (call.argument<Int>("ms") ?: 18).coerceIn(1, 120)
          val amp = (call.argument<Int>("amp") ?: 110).coerceIn(1, 255)
          pulse(ms, amp)
          res.success(null)
        }

        else -> res.notImplemented()
      }
    }
    MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      "metronome/dnd",
    ).setMethodCallHandler { call, res ->
      when (call.method) {
        "sync" -> {
          syncDn(
            on = call.argument<Boolean>("on") == true,
            play = call.argument<Boolean>("play") == true,
          )
          res.success(null)
        }

        "state" -> {
          res.success(
            mapOf(
              "sup" to isDnSup(),
              "acc" to hasDnAcc(),
              "own" to DnSp.own(this),
              "flt" to curFlt(),
            ),
          )
        }

        "req" -> reqDn(res)
        else -> res.notImplemented()
      }
    }
  }

  override fun onActivityResult(req: Int, code: Int, data: Intent?) {
    super.onActivityResult(req, code, data)
    if (req != 4201) return
    doneDn(hasDnAcc())
  }

  override fun onDestroy() {
    if (isFinishing && !isChangingConfigurations) {
      offDn()
    }
    super.onDestroy()
  }

  private fun reqDn(res: MethodChannel.Result) {
    if (!isDnSup()) {
      res.error("unsupported", null, null)
      return
    }
    if (dnRes != null) {
      res.error("busy", null, null)
      return
    }
    if (hasDnAcc()) {
      res.success(true)
      return
    }
    dnRes = res
    startActivityForResult(
      Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS),
      4201,
    )
  }

  private fun doneDn(ok: Boolean) {
    val res = dnRes ?: return
    dnRes = null
    if (ok) {
      res.success(true)
      return
    }
    res.error("denied", null, null)
  }

  private fun syncDn(on: Boolean, play: Boolean) {
    if (!isDnSup()) return
    if (on && play) {
      onDn()
      return
    }
    offDn()
  }

  private fun onDn() {
    if (!hasDnAcc()) return
    if (DnSp.own(this)) return
    val nm = loadNm() ?: return
    val pol = nm.notificationPolicy
    DnSp.put(
      this,
      own = true,
      flt = normFlt(nm.currentInterruptionFilter),
      cat = pol.priorityCategories,
      cal = pol.priorityCallSenders,
      msg = pol.priorityMessageSenders,
      sup = loadSup(pol),
      con = loadCon(pol),
    )
    val cat = NotificationManager.Policy.PRIORITY_CATEGORY_MEDIA
    val nxt = when {
      Build.VERSION.SDK_INT >= Build.VERSION_CODES.R ->
        NotificationManager.Policy(
          cat,
          NotificationManager.Policy.PRIORITY_SENDERS_ANY,
          NotificationManager.Policy.PRIORITY_SENDERS_ANY,
          0,
          NotificationManager.Policy.CONVERSATION_SENDERS_NONE,
        )
      Build.VERSION.SDK_INT >= Build.VERSION_CODES.N ->
        NotificationManager.Policy(
          cat,
          NotificationManager.Policy.PRIORITY_SENDERS_ANY,
          NotificationManager.Policy.PRIORITY_SENDERS_ANY,
          0,
        )
      else ->
        NotificationManager.Policy(
          cat,
          NotificationManager.Policy.PRIORITY_SENDERS_ANY,
          NotificationManager.Policy.PRIORITY_SENDERS_ANY,
        )
    }
    try {
      nm.setNotificationPolicy(nxt)
      nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
    } catch (_: Exception) {
      DnSp.put(this, own = false)
    }
  }

  private fun offDn() {
    if (!DnSp.own(this)) return
    if (!hasDnAcc()) {
      DnSp.put(this, own = false)
      return
    }
    val nm = loadNm() ?: run {
      DnSp.put(this, own = false)
      return
    }
    try {
      nm.setNotificationPolicy(loadPol())
      nm.setInterruptionFilter(normFlt(DnSp.flt(this)))
    } catch (_: Exception) {
    } finally {
      DnSp.put(
        this,
        own = false,
        flt = NotificationManager.INTERRUPTION_FILTER_ALL,
      )
    }
  }

  private fun loadNm(): NotificationManager? {
    return getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
  }

  private fun isDnSup(): Boolean {
    return Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
  }

  private fun hasDnAcc(): Boolean {
    if (!isDnSup()) return false
    val nm = loadNm() ?: return false
    return nm.isNotificationPolicyAccessGranted
  }

  private fun curFlt(): Int {
    if (!isDnSup()) return 0
    val nm = loadNm() ?: return 0
    return nm.currentInterruptionFilter
  }

  private fun normFlt(flt: Int): Int {
    return when (flt) {
      NotificationManager.INTERRUPTION_FILTER_ALL,
      NotificationManager.INTERRUPTION_FILTER_PRIORITY,
      NotificationManager.INTERRUPTION_FILTER_NONE,
      NotificationManager.INTERRUPTION_FILTER_ALARMS -> flt
      else -> NotificationManager.INTERRUPTION_FILTER_ALL
    }
  }

  private fun loadPol(): NotificationManager.Policy {
    val cat = DnSp.cat(this)
    val cal = DnSp.cal(this)
    val msg = DnSp.msg(this)
    val sup = DnSp.sup(this)
    return when {
      Build.VERSION.SDK_INT >= Build.VERSION_CODES.R ->
        NotificationManager.Policy(
          cat,
          cal,
          msg,
          sup,
          DnSp.con(this),
        )
      Build.VERSION.SDK_INT >= Build.VERSION_CODES.P ->
        NotificationManager.Policy(
          cat,
          cal,
          msg,
          sup,
        )
      Build.VERSION.SDK_INT >= Build.VERSION_CODES.N ->
        NotificationManager.Policy(
          cat,
          cal,
          msg,
          sup,
        )
      else ->
        NotificationManager.Policy(
          cat,
          cal,
          msg,
        )
    }
  }

  private fun loadSup(pol: NotificationManager.Policy): Int {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
      pol.suppressedVisualEffects
    } else {
      0
    }
  }

  private fun loadCon(pol: NotificationManager.Policy): Int {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
      pol.priorityConversationSenders
    } else {
      NotificationManager.Policy.CONVERSATION_SENDERS_ANYONE
    }
  }

  private fun pulse(ms: Int, amp: Int) {
    val vb = loadVb() ?: return
    if (!vb.hasVibrator()) return
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      vb.vibrate(
        VibrationEffect.createOneShot(
          ms.toLong(),
          amp,
        ),
      )
      return
    }
    @Suppress("DEPRECATION")
    vb.vibrate(ms.toLong())
  }

  private fun loadVb(): Vibrator? {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      val mgr = getSystemService(Context.VIBRATOR_MANAGER_SERVICE)
          as? VibratorManager
      mgr?.defaultVibrator
    } else {
      @Suppress("DEPRECATION")
      getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
    }
  }
}
