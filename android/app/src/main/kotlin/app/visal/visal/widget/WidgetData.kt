package app.visal.visal.widget

import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import app.visal.visal.MainActivity
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import java.util.Calendar
import kotlin.math.roundToLong

/** Flutter tarafındaki WidgetKeys ile aynı anahtarlar (lib/features/widgets/home_widget_service.dart). */
object WidgetKeys {
    const val STATE = "w_state"
    const val SINCE = "w_since"
    const val PARTNER = "w_partner"
    const val MOOD = "w_mood"
    const val PRIVATE = "w_private"
    const val LOVE_STATUS = "w_love_status"
}

data class WidgetSnapshot(
    val ready: Boolean,
    val signedOut: Boolean,
    val days: Int?,
    val partner: String,
    val mood: String,
    val isPrivate: Boolean,
    val loveStatus: String,
) {
    companion object {
        fun from(prefs: SharedPreferences): WidgetSnapshot {
            val state = prefs.getString(WidgetKeys.STATE, null) ?: "signed_out"
            return WidgetSnapshot(
                ready = state == "ready",
                signedOut = state == "signed_out",
                days = daysTogether(prefs.getString(WidgetKeys.SINCE, null)),
                partner = prefs.getString(WidgetKeys.PARTNER, null).orEmpty(),
                mood = prefs.getString(WidgetKeys.MOOD, null).orEmpty(),
                isPrivate = prefs.getString(WidgetKeys.PRIVATE, null) == "1",
                loveStatus = prefs.getString(WidgetKeys.LOVE_STATUS, null).orEmpty(),
            )
        }

        /** Uygulamadaki daysTogether ile aynı: başlangıç günü de sayılır. */
        fun daysTogether(since: String?, now: Calendar = Calendar.getInstance()): Int? {
            val parts = since?.split("-")?.mapNotNull { it.toIntOrNull() } ?: return null
            if (parts.size != 3) return null
            val start = Calendar.getInstance().apply {
                clear()
                set(parts[0], parts[1] - 1, parts[2])
            }
            val today = Calendar.getInstance().apply {
                clear()
                set(now.get(Calendar.YEAR), now.get(Calendar.MONTH), now.get(Calendar.DAY_OF_MONTH))
            }
            // Yaz saati geçişlerinde 23/25 saatlik günler yuvarlanır.
            val diff = ((today.timeInMillis - start.timeInMillis) / 86_400_000.0).roundToLong()
            return (diff + 1).coerceAtLeast(1).toInt()
        }
    }
}

fun openAppIntent(context: Context) = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)

fun sendLoveIntent(context: Context) =
    HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("visal://love"))
