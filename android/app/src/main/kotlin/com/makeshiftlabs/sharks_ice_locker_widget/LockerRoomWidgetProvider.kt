package com.makeshiftlabs.sharks_ice_locker_widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class LockerRoomWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.locker_room_widget).apply {
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.widget_root_container, pendingIntent)

                val primaryLr = widgetData.getString("primary_locker_room", "—") ?: "—"
                val headline = widgetData.getString("headline_text", "No Games Today") ?: "No Games Today"
                val gameTime = widgetData.getString("game_time_badge", "") ?: ""
                val jerseyBadge = widgetData.getString("jersey_badge", "") ?: ""
                val isHomeGame = widgetData.getBoolean("is_home_game", true)

                setTextViewText(R.id.tv_locker_number, primaryLr)
                setTextViewText(R.id.tv_headline, headline)

                if (gameTime.isNotEmpty()) {
                    setTextViewText(R.id.tv_game_time, gameTime)
                    setViewVisibility(R.id.tv_game_time, View.VISIBLE)
                } else {
                    setViewVisibility(R.id.tv_game_time, View.GONE)
                }

                if (jerseyBadge.isNotEmpty()) {
                    setTextViewText(R.id.tv_jersey_badge, jerseyBadge)
                    val bgColor = if (isHomeGame) 0xFFFFFFFF.toInt() else 0xFF1E293B.toInt()
                    val fgColor = if (isHomeGame) 0xFF0F172A.toInt() else 0xFFFFFFFF.toInt()
                    val jerseyDrawable = if (isHomeGame) R.drawable.ic_jersey else R.drawable.ic_jersey_dark
                    setInt(R.id.jersey_badge_container, "setBackgroundColor", bgColor)
                    setTextColor(R.id.tv_jersey_badge, fgColor)
                    setImageViewResource(R.id.iv_jersey_icon, jerseyDrawable)
                    setViewVisibility(R.id.jersey_badge_container, View.VISIBLE)
                } else {
                    setViewVisibility(R.id.jersey_badge_container, View.GONE)
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
