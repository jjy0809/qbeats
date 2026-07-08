package com.dz.metronome

import android.app.NotificationManager
import android.content.Context

object DnSp {
  private const val f = "dnd"
  private const val kOwn = "own"
  private const val kFlt = "flt"
  private const val kCat = "cat"
  private const val kCal = "cal"
  private const val kMsg = "msg"
  private const val kSup = "sup"
  private const val kCon = "con"

  fun put(
    ctx: Context,
    own: Boolean? = null,
    flt: Int? = null,
    cat: Int? = null,
    cal: Int? = null,
    msg: Int? = null,
    sup: Int? = null,
    con: Int? = null,
  ) {
    val ed = ctx.getSharedPreferences(f, Context.MODE_PRIVATE).edit()
    if (own != null) ed.putBoolean(kOwn, own)
    if (flt != null) ed.putInt(kFlt, flt)
    if (cat != null) ed.putInt(kCat, cat)
    if (cal != null) ed.putInt(kCal, cal)
    if (msg != null) ed.putInt(kMsg, msg)
    if (sup != null) ed.putInt(kSup, sup)
    if (con != null) ed.putInt(kCon, con)
    ed.apply()
  }

  fun own(ctx: Context): Boolean {
    return ctx.getSharedPreferences(f, Context.MODE_PRIVATE)
      .getBoolean(kOwn, false)
  }

  fun flt(ctx: Context): Int {
    return ctx.getSharedPreferences(f, Context.MODE_PRIVATE)
      .getInt(kFlt, NotificationManager.INTERRUPTION_FILTER_ALL)
  }

  fun cat(ctx: Context): Int {
    return ctx.getSharedPreferences(f, Context.MODE_PRIVATE).getInt(kCat, 0)
  }

  fun cal(ctx: Context): Int {
    return ctx.getSharedPreferences(f, Context.MODE_PRIVATE)
      .getInt(kCal, NotificationManager.Policy.PRIORITY_SENDERS_ANY)
  }

  fun msg(ctx: Context): Int {
    return ctx.getSharedPreferences(f, Context.MODE_PRIVATE)
      .getInt(kMsg, NotificationManager.Policy.PRIORITY_SENDERS_ANY)
  }

  fun sup(ctx: Context): Int {
    return ctx.getSharedPreferences(f, Context.MODE_PRIVATE).getInt(kSup, 0)
  }

  fun con(ctx: Context): Int {
    return ctx.getSharedPreferences(f, Context.MODE_PRIVATE)
      .getInt(kCon, NotificationManager.Policy.CONVERSATION_SENDERS_ANYONE)
  }
}
