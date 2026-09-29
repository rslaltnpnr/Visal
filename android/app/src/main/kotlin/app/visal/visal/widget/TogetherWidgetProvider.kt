package app.visal.visal.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import app.visal.visal.R
import es.antonborri.home_widget.HomeWidgetProvider

/** "Birlikte" sayacı: gün sayısı + partnerin adı ve bugünkü ruh hali. */
class TogetherWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val s = WidgetSnapshot.from(widgetData)
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_together).apply {
                setOnClickPendingIntent(R.id.widget_root, openAppIntent(context))
                if (s.ready && s.days != null) {
                    setTextViewText(R.id.together_days, s.days.toString())
                    setTextViewText(R.id.together_label, context.getString(R.string.widget_days_together))
                } else {
                    setTextViewText(R.id.together_days, "♡")
                    setTextViewText(
                        R.id.together_label,
                        context.getString(if (s.signedOut) R.string.widget_sign_in else R.string.widget_pair_first),
                    )
                }
                val partnerLine = listOf(s.partner, s.mood).filter { it.isNotBlank() }.joinToString("  ")
                if (s.ready && !s.isPrivate && partnerLine.isNotBlank()) {
                    setTextViewText(R.id.together_partner, partnerLine)
                    setViewVisibility(R.id.together_partner, View.VISIBLE)
                } else {
                    setViewVisibility(R.id.together_partner, View.GONE)
                }
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
