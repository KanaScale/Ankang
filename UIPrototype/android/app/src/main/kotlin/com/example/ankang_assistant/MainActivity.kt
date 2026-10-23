package com.example.ankang_assistant

import android.Manifest
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.net.Uri
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.max

class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "ankang_assistant/sos_device"
        const val REMINDER_CHANNEL = "ankang_assistant/reminder_alarm"
        const val PERMISSION_REQUEST_CODE = 4102
        const val REMINDER_PERMISSION_REQUEST_CODE = 4103
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingReminderPermissionResult: MethodChannel.Result? = null
    private var reminderChannel: MethodChannel? = null
    private var pendingReminderLaunch: Map<String, Any?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(::handleMethodCall)
        reminderChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, REMINDER_CHANNEL)
                .also { it.setMethodCallHandler(::handleReminderMethodCall) }
        if (pendingReminderLaunch == null) {
            pendingReminderLaunch = ReminderNotificationLaunch.payload(intent)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val payload = ReminderNotificationLaunch.payload(intent) ?: return
        val channel = reminderChannel
        if (channel == null) {
            pendingReminderLaunch = payload
        } else {
            channel.invokeMethod("reminderOpened", payload)
        }
    }

    override fun onResume() {
        super.onResume()
        reminderChannel?.let(ReminderAlarmForegroundBridge::attach)
    }

    override fun onPause() {
        reminderChannel?.let(ReminderAlarmForegroundBridge::detach)
        super.onPause()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        reminderChannel?.let(ReminderAlarmForegroundBridge::detach)
        reminderChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun handleReminderMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkReadiness" -> result.success(ReminderAlarmScheduler.readiness(this))
            "requestPermission" -> requestReminderPermission(result)
            "openExactAlarmSettings" ->
                result.success(ReminderAlarmScheduler.openExactAlarmSettings(this))
            "getInitialReminderLaunch" -> {
                val payload = pendingReminderLaunch
                    ?: ReminderNotificationLaunch.payload(intent)
                pendingReminderLaunch = null
                if (payload != null) {
                    setIntent(Intent(intent).apply { action = null })
                }
                result.success(payload)
            }
            "schedule" -> {
                val ownerUserId = call.argument<Number>("ownerUserId")?.toLong() ?: 0L
                val reminderId = call.argument<Number>("reminderId")?.toLong() ?: 0L
                val title = call.argument<String>("title").orEmpty()
                val triggerAtMillis = call.argument<Number>("triggerAtMillis")?.toLong() ?: 0L
                val repeatType = call.argument<String>("repeatType") ?: "once"
                ReminderAlarmScheduler.schedule(
                    this,
                    ownerUserId,
                    reminderId,
                    title,
                    triggerAtMillis,
                    repeatType
                )
                result.success(true)
            }
            "cancel" -> {
                ReminderAlarmScheduler.cancel(
                    this,
                    call.argument<Number>("ownerUserId")?.toLong() ?: 0L,
                    call.argument<Number>("reminderId")?.toLong() ?: 0L
                )
                result.success(true)
            }
            "cancelAll" -> {
                ReminderAlarmScheduler.cancelAll(
                    this,
                    call.argument<Number>("ownerUserId")?.toLong() ?: 0L
                )
                result.success(true)
            }
            "loadLocalReminderState" -> {
                val ownerUserId = call.argument<Number>("ownerUserId")?.toLong() ?: 0L
                result.success(ReminderLocalStore.load(this, ownerUserId))
            }
            "saveLocalReminderState" -> {
                val ownerUserId = call.argument<Number>("ownerUserId")?.toLong() ?: 0L
                val json = call.argument<String>("json").orEmpty()
                result.success(ReminderLocalStore.save(this, ownerUserId, json))
            }
            else -> result.notImplemented()
        }
    }

    private fun requestReminderPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(ReminderAlarmScheduler.readiness(this))
            return
        }
        if (pendingReminderPermissionResult != null) {
            result.error("permission_request_in_progress", "通知权限申请正在进行", null)
            return
        }
        pendingReminderPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REMINDER_PERMISSION_REQUEST_CODE
        )
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkReadiness" -> result.success(readinessSnapshot())
            "requestPermissions" -> requestSosPermissions(result)
            "resolveLocation" -> resolveLocation(call, result)
            "openSmsSettings" -> openSmsSettings(result)
            "dispatchSos" -> dispatchSos(call, result)
            "getDispatchSnapshot" -> getDispatchSnapshot(call, result)
            "callEmergencyNumber" -> callEmergencyNumber(call, result)
            "saveLocalSosEvent" -> saveLocalSosEvent(call, result)
            "getLocalSosEvents" -> getLocalSosEvents(call, result)
            "markLocalSosEventSynced" -> markLocalSosEventSynced(call, result)
            "deleteLocalSosEvent" -> deleteLocalSosEvent(call, result)
            "loadLocalContactState" -> result.success(SosDispatchStore.contactsState(this, call.argument<Number>("ownerUserId")?.toLong() ?: 0L))
            "saveLocalContactState" -> result.success(SosDispatchStore.saveContactsState(this, call.argument<Number>("ownerUserId")?.toLong() ?: 0L, call.argument<String>("json").orEmpty()))
            else -> result.notImplemented()
        }
    }

    private fun readinessSnapshot(): Map<String, Any?> {
        val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        val simSnapshot = simSnapshot(telephonyManager)
        val defaultSmsId = defaultSmsSubscriptionId()
        return mapOf(
            "supported" to true,
            "smsPermission" to permissionState(Manifest.permission.SEND_SMS),
            "callPermission" to permissionState(Manifest.permission.CALL_PHONE),
            "locationPermission" to locationPermissionState(),
            "locationServiceEnabled" to isLocationEnabled(locationManager),
            "defaultSmsSubscriptionId" to defaultSmsId,
            "simSlotCount" to simSnapshot.slotCount,
            "activeSimCount" to simSnapshot.activeCount
        )
    }

    private fun simSnapshot(telephonyManager: TelephonyManager): SimSnapshot {
        val slotCount = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            telephonyManager.activeModemCount
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            telephonyManager.phoneCount
        } else {
            1
        }
        var activeSimCount = 0
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            for (slot in 0 until max(1, slotCount)) {
                try {
                    if (telephonyManager.getSimState(slot) == TelephonyManager.SIM_STATE_READY) {
                        activeSimCount++
                    }
                } catch (_: RuntimeException) {
                    // Some vendors restrict per-slot SIM state. The default-SIM value remains usable.
                }
            }
        } else if (telephonyManager.simState == TelephonyManager.SIM_STATE_READY) {
            activeSimCount = 1
        }
        return SimSnapshot(slotCount, activeSimCount)
    }

    private fun defaultSmsSubscriptionId(): Int? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            SubscriptionManager.getDefaultSmsSubscriptionId()
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            @Suppress("DEPRECATION")
            SmsManager.getDefault().subscriptionId
        } else {
            -1
        }.takeUnless { it < 0 }
    }

    private fun permissionState(permission: String): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
        ) {
            return "granted"
        }
        return if (ActivityCompat.shouldShowRequestPermissionRationale(this, permission)) {
            "denied"
        } else {
            "not_granted"
        }
    }

    private fun locationPermissionState(): String {
        val fine = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        return when {
            fine -> "precise"
            coarse -> "approximate"
            else -> permissionState(Manifest.permission.ACCESS_COARSE_LOCATION)
        }
    }

    private fun requestSosPermissions(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            result.success(readinessSnapshot())
            return
        }
        if (pendingPermissionResult != null) {
            result.error("permission_request_in_progress", "权限申请正在进行", null)
            return
        }
        val missing = arrayOf(
            Manifest.permission.SEND_SMS,
            Manifest.permission.CALL_PHONE,
            Manifest.permission.ACCESS_COARSE_LOCATION,
            Manifest.permission.ACCESS_FINE_LOCATION
        ).filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) {
            result.success(readinessSnapshot())
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(this, missing.toTypedArray(), PERMISSION_REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            pendingPermissionResult?.success(readinessSnapshot())
            pendingPermissionResult = null
        } else if (requestCode == REMINDER_PERMISSION_REQUEST_CODE) {
            pendingReminderPermissionResult?.success(ReminderAlarmScheduler.readiness(this))
            pendingReminderPermissionResult = null
        }
    }

    private fun resolveLocation(call: MethodCall, result: MethodChannel.Result) {
        val fineGranted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        val coarseGranted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        if (!fineGranted && !coarseGranted) {
            result.success(unavailableLocation("permission_denied"))
            return
        }

        val timeoutMillis = (call.argument<Number>("timeoutMillis")?.toLong() ?: 5_000L)
            .coerceIn(1_000L, 10_000L)
        val cacheMaxAgeMillis =
            (call.argument<Number>("cacheMaxAgeMillis")?.toLong() ?: 900_000L)
                .coerceAtLeast(0L)
        val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val cached = newestCachedLocation(locationManager, cacheMaxAgeMillis)
        val enabledProviders = listOf(
            LocationManager.GPS_PROVIDER,
            LocationManager.NETWORK_PROVIDER
        ).filter { provider ->
            try {
                locationManager.isProviderEnabled(provider)
            } catch (_: RuntimeException) {
                false
            }
        }
        if (enabledProviders.isEmpty()) {
            result.success(cached?.let { locationMap(it, "cached") }
                ?: unavailableLocation("location_service_disabled"))
            return
        }

        var completed = false
        lateinit var timeout: Runnable
        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                if (completed) return
                completed = true
                mainHandler.removeCallbacks(timeout)
                locationManager.removeUpdates(this)
                result.success(locationMap(location, "fresh"))
            }

            @Deprecated("Deprecated in Android")
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit
            override fun onProviderEnabled(provider: String) = Unit
            override fun onProviderDisabled(provider: String) = Unit
        }
        timeout = Runnable {
            if (completed) return@Runnable
            completed = true
            locationManager.removeUpdates(listener)
            result.success(cached?.let { locationMap(it, "cached") }
                ?: unavailableLocation("location_timeout"))
        }
        try {
            enabledProviders.forEach { provider ->
                locationManager.requestLocationUpdates(provider, 0L, 0f, listener, Looper.getMainLooper())
            }
            mainHandler.postDelayed(timeout, timeoutMillis)
        } catch (_: SecurityException) {
            completed = true
            locationManager.removeUpdates(listener)
            result.success(unavailableLocation("permission_denied"))
        } catch (_: RuntimeException) {
            completed = true
            locationManager.removeUpdates(listener)
            result.success(cached?.let { locationMap(it, "cached") }
                ?: unavailableLocation("location_unavailable"))
        }
    }

    private fun newestCachedLocation(
        locationManager: LocationManager,
        maxAgeMillis: Long
    ): Location? {
        val cutoff = System.currentTimeMillis() - maxAgeMillis
        return listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
            .mapNotNull { provider ->
                try {
                    locationManager.getLastKnownLocation(provider)
                } catch (_: SecurityException) {
                    null
                } catch (_: RuntimeException) {
                    null
                }
            }
            .filter { it.time >= cutoff }
            .maxByOrNull { it.time }
    }

    private fun locationMap(location: Location, source: String): Map<String, Any?> = mapOf(
        "latitude" to location.latitude,
        "longitude" to location.longitude,
        "accuracyMeters" to if (location.hasAccuracy()) location.accuracy.toDouble() else null,
        "source" to source,
        "capturedAtMillis" to location.time,
        "errorCode" to null
    )

    private fun unavailableLocation(errorCode: String): Map<String, Any?> = mapOf(
        "latitude" to null,
        "longitude" to null,
        "accuracyMeters" to null,
        "source" to "unavailable",
        "capturedAtMillis" to null,
        "errorCode" to errorCode
    )

    private fun isLocationEnabled(locationManager: LocationManager): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            locationManager.isLocationEnabled
        } else {
            runCatching {
                locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                    locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
            }.getOrDefault(false)
        }
    }

    private fun openSmsSettings(result: MethodChannel.Result) {
        try {
            startActivity(Intent(Settings.ACTION_WIRELESS_SETTINGS))
            result.success(true)
        } catch (error: RuntimeException) {
            result.error("settings_unavailable", "无法打开系统设置", error.message)
        }
    }

    private fun dispatchSos(call: MethodCall, result: MethodChannel.Result) {
        val ownerUserId = call.argument<Number>("ownerUserId")?.toLong() ?: 0L
        val clientEventId = call.argument<String>("clientEventId")?.trim().orEmpty()
        val message = call.argument<String>("message").orEmpty()
        val contacts = call.argument<List<Map<String, Any?>>>("contacts").orEmpty()
        if (ownerUserId <= 0 || clientEventId.isBlank() || message.isBlank()) {
            result.error("invalid_dispatch", "SOS 事件编号和短信内容不能为空", null)
            return
        }
        call.argument<Map<String, Any?>>("event")?.let { SosDispatchStore.saveEvent(this, it) }
        SosDispatchStore.markExecutionState(this, ownerUserId, clientEventId, "dispatching")

        val smsPermissionGranted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.SEND_SMS
        ) == PackageManager.PERMISSION_GRANTED
        val subscriptionId = defaultSmsSubscriptionId()
        val activeSimCount = simSnapshot(
            getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        ).activeCount
        val smsManager = when {
            !smsPermissionGranted -> null
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1 && subscriptionId != null -> {
                @Suppress("DEPRECATION")
                SmsManager.getSmsManagerForSubscriptionId(subscriptionId)
            }
            Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP_MR1 -> {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }
            else -> null
        }

        contacts.forEach { contact ->
            val contactId = (contact["contactId"] as? Number)?.toLong()
            val contactName = contact["contactName"] as? String
            val phone = (contact["phone"] as? String).orEmpty()
            val smsCapable = contact["smsCapable"] as? Boolean ?: false
            val attemptId = (contact["smsAttemptId"] as? String).orEmpty()
            if (!smsCapable) {
                SosDispatchStore.recordAttempt(
                    this, ownerUserId, clientEventId, attemptId, contactId, contactName,
                    "sms", "skipped_not_sms_capable"
                )
                return@forEach
            }
            SosDispatchStore.recordAttempt(
                this, ownerUserId, clientEventId, attemptId, contactId, contactName, "sms", "requested"
            )
            when {
                !smsPermissionGranted -> SosDispatchStore.recordAttempt(
                    this, ownerUserId, clientEventId, attemptId, contactId, contactName,
                    "sms", "failed", "permission_denied"
                )
                smsManager == null -> SosDispatchStore.recordAttempt(
                    this, ownerUserId, clientEventId, attemptId, contactId, contactName,
                    "sms", "failed", if (activeSimCount == 0) "no_sim" else "no_default_sms_sim"
                )
                phone.isBlank() -> SosDispatchStore.recordAttempt(
                    this, ownerUserId, clientEventId, attemptId, contactId, contactName,
                    "sms", "failed", "invalid_phone"
                )
                else -> sendMultipartSms(
                    smsManager,
                    ownerUserId,
                    clientEventId,
                    attemptId,
                    contactId,
                    contactName,
                    phone,
                    message
                )
            }
        }

        val primary = contacts.firstOrNull { (it["priority"] as? Number)?.toInt() == 1 }
        if (primary != null) {
            launchEmergencyCall(
                ownerUserId = ownerUserId,
                clientEventId = clientEventId,
                attemptId = (primary["callAttemptId"] as? String).orEmpty(),
                contactId = (primary["contactId"] as? Number)?.toLong(),
                contactName = primary["contactName"] as? String,
                phone = (primary["phone"] as? String).orEmpty()
            )
        }
        SosDispatchStore.markExecutionState(this, ownerUserId, clientEventId, "completed")
        result.success(SosDispatchStore.snapshot(this, ownerUserId, clientEventId))
    }

    private fun sendMultipartSms(
        smsManager: SmsManager,
        ownerUserId: Long,
        clientEventId: String,
        attemptId: String,
        contactId: Long?,
        contactName: String?,
        phone: String,
        message: String
    ) {
        try {
            val parts = smsManager.divideMessage(message)
            val sentIntents = ArrayList<PendingIntent>(parts.size)
            val deliveredIntents = ArrayList<PendingIntent>(parts.size)
            parts.indices.forEach { index ->
                sentIntents.add(statusPendingIntent(
                    ownerUserId, clientEventId, attemptId, contactId, contactName,
                    SosSmsStatusReceiver.PHASE_SENT, index, parts.size
                ))
                deliveredIntents.add(statusPendingIntent(
                    ownerUserId, clientEventId, attemptId, contactId, contactName,
                    SosSmsStatusReceiver.PHASE_DELIVERED, index, parts.size
                ))
            }
            smsManager.sendMultipartTextMessage(
                phone,
                null,
                parts,
                sentIntents,
                deliveredIntents
            )
        } catch (error: SecurityException) {
            SosDispatchStore.recordAttempt(
                this, ownerUserId, clientEventId, attemptId, contactId, contactName,
                "sms", "failed", "permission_denied"
            )
        } catch (error: IllegalArgumentException) {
            SosDispatchStore.recordAttempt(
                this, ownerUserId, clientEventId, attemptId, contactId, contactName,
                "sms", "failed", "invalid_sms_request"
            )
        } catch (error: RuntimeException) {
            SosDispatchStore.recordAttempt(
                this, ownerUserId, clientEventId, attemptId, contactId, contactName,
                "sms", "failed", "sms_dispatch_failed"
            )
        }
    }

    private fun statusPendingIntent(
        ownerUserId: Long,
        clientEventId: String,
        attemptId: String,
        contactId: Long?,
        contactName: String?,
        phase: String,
        partIndex: Int,
        totalParts: Int
    ): PendingIntent {
        val intent = Intent(this, SosSmsStatusReceiver::class.java).apply {
            data = Uri.parse("ankang://sos/$clientEventId/$attemptId/$phase/$partIndex")
            putExtra(SosSmsStatusReceiver.EXTRA_OWNER_USER_ID, ownerUserId)
            putExtra(SosSmsStatusReceiver.EXTRA_CLIENT_EVENT_ID, clientEventId)
            putExtra(SosSmsStatusReceiver.EXTRA_ATTEMPT_ID, attemptId)
            if (contactId != null) putExtra(SosSmsStatusReceiver.EXTRA_CONTACT_ID, contactId)
            putExtra(SosSmsStatusReceiver.EXTRA_CONTACT_NAME, contactName)
            putExtra(SosSmsStatusReceiver.EXTRA_PHASE, phase)
            putExtra(SosSmsStatusReceiver.EXTRA_PART_INDEX, partIndex)
            putExtra(SosSmsStatusReceiver.EXTRA_TOTAL_PARTS, totalParts)
        }
        val requestCode =
            "$ownerUserId|$clientEventId|$attemptId|$phase|$partIndex".hashCode()
        return PendingIntent.getBroadcast(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun getDispatchSnapshot(call: MethodCall, result: MethodChannel.Result) {
        val ownerUserId = call.argument<Number>("ownerUserId")?.toLong() ?: 0L
        val clientEventId = call.argument<String>("clientEventId")?.trim().orEmpty()
        if (ownerUserId <= 0 || clientEventId.isBlank()) {
            result.error("invalid_event_id", "clientEventId 不能为空", null)
            return
        }
        result.success(SosDispatchStore.snapshot(this, ownerUserId, clientEventId))
    }

    private fun callEmergencyNumber(call: MethodCall, result: MethodChannel.Result) {
        val ownerUserId = call.argument<Number>("ownerUserId")?.toLong() ?: 0L
        val clientEventId = call.argument<String>("clientEventId")?.trim().orEmpty()
        val attemptId = call.argument<String>("attemptId")?.trim().orEmpty()
        val phone = call.argument<String>("phone")?.trim().orEmpty()
        if (ownerUserId <= 0 || clientEventId.isBlank() || attemptId.isBlank() || phone.isBlank()) {
            result.error("invalid_call", "拨号参数不完整", null)
            return
        }
        launchEmergencyCall(
            ownerUserId,
            clientEventId,
            attemptId,
            (call.argument<Number>("contactId"))?.toLong(),
            call.argument<String>("contactName"),
            phone
        )
        result.success(SosDispatchStore.snapshot(this, ownerUserId, clientEventId))
    }

    private fun launchEmergencyCall(
        ownerUserId: Long,
        clientEventId: String,
        attemptId: String,
        contactId: Long?,
        contactName: String?,
        phone: String
    ) {
        if (attemptId.isBlank() || phone.isBlank()) return
        SosDispatchStore.recordAttempt(
            this, ownerUserId, clientEventId, attemptId, contactId, contactName, "call", "requested"
        )
        val canCallDirectly = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.CALL_PHONE
        ) == PackageManager.PERMISSION_GRANTED
        val intent = Intent(
            if (canCallDirectly) Intent.ACTION_CALL else Intent.ACTION_DIAL,
            Uri.fromParts("tel", phone, null)
        )
        try {
            startActivity(intent)
            SosDispatchStore.recordAttempt(
                this,
                ownerUserId,
                clientEventId,
                attemptId,
                contactId,
                contactName,
                "call",
                "launched",
                if (canCallDirectly) null else "dialer_fallback_permission_denied"
            )
        } catch (error: RuntimeException) {
            SosDispatchStore.recordAttempt(
                this, ownerUserId, clientEventId, attemptId, contactId, contactName,
                "call", "failed", "call_launch_failed"
            )
        }
    }

    private data class SimSnapshot(val slotCount: Int, val activeCount: Int)

    private fun saveLocalSosEvent(call: MethodCall, result: MethodChannel.Result) {
        val event = call.argument<Map<String, Any?>>("event")
        val ownerUserId = (event?.get("ownerUserId") as? Number)?.toLong() ?: 0L
        if (event == null ||
            ownerUserId <= 0 ||
            (event["clientEventId"] as? String).isNullOrBlank()
        ) {
            result.error("invalid_local_event", "本地 SOS 事件参数不完整", null)
            return
        }
        SosDispatchStore.saveEvent(this, event)
        result.success(true)
    }

    private fun getLocalSosEvents(call: MethodCall, result: MethodChannel.Result) {
        val ownerUserId = call.argument<Number>("ownerUserId")?.toLong() ?: 0L
        val pendingOnly = call.argument<Boolean>("pendingOnly") ?: false
        result.success(SosDispatchStore.events(this, ownerUserId, pendingOnly))
    }

    private fun markLocalSosEventSynced(call: MethodCall, result: MethodChannel.Result) {
        val ownerUserId = call.argument<Number>("ownerUserId")?.toLong() ?: 0L
        val clientEventId = call.argument<String>("clientEventId")?.trim().orEmpty()
        if (ownerUserId <= 0 || clientEventId.isBlank()) {
            result.error("invalid_event_id", "clientEventId 不能为空", null)
            return
        }
        SosDispatchStore.markEventSynced(this, ownerUserId, clientEventId)
        result.success(true)
    }

    private fun deleteLocalSosEvent(call: MethodCall, result: MethodChannel.Result) {
        val ownerUserId = call.argument<Number>("ownerUserId")?.toLong() ?: 0L
        val clientEventId = call.argument<String>("clientEventId")?.trim().orEmpty()
        if (ownerUserId <= 0 || clientEventId.isBlank()) {
            result.error("invalid_event_id", "SOS 账号或事件编号无效", null)
            return
        }
        SosDispatchStore.deleteEvent(this, ownerUserId, clientEventId)
        result.success(true)
    }
}
