package com.ankang.assistant.emergency.service;

import com.ankang.assistant.config.JwtService;
import com.ankang.assistant.emergency.dto.DispatchAttemptDTO;
import com.ankang.assistant.emergency.dto.DispatchResultsDTO;
import com.ankang.assistant.emergency.dto.EmergencyContactSaveDTO;
import com.ankang.assistant.emergency.dto.SosCreateDTO;
import com.ankang.assistant.emergency.entity.EmergencyContact;
import com.ankang.assistant.emergency.entity.EmergencyDeliveryAttempt;
import com.ankang.assistant.emergency.entity.EmergencyEvent;
import com.ankang.assistant.emergency.mapper.EmergencyContactMapper;
import com.ankang.assistant.emergency.mapper.EmergencyDeliveryAttemptMapper;
import com.ankang.assistant.emergency.mapper.EmergencyEventMapper;
import com.ankang.assistant.emergency.vo.EmergencyEventVO;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class EmergencyServiceTest {

    @AfterEach
    void clearSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void recordsSosEventWithoutClaimingContactsWereNotified() {
        authenticateAs(42L);
        EmergencyContactMapper contactMapper = mock(EmergencyContactMapper.class);
        EmergencyEventMapper eventMapper = mock(EmergencyEventMapper.class);
        EmergencyDeliveryAttemptMapper attemptMapper = mock(EmergencyDeliveryAttemptMapper.class);
        doAnswer(invocation -> {
            ((EmergencyEvent) invocation.getArgument(0)).setId(1001L);
            return 1;
        }).when(eventMapper).insert(any(EmergencyEvent.class));
        EmergencyService service = new EmergencyService(contactMapper, eventMapper, attemptMapper);

        EmergencyEventVO event = service.createSosEvent(new SosCreateDTO(
                new BigDecimal("31.2304"), new BigDecimal("121.4737"), "上海市某地", "用户确认求助"
        ));

        assertThat(event.status()).isEqualTo("dispatching");
        assertThat(event.contactsNotified()).isZero();
        assertThat(event.id()).isEqualTo(1001L);
        ArgumentCaptor<EmergencyEvent> eventCaptor = ArgumentCaptor.forClass(EmergencyEvent.class);
        verify(eventMapper).insert(eventCaptor.capture());
        assertThat(eventCaptor.getValue().getUserId()).isEqualTo(42L);
        assertThat(eventCaptor.getValue().getLocationSource()).isEqualTo("fresh");
    }

    @Test
    void removingPrimaryFlagPromotesNextContact() {
        authenticateAs(42L);
        EmergencyContactMapper contactMapper = mock(EmergencyContactMapper.class);
        EmergencyEventMapper eventMapper = mock(EmergencyEventMapper.class);
        EmergencyDeliveryAttemptMapper attemptMapper = mock(EmergencyDeliveryAttemptMapper.class);
        EmergencyContact primary = contact(1L, 1);
        EmergencyContact backup = contact(2L, 2);
        List<EmergencyContact> contacts = new ArrayList<>(List.of(primary, backup));
        when(contactMapper.selectById(1L)).thenReturn(primary);
        when(contactMapper.selectList(any())).thenAnswer(invocation -> new ArrayList<>(contacts));
        when(contactMapper.updateById(any(EmergencyContact.class))).thenReturn(1);

        new EmergencyService(contactMapper, eventMapper, attemptMapper).updateContact(
                1L, new EmergencyContactSaveDTO(null, "主要联系人", "家属", null, "13800000001", 0)
        );

        assertThat(primary.getPriority()).isEqualTo(2);
        assertThat(backup.getPriority()).isEqualTo(1);
    }

    @Test
    void rejectsUnsupportedPriorityAndInvalidPhone() {
        authenticateAs(42L);
        EmergencyService service = serviceWithMocks();

        assertThatThrownBy(() -> service.createContact(
                new EmergencyContactSaveDTO(null, "联系人", "家属", null, "13800000001", -1)
        )).isInstanceOf(IllegalArgumentException.class).hasMessage("priority 只能为 0 或 1");
        assertThatThrownBy(() -> service.createContact(
                new EmergencyContactSaveDTO(null, "联系人", "家属", null, "12-34", 0)
        )).isInstanceOf(IllegalArgumentException.class).hasMessage("请输入正确的大陆手机号");
    }

    @Test
    void rejectsDuplicatePhoneForCurrentUser() {
        authenticateAs(42L);
        EmergencyContactMapper contactMapper = mock(EmergencyContactMapper.class);
        when(contactMapper.selectList(any())).thenReturn(List.of());
        when(contactMapper.selectCount(any())).thenReturn(1L);
        EmergencyService service = new EmergencyService(
                contactMapper,
                mock(EmergencyEventMapper.class),
                mock(EmergencyDeliveryAttemptMapper.class)
        );

        assertThatThrownBy(() -> service.createContact(
                new EmergencyContactSaveDTO(null, "重复联系人", "家属", null, "13800000001", 0)
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("该手机号已经是当前账号的紧急联系人");
    }

    @Test
    void createsSosIdempotentlyForCurrentUser() {
        authenticateAs(42L);
        EmergencyContactMapper contactMapper = mock(EmergencyContactMapper.class);
        EmergencyEventMapper eventMapper = mock(EmergencyEventMapper.class);
        EmergencyDeliveryAttemptMapper attemptMapper = mock(EmergencyDeliveryAttemptMapper.class);
        doAnswer(invocation -> {
            ((EmergencyEvent) invocation.getArgument(0)).setId(2001L);
            return 1;
        }).when(eventMapper).insert(any(EmergencyEvent.class));
        EmergencyEvent existing = event(2001L, "device-event-1");
        when(eventMapper.selectOne(any())).thenReturn(null, existing);
        when(attemptMapper.selectList(any())).thenReturn(List.of());
        EmergencyService service = new EmergencyService(contactMapper, eventMapper, attemptMapper);
        SosCreateDTO request = new SosCreateDTO(
                "device-event-1", LocalDateTime.now(), null, null,
                null, "unavailable", null, "求助"
        );

        EmergencyEventVO first = service.createSosEvent(request);
        EmergencyEventVO second = service.createSosEvent(request);

        assertThat(first.id()).isEqualTo(2001L);
        assertThat(second.id()).isEqualTo(2001L);
        verify(eventMapper, times(1)).insert(any(EmergencyEvent.class));
    }

    @Test
    void upsertsDispatchAttemptAndCountsOnlyDeliveredContacts() {
        authenticateAs(42L);
        EmergencyContactMapper contactMapper = mock(EmergencyContactMapper.class);
        EmergencyEventMapper eventMapper = mock(EmergencyEventMapper.class);
        EmergencyDeliveryAttemptMapper attemptMapper = mock(EmergencyDeliveryAttemptMapper.class);
        EmergencyEvent event = event(3001L, "device-event-2");
        EmergencyDeliveryAttempt stored = new EmergencyDeliveryAttempt();
        when(eventMapper.selectOne(any())).thenReturn(event);
        when(attemptMapper.selectOne(any())).thenReturn(null, stored);
        doAnswer(invocation -> {
            EmergencyDeliveryAttempt inserted = invocation.getArgument(0);
            inserted.setId(1L);
            copyAttempt(inserted, stored);
            return 1;
        }).when(attemptMapper).insert(any(EmergencyDeliveryAttempt.class));
        when(attemptMapper.updateById(any(EmergencyDeliveryAttempt.class))).thenReturn(1);
        when(attemptMapper.selectList(any())).thenAnswer(invocation -> List.of(stored));
        when(eventMapper.updateById(any(EmergencyEvent.class))).thenReturn(1);
        EmergencyService service = new EmergencyService(contactMapper, eventMapper, attemptMapper);

        service.updateDispatchResults("device-event-2", results("sent"));
        EmergencyEventVO result = service.updateDispatchResults("device-event-2", results("delivered"));

        assertThat(result.contactsNotified()).isEqualTo(1);
        assertThat(result.status()).isEqualTo("completed");
        assertThat(result.attempts()).singleElement().extracting(item -> item.status()).isEqualTo("delivered");
        verify(attemptMapper, times(1)).insert(any(EmergencyDeliveryAttempt.class));
        verify(attemptMapper, times(1)).updateById(any(EmergencyDeliveryAttempt.class));
    }

    @Test
    void rejectsDispatchUpdateForEventOutsideCurrentUser() {
        authenticateAs(42L);
        assertThatThrownBy(() -> serviceWithMocks().updateDispatchResults(
                "another-users-event", results("delivered")
        )).isInstanceOf(IllegalArgumentException.class).hasMessage("SOS 事件不存在");
    }

    @Test
    void contactCrudListsIdempotencyAndDuplicateRecoveryAreCovered() {
        authenticateAs(42L);
        EmergencyContactMapper contacts = mock(EmergencyContactMapper.class);
        EmergencyEventMapper events = mock(EmergencyEventMapper.class);
        EmergencyDeliveryAttemptMapper attempts = mock(EmergencyDeliveryAttemptMapper.class);
        EmergencyContact stored = contact(30L, 1);
        stored.setClientContactId("client-30");
        stored.setRelation("family");
        stored.setRelationship("family");
        when(contacts.selectList(any())).thenReturn(
                new ArrayList<>(), new ArrayList<>(List.of(stored)), new ArrayList<>(List.of(stored))
        );
        when(contacts.selectCount(any())).thenReturn(0L);
        when(contacts.insert(any(EmergencyContact.class))).thenAnswer(invocation -> {
            EmergencyContact value = invocation.getArgument(0);
            value.setId(30L);
            value.setPriority(1);
            return 1;
        });
        when(contacts.selectById(30L)).thenReturn(stored);
        EmergencyService service = new EmergencyService(contacts, events, attempts);

        var created = service.createContact(new EmergencyContactSaveDTO(
                " client-30 ", "Family", "family", null, "13800000001", 1
        ));
        assertThat(created.id()).isEqualTo(30L);
        assertThat(service.listContacts()).hasSize(1);
        assertThat(service.listContactsByUserId(42L)).hasSize(1);

        service.deleteContact(30L);
        verify(contacts).deleteById(30L);
        when(contacts.selectById(31L)).thenReturn(null);
        service.deleteContact(31L);
        assertThatThrownBy(() -> service.listContactsByUserId(0L))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void sosRequestValidationCoversEveryRejectedShapeAndUnavailableLocation() {
        authenticateAs(42L);
        EmergencyService service = serviceWithMocks();
        assertThatThrownBy(() -> service.createSosEvent(null))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> service.createSosEvent(new SosCreateDTO(
                "x".repeat(37), null, null, null, null, null, null, null
        ))).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> service.createSosEvent(new SosCreateDTO(
                "x", null, BigDecimal.ONE, null, null, null, null, null
        ))).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> service.createSosEvent(new SosCreateDTO(
                "x", null, null, null, new BigDecimal("-1"), null, null, null
        ))).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> service.createSosEvent(new SosCreateDTO(
                "x", null, null, null, null, "gps", null, null
        ))).isInstanceOf(IllegalArgumentException.class);

        EmergencyEventMapper eventMapper = mock(EmergencyEventMapper.class);
        when(eventMapper.insert(any(EmergencyEvent.class))).thenAnswer(invocation -> {
            invocation.<EmergencyEvent>getArgument(0).setId(40L);
            return 1;
        });
        EmergencyService valid = new EmergencyService(
                mock(EmergencyContactMapper.class), eventMapper,
                mock(EmergencyDeliveryAttemptMapper.class)
        );
        EmergencyEventVO result = valid.createSosEvent(new SosCreateDTO(
                null, null, null, null, null, null, null, null
        ));
        assertThat(result.locationSource()).isEqualTo("unavailable");
    }

    @Test
    void dispatchValidationAndAggregateStatesCoverAllBranches() {
        EmergencyService service = serviceWithMocks();
        for (DispatchAttemptDTO invalid : List.of(
                new DispatchAttemptDTO("a", 1L, "email", "sent", null, null),
                new DispatchAttemptDTO("a", 1L, "sms", "unknown", null, null),
                new DispatchAttemptDTO("a", 1L, "call", "sent", null, null),
                new DispatchAttemptDTO("a", 1L, "sms", "launched", null, null)
        )) {
            assertThatThrownBy(() -> ReflectionTestUtils.invokeMethod(
                    service, "validateAttempt", invalid
            )).isInstanceOf(IllegalArgumentException.class);
        }

        assertThat(aggregate(service, List.of())).isEqualTo("dispatching");
        assertThat(aggregate(service, List.of(attempt("requested", "sms", 1L))))
                .isEqualTo("dispatching");
        assertThat(aggregate(service, List.of(attempt("failed", "sms", 1L))))
                .isEqualTo("failed");
        assertThat(aggregate(service, List.of(
                attempt("delivered", "sms", 1L), attempt("failed", "sms", 2L)
        ))).isEqualTo("partial_failure");
        assertThat(aggregate(service, List.of(attempt("launched", "call", 1L))))
                .isEqualTo("completed");
    }

    @Test
    void duplicateSosInsertReturnsConcurrentEventOrRethrows() {
        authenticateAs(42L);
        EmergencyEventMapper events = mock(EmergencyEventMapper.class);
        EmergencyEvent concurrent = event(50L, "dup-event");
        when(events.selectOne(any())).thenReturn(null, null, null, concurrent);
        when(events.insert(any(EmergencyEvent.class))).thenThrow(new DuplicateKeyException("duplicate"));
        EmergencyService service = new EmergencyService(
                mock(EmergencyContactMapper.class), events,
                mock(EmergencyDeliveryAttemptMapper.class)
        );
        SosCreateDTO dto = new SosCreateDTO(
                "dup-event", null, null, null, null, "unavailable", null, null
        );

        assertThatThrownBy(() -> service.createSosEvent(dto))
                .isInstanceOf(DuplicateKeyException.class);
        assertThat(service.createSosEvent(dto).id()).isEqualTo(50L);
    }

    @Test
    void eventListingMissingContactAndPrivateStatusHelpersAreCovered() {
        authenticateAs(42L);
        EmergencyEventMapper events = mock(EmergencyEventMapper.class);
        EmergencyDeliveryAttemptMapper attempts = mock(EmergencyDeliveryAttemptMapper.class);
        EmergencyEvent stored = event(60L, "event-60");
        when(events.selectList(any())).thenReturn(List.of(stored));
        when(attempts.selectList(any())).thenReturn(List.of());
        EmergencyContactMapper contacts = mock(EmergencyContactMapper.class);
        EmergencyService service = new EmergencyService(contacts, events, attempts);

        assertThat(service.listEvents()).hasSize(1);
        assertThat(service.listEventsByUserId(42L)).hasSize(1);
        assertThatThrownBy(() -> service.listEventsByUserId(-1L))
                .isInstanceOf(IllegalArgumentException.class);
        when(contacts.selectById(99L)).thenReturn(null);
        assertThatThrownBy(() -> service.updateContact(
                99L, new EmergencyContactSaveDTO(null, "x", "family", null, "13800000001", 0)
        )).isInstanceOf(IllegalArgumentException.class);

        when(contacts.selectList(any())).thenReturn(new ArrayList<>());
        ReflectionTestUtils.invokeMethod(service, "resequenceContacts", 42L, null);
        assertThat((Integer) ReflectionTestUtils.invokeMethod(service, "statusRank", "requested")).isZero();
        assertThat((Integer) ReflectionTestUtils.invokeMethod(service, "statusRank", "sent")).isEqualTo(1);
        assertThat((Integer) ReflectionTestUtils.invokeMethod(service, "statusRank", "delivered")).isEqualTo(2);
    }

    @Test
    void terminalDispatchAttemptDoesNotRegressAndDuplicateAttemptRecovers() {
        authenticateAs(42L);
        EmergencyEventMapper events = mock(EmergencyEventMapper.class);
        EmergencyDeliveryAttemptMapper attempts = mock(EmergencyDeliveryAttemptMapper.class);
        EmergencyEvent storedEvent = event(70L, "event-70");
        EmergencyDeliveryAttempt terminal = attempt("delivered", "sms", 1L);
        terminal.setId(5L);
        terminal.setAttemptId("a");
        terminal.setEventId(70L);
        terminal.setUserId(42L);
        when(events.selectOne(any())).thenReturn(storedEvent);
        when(attempts.selectOne(any())).thenReturn(terminal);
        when(attempts.selectList(any())).thenReturn(List.of(terminal));
        EmergencyService service = new EmergencyService(
                mock(EmergencyContactMapper.class), events, attempts
        );

        EmergencyEventVO result = service.updateDispatchResults(
                "event-70",
                new DispatchResultsDTO(List.of(
                        new DispatchAttemptDTO("a", 1L, "sms", "sent", null, null)
                ))
        );
        assertThat(result.status()).isEqualTo("completed");
        verify(attempts, org.mockito.Mockito.never()).updateById(any(EmergencyDeliveryAttempt.class));
    }

    private String aggregate(EmergencyService service, List<EmergencyDeliveryAttempt> attempts) {
        return ReflectionTestUtils.invokeMethod(service, "aggregateStatus", attempts);
    }

    private EmergencyDeliveryAttempt attempt(String status, String channel, Long contactId) {
        EmergencyDeliveryAttempt attempt = new EmergencyDeliveryAttempt();
        attempt.setStatus(status);
        attempt.setChannel(channel);
        attempt.setContactId(contactId);
        return attempt;
    }

    private DispatchResultsDTO results(String status) {
        return new DispatchResultsDTO(List.of(
                new DispatchAttemptDTO("attempt-1", 9L, "sms", status, null, LocalDateTime.now())
        ));
    }

    private EmergencyService serviceWithMocks() {
        return new EmergencyService(
                mock(EmergencyContactMapper.class),
                mock(EmergencyEventMapper.class),
                mock(EmergencyDeliveryAttemptMapper.class)
        );
    }

    private EmergencyEvent event(Long id, String clientEventId) {
        EmergencyEvent event = new EmergencyEvent();
        event.setId(id);
        event.setUserId(42L);
        event.setClientEventId(clientEventId);
        event.setCreatedAt(LocalDateTime.now());
        event.setStatus("dispatching");
        event.setContactsNotified(0);
        return event;
    }

    private EmergencyContact contact(Long id, int priority) {
        EmergencyContact contact = new EmergencyContact();
        contact.setId(id);
        contact.setUserId(42L);
        contact.setName("联系人" + id);
        contact.setPhone("1380000000" + id);
        contact.setPriority(priority);
        return contact;
    }

    private void copyAttempt(EmergencyDeliveryAttempt source, EmergencyDeliveryAttempt target) {
        target.setId(source.getId());
        target.setEventId(source.getEventId());
        target.setUserId(source.getUserId());
        target.setAttemptId(source.getAttemptId());
        target.setContactId(source.getContactId());
        target.setChannel(source.getChannel());
        target.setStatus(source.getStatus());
        target.setErrorCode(source.getErrorCode());
        target.setOccurredAt(source.getOccurredAt());
        target.setCreatedAt(source.getCreatedAt());
        target.setUpdatedAt(source.getUpdatedAt());
    }

    private void authenticateAs(Long userId) {
        JwtService.JwtUser principal = new JwtService.JwtUser(userId, "emergency-test");
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(principal, null, List.of())
        );
    }
}
