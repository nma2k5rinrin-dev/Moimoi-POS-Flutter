package com.moimoi.moimoi_pos

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class ThuChiWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val income = widgetData.getString("income", "0")
            val expense = widgetData.getString("expense", "0")
            val balance = widgetData.getString("balance", "+0")
            val isHidden = widgetData.getBoolean("hide_widget_data", false)

            val views = RemoteViews(context.packageName, R.layout.thu_chi_widget).apply {
                if (isHidden) {
                    setTextViewText(R.id.tv_income, "***")
                    setTextViewText(R.id.tv_expense, "***")
                    setTextViewText(R.id.tv_balance, "*** VNĐ")
                    setTextColor(R.id.tv_balance, android.graphics.Color.parseColor("#64748B"))
                } else {
                    setTextViewText(R.id.tv_income, income)
                    setTextViewText(R.id.tv_expense, expense)
                    setTextViewText(R.id.tv_balance, "$balance VNĐ")
                    
                    if (balance != null && balance.startsWith("-")) {
                        setTextColor(R.id.tv_balance, android.graphics.Color.parseColor("#DC2626"))
                    } else {
                        setTextColor(R.id.tv_balance, android.graphics.Color.parseColor("#059669"))
                    }
                }

                // Add click listener to open the app Cashflow page
                val pendingIntent = es.antonborri.home_widget.HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    android.net.Uri.parse("moimoi://cashflow")
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
