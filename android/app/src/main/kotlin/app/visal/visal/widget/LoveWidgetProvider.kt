package app.visal.visal.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import app.visal.visal.R
import es.antonborri.home_widget.HomeWidgetProvider

/** ❤️ Aşk dokunuşu: uygulamayı açmadan partnere "seni düşünüyor" gönderir. */
class LoveWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val s = WidgetSnapshot.from(widgetData)
        val caption = when {
            !s.ready -> context.getString(if (s.signedOut) R.string.widget_sign_in else R.string.widget_pair_first)
            s.loveStatus.isNotBlank() -> s.loveStatus
            s.isPrivate || s.partner.isBlank() -> context.getString(R.string.widget_love_tap)
            else -> context.getString(R.string.widget_love_to, s.partner)
        }
        // Hazır değilse dokunmak uygulamayı açar (giriş/eşleşme için).
        val action = if (s.ready) sendLoveIntent(context) else openAppIntent(context)
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_love).apply {
                setTextViewText(R.id.love_caption, caption)
                setOnClickPendingIntent(R.id.widget_root, action)
                setOnClickPendingIntent(R.id.love_heart, action)
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
