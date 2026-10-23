package com.ankang.assistant.emergency.service;

import com.ankang.assistant.emergency.dto.DispatchAttemptDTO;
import com.ankang.assistant.emergency.dto.EmergencyContactSaveDTO;
import com.ankang.assistant.emergency.dto.SosCreateDTO;
import com.ankang.assistant.emergency.entity.EmergencyContact;
import com.ankang.assistant.emergency.entity.EmergencyDeliveryAttempt;
import com.ankang.assistant.emergency.entity.EmergencyEvent;
import com.ankang.assistant.emergency.mapper.EmergencyContactMapper;
import com.ankang.assistant.emergency.mapper.EmergencyDeliveryAttemptMapper;
import com.ankang.assistant.emergency.mapper.EmergencyEventMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class EmergencyServiceBranchCoverageTest {

    private EmergencyService service;

    @BeforeEach
    void setUp() {
        service = new EmergencyService(mock(EmergencyContactMapper.class), mock(EmergencyEventMapper.class),
                mock(EmergencyDeliveryAttemptMapper.class));
    }

    @Test
    void coversAllSosValidationAndLocationBranches() {
        assertThatThrownBy(() -> invoke("validateSosCreateDTO", (Object) null))
                .isInstanceOf(IllegalArgumentException.class);
        validate(sos(null, null, null, null, null));
        validate(sos("id", null, null, null, "cached"));
        assertThat((String) invoke("resolveLocationSource", sos(null, null, null, null, null)))
                .isEqualTo("unavailable");
        assertThat((String) invoke("resolveLocationSource", sos(null, BigDecimal.ONE, BigDecimal.TEN, null, null)))
                .isEqualTo("fresh");
        assertThat((String) invoke("resolveLocationSource", sos(null, null, null, null, "cached")))
                .isEqualTo("cached");

        assertThatThrownBy(() -> validate(sos("x".repeat(37), null, null, null, null)))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> validate(sos(null, BigDecimal.ONE, null, null, null)))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> validate(sos(null, null, BigDecimal.ONE, null, null)))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> validate(sos(null, null, null, new BigDecimal("-1"), null)))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> validate(sos(null, null, null, null, "gps")))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void coversAttemptValidationChannelStatusCombinations() {
        validateAttempt("sms", "requested");
        validateAttempt("sms", "sent");
        validateAttempt("sms", "delivered");
        validateAttempt("call", "requested");
        validateAttempt("call", "launched");
        validateAttempt("call", "failed");

        assertThatThrownBy(() -> validateAttempt("push", "sent")).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> validateAttempt("sms", "unknown")).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> validateAttempt("call", "sent")).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> validateAttempt("call", "delivered")).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> validateAttempt("call", "skipped_not_sms_capable"))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> validateAttempt("sms", "launched")).isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void coversAggregateStatusAndDeliveredContactBranches() {
        assertThat((String) invoke("aggregateStatus", List.of())).isEqualTo("dispatching");
        assertThat((String) invoke("aggregateStatus", List.of(attempt("sms", "requested", 1L))))
                .isEqualTo("dispatching");
        assertThat((String) invoke("aggregateStatus", List.of(attempt("sms", "failed", 1L))))
                .isEqualTo("failed");
        assertThat((String) invoke("aggregateStatus", List.of(attempt("sms", "delivered", 1L))))
                .isEqualTo("completed");
        assertThat((String) invoke("aggregateStatus", List.of(
                attempt("sms", "delivered", 1L), attempt("call", "failed", 2L))))
                .isEqualTo("partial_failure");

        List<EmergencyDeliveryAttempt> attempts = List.of(
                attempt("sms", "delivered", 1L),
                attempt("sms", "delivered", 1L),
                attempt("sms", "delivered", null),
                attempt("call", "delivered", 2L),
                attempt("sms", "failed", 3L));
        assertThat((int) invoke("countDeliveredContacts", attempts)).isEqualTo(1);
        assertThat((int) invoke("statusRank", "requested")).isZero();
        assertThat((int) invoke("statusRank", "sent")).isEqualTo(1);
        assertThat((int) invoke("statusRank", "failed")).isEqualTo(2);
        assertThat((boolean) invoke("hasText", (Object) null)).isFalse();
        assertThat((boolean) invoke("hasText", " ")).isFalse();
        assertThat((boolean) invoke("hasText", "x")).isTrue();
        assertThatThrownBy(() -> invoke("assertValidUserId", (Long) null)).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> invoke("assertValidUserId", 0L)).isInstanceOf(IllegalArgumentException.class);
        invoke("assertValidUserId", 1L);
    }

    @Test
    void coversContactOwnershipClientIdsAndDtoFallbacks() {
        EmergencyContactMapper contacts = mock(EmergencyContactMapper.class);
        service = new EmergencyService(contacts, mock(EmergencyEventMapper.class),
                mock(EmergencyDeliveryAttemptMapper.class));
        EmergencyContact contact = new EmergencyContact();
        contact.setId(1L);
        contact.setUserId(42L);

        when(contacts.selectById(1L)).thenReturn(null, contact, contact);
        assertThatThrownBy(() -> invoke("requireContact", 1L, 42L))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> invoke("requireContact", 1L, 7L))
                .isInstanceOf(IllegalArgumentException.class);
        assertThat((EmergencyContact) invoke("requireContact", 1L, 42L)).isSameAs(contact);

        assertThat((EmergencyContact) invoke("findContactByClientId", 42L, null)).isNull();
        assertThat((EmergencyContact) invoke("findContactByClientId", 42L, " ")).isNull();

        EmergencyContact first = new EmergencyContact();
        invoke("applyContactDTO", first,
                new EmergencyContactSaveDTO(null, "name", null, "friend", "13800000000", null));
        assertThat(first.getRelation()).isEqualTo("friend");
        assertThat(first.getRelationship()).isEqualTo("friend");
        EmergencyContact second = new EmergencyContact();
        invoke("applyContactDTO", second,
                new EmergencyContactSaveDTO(null, "name", "family", "friend", "13800000000", 1));
        assertThat(second.getRelation()).isEqualTo("family");
        assertThat(second.getRelationship()).isEqualTo("friend");
    }

    @Test
    void coversAttemptNullEventAndTerminalUpdateBranches() {
        assertThat((List<?>) invoke("attemptsForEvent", null, 42L)).isEmpty();

        EmergencyDeliveryAttempt terminal = attempt("sms", "delivered", 1L);
        terminal.setOccurredAt(LocalDateTime.MIN);
        DispatchAttemptDTO regression = new DispatchAttemptDTO(
                "a", 2L, "sms", "sent", "ignored", LocalDateTime.MAX);
        invoke("applyAttemptUpdate", terminal, regression, LocalDateTime.now());
        assertThat(terminal.getContactId()).isEqualTo(1L);
        assertThat(terminal.getOccurredAt()).isEqualTo(LocalDateTime.MIN);

        EmergencyDeliveryAttempt requested = attempt("sms", "requested", 1L);
        LocalDateTime now = LocalDateTime.now();
        invoke("applyAttemptUpdate", requested,
                new DispatchAttemptDTO("a", 2L, "sms", "delivered", null, null), now);
        assertThat(requested.getStatus()).isEqualTo("delivered");
        assertThat(requested.getOccurredAt()).isEqualTo(now);

        EmergencyDeliveryAttempt sent = attempt("sms", "sent", 1L);
        LocalDateTime occurred = now.minusMinutes(1);
        invoke("applyAttemptUpdate", sent,
                new DispatchAttemptDTO("a", 2L, "sms", "delivered", null, occurred), now);
        assertThat(sent.getOccurredAt()).isEqualTo(occurred);
    }

    @Test
    void coversConcurrentAttemptInsertRecoveryAndRethrow() {
        EmergencyDeliveryAttemptMapper attempts = mock(EmergencyDeliveryAttemptMapper.class);
        service = new EmergencyService(mock(EmergencyContactMapper.class), mock(EmergencyEventMapper.class), attempts);
        EmergencyEvent event = new EmergencyEvent();
        event.setId(10L);
        DispatchAttemptDTO dto = new DispatchAttemptDTO("attempt", 2L, "sms", "delivered", null, null);
        EmergencyDeliveryAttempt concurrent = attempt("sms", "requested", 2L);
        concurrent.setId(99L);

        when(attempts.selectOne(any())).thenReturn(null, concurrent);
        doThrow(new org.springframework.dao.DuplicateKeyException("race"))
                .when(attempts).insert(any(EmergencyDeliveryAttempt.class));
        invoke("upsertAttempt", event, 42L, dto);
        verify(attempts).updateById(concurrent);

        EmergencyDeliveryAttemptMapper failed = mock(EmergencyDeliveryAttemptMapper.class);
        service = new EmergencyService(mock(EmergencyContactMapper.class), mock(EmergencyEventMapper.class), failed);
        when(failed.selectOne(any())).thenReturn(null);
        doThrow(new org.springframework.dao.DuplicateKeyException("race"))
                .when(failed).insert(any(EmergencyDeliveryAttempt.class));
        assertThatThrownBy(() -> invoke("upsertAttempt", event, 42L, dto))
                .isInstanceOf(org.springframework.dao.DuplicateKeyException.class);
    }

    private SosCreateDTO sos(String id, BigDecimal lat, BigDecimal lon, BigDecimal accuracy, String source) {
        return new SosCreateDTO(id, LocalDateTime.now(), lat, lon, accuracy, source, null, null);
    }

    private void validate(SosCreateDTO dto) {
        invoke("validateSosCreateDTO", dto);
    }

    private void validateAttempt(String channel, String status) {
        invoke("validateAttempt", new DispatchAttemptDTO("a", 1L, channel, status, null, null));
    }

    private EmergencyDeliveryAttempt attempt(String channel, String status, Long contactId) {
        EmergencyDeliveryAttempt attempt = new EmergencyDeliveryAttempt();
        attempt.setChannel(channel);
        attempt.setStatus(status);
        attempt.setContactId(contactId);
        return attempt;
    }

    private <T> T invoke(String name, Object... args) {
        return ReflectionTestUtils.invokeMethod(service, name, args);
    }
}
