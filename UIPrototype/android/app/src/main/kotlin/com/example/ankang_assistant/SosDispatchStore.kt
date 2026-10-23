package com.example.ankang_assistant

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

internal object SosDispatchStore {
    private const val PREFERENCES = "sos_dispatch_store_v2"
    private const val ATTEMPTS_KEY = "attempts"
    private const val EVENTS_KEY = "events"
    private const val PARTS_KEY = "parts"
    private const val CONTACTS_KEY = "contacts"

    @Synchronized
    fun contactsState(context: Context, ownerUserId: Long): String {
        if (ownerUserId <= 0) return ""
        return readObject(context, CONTACTS_KEY).optString(ownerUserId.toString(), "")
    }

    @Synchronized
    fun saveContactsState(context: Context, ownerUserId: Long, json: String): Boolean {
        if (ownerUserId <= 0 || json.isBlank()) return false
        val states = readObject(context, CONTACTS_KEY)
        states.put(ownerUserId.toString(), json)
        writeObject(context, CONTACTS_KEY, states)
        return true
    }

    @Synchronized
    fun recordAttempt(
        context: Context,
        ownerUserId: Long,
        clientEventId: String,
        attemptId: String,
        contactId: Long?,
        contactName: String?,
        channel: String,
        status: String,
        errorCode: String? = null
    ) {
        if (ownerUserId <= 0) return
        val attempts = readObject(context, ATTEMPTS_KEY)
        val key = attemptKey(ownerUserId, clientEventId, attemptId)
        val existing = attempts.optJSONObject(key)
        if (existing != null && isTerminal(existing.optString("status")) &&
            rank(status) < rank(existing.optString("status"))
        ) {
            return
        }
        attempts.put(key, JSONObject().apply {
            put("ownerUserId", ownerUserId)
            put("clientEventId", clientEventId)
            put("attemptId", attemptId)
            if (contactId == null) put("contactId", JSONObject.NULL) else put("contactId", contactId)
            if (contactName == null) put("contactName", JSONObject.NULL) else put("contactName", contactName)
            put("channel", channel)
            put("status", status)
            if (errorCode == null) put("errorCode", JSONObject.NULL) else put("errorCode", errorCode)
            put("occurredAtMillis", System.currentTimeMillis())
        })
        val events = readObject(context, EVENTS_KEY)
        events.optJSONObject(eventKey(ownerUserId, clientEventId))
            ?.put("syncPending", true)
        writeObject(context, ATTEMPTS_KEY, attempts)
        writeObject(context, EVENTS_KEY, events)
    }

    @Synchronized
    fun markExecutionState(context: Context, ownerUserId: Long, clientEventId: String, state: String) {
        val events = readObject(context, EVENTS_KEY)
        events.optJSONObject(eventKey(ownerUserId, clientEventId))?.apply {
            put("executionState", state)
            put("updatedAtMillis", System.currentTimeMillis())
        }
        writeObject(context, EVENTS_KEY, events)
    }

    @Synchronized
    fun recordSuccessfulPart(
        context: Context,
        ownerUserId: Long,
        clientEventId: String,
        attemptId: String,
        phase: String,
        partIndex: Int,
        totalParts: Int
    ): Boolean {
        if (ownerUserId <= 0) return false
        val parts = readObject(context, PARTS_KEY)
        val key = "$ownerUserId|$clientEventId|$attemptId|$phase"
        val recorded = parts.optJSONArray(key) ?: JSONArray()
        if ((0 until recorded.length()).none { recorded.optInt(it, -1) == partIndex }) {
            recorded.put(partIndex)
        }
        parts.put(key, recorded)
        writeObject(context, PARTS_KEY, parts)
        return recorded.length() >= totalParts
    }

    @Synchronized
    fun snapshot(
        context: Context,
        ownerUserId: Long,
        clientEventId: String
    ): List<Map<String, Any?>> {
        if (ownerUserId <= 0) return emptyList()
        val attempts = readObject(context, ATTEMPTS_KEY)
        val result = mutableListOf<Map<String, Any?>>()
        val keys = attempts.keys()
        while (keys.hasNext()) {
            val value = attempts.optJSONObject(keys.next()) ?: continue
            if (value.optLong("ownerUserId") != ownerUserId ||
                value.optString("clientEventId") != clientEventId
            ) {
                continue
            }
            result.add(mapOf(
                "ownerUserId" to ownerUserId,
                "clientEventId" to value.optString("clientEventId"),
                "attemptId" to value.optString("attemptId"),
                "contactId" to value.optLongOrNull("contactId"),
                "contactName" to value.optNullableString("contactName"),
                "channel" to value.optString("channel"),
                "status" to value.optString("status"),
                "errorCode" to value.optNullableString("errorCode"),
                "occurredAtMillis" to value.optLong("occurredAtMillis")
            ))
        }
        return result.sortedBy { (it["occurredAtMillis"] as? Long) ?: 0L }
    }

    @Synchronized
    fun saveEvent(context: Context, values: Map<String, Any?>) {
        val ownerUserId = (values["ownerUserId"] as? Number)?.toLong() ?: return
        val clientEventId = values["clientEventId"] as? String ?: return
        if (ownerUserId <= 0 || clientEventId.isBlank()) return
        val events = readObject(context, EVENTS_KEY)
        val key = eventKey(ownerUserId, clientEventId)
        val existing = events.optJSONObject(key) ?: JSONObject()
        values.forEach { (field, value) ->
            existing.put(field, value ?: JSONObject.NULL)
        }
        existing.put("ownerUserId", ownerUserId)
        existing.put("clientEventId", clientEventId)
        existing.put("syncPending", true)
        if (!existing.has("executionState")) existing.put("executionState", "prepared")
        existing.put("updatedAtMillis", System.currentTimeMillis())
        events.put(key, existing)
        trimOldEvents(events, ownerUserId)
        writeObject(context, EVENTS_KEY, events)
    }

    @Synchronized
    fun events(
        context: Context,
        ownerUserId: Long,
        pendingOnly: Boolean
    ): List<Map<String, Any?>> {
        if (ownerUserId <= 0) return emptyList()
        val events = readObject(context, EVENTS_KEY)
        val result = mutableListOf<Map<String, Any?>>()
        val keys = events.keys()
        while (keys.hasNext()) {
            val value = events.optJSONObject(keys.next()) ?: continue
            if (value.optLong("ownerUserId") != ownerUserId) continue
            if (pendingOnly && !value.optBoolean("syncPending", true)) continue
            result.add(mapOf(
                "ownerUserId" to ownerUserId,
                "clientEventId" to value.optString("clientEventId"),
                "triggeredAtMillis" to value.optLong("triggeredAtMillis"),
                "latitude" to value.optDoubleOrNull("latitude"),
                "longitude" to value.optDoubleOrNull("longitude"),
                "accuracyMeters" to value.optDoubleOrNull("accuracyMeters"),
                "locationSource" to value.optString("locationSource", "unavailable"),
                "message" to value.optString("message"),
                "syncPending" to value.optBoolean("syncPending", true),
                "executionState" to value.optString("executionState", "completed"),
                "syncError" to value.optNullableString("syncError"),
                "contactSnapshot" to value.optJSONArray("contactSnapshot")?.let { array ->
                    (0 until array.length()).mapNotNull { index ->
                        array.optJSONObject(index)?.let { item ->
                            item.keys().asSequence().associateWith { key ->
                                if (item.isNull(key)) null else item.opt(key)
                            }
                        }
                    }
                }.orEmpty(),
                "updatedAtMillis" to value.optLong("updatedAtMillis")
            ))
        }
        return result.sortedByDescending { (it["triggeredAtMillis"] as? Long) ?: 0L }
    }

    @Synchronized
    fun markEventSynced(context: Context, ownerUserId: Long, clientEventId: String) {
        if (ownerUserId <= 0) return
        val events = readObject(context, EVENTS_KEY)
        val event = events.optJSONObject(eventKey(ownerUserId, clientEventId)) ?: return
        event.put("syncPending", false)
        event.put("updatedAtMillis", System.currentTimeMillis())
        writeObject(context, EVENTS_KEY, events)
    }

    @Synchronized
    fun deleteEvent(context: Context, ownerUserId: Long, clientEventId: String) {
        if (ownerUserId <= 0) return
        val events = readObject(context, EVENTS_KEY)
        events.remove(eventKey(ownerUserId, clientEventId))
        writeObject(context, EVENTS_KEY, events)

        val attempts = readObject(context, ATTEMPTS_KEY)
        attempts.keys().asSequence().toList().forEach { key ->
            val value = attempts.optJSONObject(key) ?: return@forEach
            if (value.optLong("ownerUserId") == ownerUserId &&
                value.optString("clientEventId") == clientEventId
            ) {
                attempts.remove(key)
            }
        }
        writeObject(context, ATTEMPTS_KEY, attempts)

        val parts = readObject(context, PARTS_KEY)
        val prefix = "$ownerUserId|$clientEventId|"
        parts.keys().asSequence().toList()
            .filter { it.startsWith(prefix) }
            .forEach(parts::remove)
        writeObject(context, PARTS_KEY, parts)
    }

    private fun readObject(context: Context, key: String): JSONObject {
        // Legacy records did not contain an account owner and must never be
        // assigned to whichever user happens to log in after an upgrade.
        context.getSharedPreferences("sos_dispatch_store", Context.MODE_PRIVATE)
            .edit()
            .clear()
            .apply()
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        val encrypted = preferences.getString(key, null) ?: return JSONObject()
        val raw = SosStoreCipher.decrypt(encrypted)
        if (raw == null) {
            preferences.edit().remove(key).apply()
            return JSONObject()
        }
        return try {
            JSONObject(raw)
        } catch (_: RuntimeException) {
            JSONObject()
        }
    }

    private fun writeObject(context: Context, key: String, value: JSONObject) {
        val encrypted = SosStoreCipher.encrypt(value.toString()) ?: return
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .putString(key, encrypted)
            .apply()
    }

    private fun JSONObject.optLongOrNull(key: String): Long? =
        if (isNull(key) || !has(key)) null else optLong(key)

    private fun JSONObject.optNullableString(key: String): String? =
        if (isNull(key) || !has(key)) null else optString(key)

    private fun JSONObject.optDoubleOrNull(key: String): Double? =
        if (isNull(key) || !has(key)) null else optDouble(key)

    private fun trimOldEvents(events: JSONObject, ownerUserId: Long) {
        val owned = events.keys().asSequence().toList().mapNotNull { key ->
            val event = events.optJSONObject(key) ?: return@mapNotNull null
            if (event.optLong("ownerUserId") != ownerUserId) return@mapNotNull null
            Triple(key, event.optLong("triggeredAtMillis"), event.optBoolean("syncPending", true))
        }
        if (owned.size <= 20) return
        owned.filter { !it.third }
            .sortedBy { it.second }
            .take(owned.size - 20)
            .forEach { events.remove(it.first) }
    }

    private fun eventKey(ownerUserId: Long, clientEventId: String) =
        "$ownerUserId|$clientEventId"

    private fun attemptKey(ownerUserId: Long, clientEventId: String, attemptId: String) =
        "$ownerUserId|$clientEventId|$attemptId"

    private fun isTerminal(status: String): Boolean = status in setOf(
        "delivered", "launched", "failed", "skipped_not_sms_capable"
    )

    private fun rank(status: String): Int = when (status) {
        "requested" -> 0
        "sent" -> 1
        else -> 2
    }
}

private object SosStoreCipher {
    private const val KEY_ALIAS = "ankang_sos_dispatch_key_v2"
    private const val KEYSTORE = "AndroidKeyStore"
    private const val TRANSFORMATION = "AES/GCM/NoPadding"

    fun encrypt(value: String): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return null
        return try {
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, secretKey())
            val iv = Base64.encodeToString(cipher.iv, Base64.NO_WRAP)
            val payload = Base64.encodeToString(
                cipher.doFinal(value.toByteArray(Charsets.UTF_8)),
                Base64.NO_WRAP
            )
            "v2:$iv:$payload"
        } catch (_: Exception) {
            null
        }
    }

    fun decrypt(value: String): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M || !value.startsWith("v2:")) {
            return null
        }
        return try {
            val parts = value.split(':', limit = 3)
            if (parts.size != 3) return null
            val cipher = Cipher.getInstance(TRANSFORMATION)
            val iv = Base64.decode(parts[1], Base64.NO_WRAP)
            cipher.init(Cipher.DECRYPT_MODE, secretKey(), GCMParameterSpec(128, iv))
            val clear = cipher.doFinal(Base64.decode(parts[2], Base64.NO_WRAP))
            clear.toString(Charsets.UTF_8)
        } catch (_: Exception) {
            null
        }
    }

    private fun secretKey(): SecretKey {
        val keyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        (keyStore.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE)
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .build()
        )
        return generator.generateKey()
    }
}
