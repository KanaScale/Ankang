package com.example.ankang_assistant

import android.content.Context

internal object ReminderLocalStore {
    private const val PREFERENCES = "reminder_local_repository"

    fun load(context: Context, ownerUserId: Long): String {
        if (ownerUserId <= 0) return ""
        return context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .getString(key(ownerUserId), "")
            .orEmpty()
    }

    fun save(context: Context, ownerUserId: Long, json: String): Boolean {
        if (ownerUserId <= 0 || json.isBlank()) return false
        return context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .putString(key(ownerUserId), json)
            .commit()
    }

    private fun key(ownerUserId: Long) = "owner_$ownerUserId"
}
