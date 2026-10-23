package com.example.ankang_assistant

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.SmsManager

class SosSmsStatusReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val ownerUserId = intent.getLongExtra(EXTRA_OWNER_USER_ID, 0L)
        if (ownerUserId <= 0) return
        val clientEventId = intent.getStringExtra(EXTRA_CLIENT_EVENT_ID) ?: return
        val attemptId = intent.getStringExtra(EXTRA_ATTEMPT_ID) ?: return
        val contactId = intent.longExtraOrNull(EXTRA_CONTACT_ID)
        val contactName = intent.getStringExtra(EXTRA_CONTACT_NAME)
        val phase = intent.getStringExtra(EXTRA_PHASE) ?: return
        val partIndex = intent.getIntExtra(EXTRA_PART_INDEX, 0)
        val totalParts = intent.getIntExtra(EXTRA_TOTAL_PARTS, 1)

        if (resultCode != Activity.RESULT_OK) {
            SosDispatchStore.recordAttempt(
                context,
                ownerUserId,
                clientEventId,
                attemptId,
                contactId,
                contactName,
                "sms",
                "failed",
                smsErrorCode(resultCode, phase)
            )
            return
        }
        val complete = SosDispatchStore.recordSuccessfulPart(
            context,
            ownerUserId,
            clientEventId,
            attemptId,
            phase,
            partIndex,
            totalParts
        )
        if (complete) {
            SosDispatchStore.recordAttempt(
                context,
                ownerUserId,
                clientEventId,
                attemptId,
                contactId,
                contactName,
                "sms",
                if (phase == PHASE_SENT) "sent" else "delivered"
            )
        }
    }

    private fun smsErrorCode(code: Int, phase: String): String {
        if (phase == PHASE_DELIVERED) return "delivery_failed"
        return when (code) {
            SmsManager.RESULT_ERROR_GENERIC_FAILURE -> "generic_failure"
            SmsManager.RESULT_ERROR_NO_SERVICE -> "no_service"
            SmsManager.RESULT_ERROR_NULL_PDU -> "null_pdu"
            SmsManager.RESULT_ERROR_RADIO_OFF -> "radio_off"
            SmsManager.RESULT_ERROR_LIMIT_EXCEEDED -> "limit_exceeded"
            SmsManager.RESULT_ERROR_SHORT_CODE_NOT_ALLOWED -> "short_code_not_allowed"
            SmsManager.RESULT_ERROR_SHORT_CODE_NEVER_ALLOWED -> "short_code_never_allowed"
            else -> "sms_error_$code"
        }
    }

    private fun Intent.longExtraOrNull(key: String): Long? =
        if (hasExtra(key)) getLongExtra(key, 0L) else null

    companion object {
        const val EXTRA_OWNER_USER_ID = "ownerUserId"
        const val EXTRA_CLIENT_EVENT_ID = "clientEventId"
        const val EXTRA_ATTEMPT_ID = "attemptId"
        const val EXTRA_CONTACT_ID = "contactId"
        const val EXTRA_CONTACT_NAME = "contactName"
        const val EXTRA_PHASE = "phase"
        const val EXTRA_PART_INDEX = "partIndex"
        const val EXTRA_TOTAL_PARTS = "totalParts"
        const val PHASE_SENT = "sent"
        const val PHASE_DELIVERED = "delivered"
    }
}
