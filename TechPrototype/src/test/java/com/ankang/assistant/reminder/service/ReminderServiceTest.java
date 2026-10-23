package com.ankang.assistant.reminder.service;

import com.ankang.assistant.config.JwtService;
import com.ankang.assistant.reminder.dto.ReminderSaveDTO;
import com.ankang.assistant.reminder.entity.Reminder;
import com.ankang.assistant.reminder.mapper.ReminderMapper;
import com.ankang.assistant.reminder.vo.ReminderVO;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class ReminderServiceTest {

    /** 防止线程级安全上下文泄漏到其他测试。 */
    @AfterEach
    void clearSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void updatePreservesOneTimeCompletionAndCanDisableReminder() {
        // Arrange：模拟当前登录用户及其已有的一次性提醒。
        authenticateAs(42L);
        ReminderMapper mapper = mock(ReminderMapper.class);
        Reminder existing = new Reminder();
        LocalDateTime remindAt = LocalDateTime.now().withHour(9).withMinute(30).withSecond(0).withNano(0);
        existing.setId(1L);
        existing.setUserId(42L);
        existing.setRepeatType("once");
        existing.setRemindAt(remindAt);
        existing.setCompleted(true);
        when(mapper.selectById(1L)).thenReturn(existing);
        when(mapper.updateById(any(Reminder.class))).thenReturn(1);
        ReminderService service = new ReminderService(mapper);

        // Act：更新内容并停用提醒。
        ReminderVO updated = service.updateReminder(1L, new ReminderSaveDTO(
                null,
                "早餐后服药",
                "medicine",
                "降压药 1 片",
                "饭后服用",
                remindAt,
                null,
                "once",
                false
        ));

        // Assert：普通编辑不能意外清除同一重复类型的完成状态。
        assertThat(updated.completed()).isTrue();
        assertThat(updated.enabled()).isFalse();
        assertThat(updated.remindAt()).isEqualTo(remindAt);
    }

    @Test
    void updateScheduleResetsOneTimeCompletion() {
        authenticateAs(42L);
        ReminderMapper mapper = mock(ReminderMapper.class);
        LocalDateTime originalTime = LocalDateTime.now().withHour(9).withMinute(0).withSecond(0).withNano(0);
        Reminder existing = reminder(2L, "once", originalTime);
        existing.setCompleted(true);
        when(mapper.selectById(2L)).thenReturn(existing);
        when(mapper.updateById(any(Reminder.class))).thenReturn(1);

        ReminderVO updated = new ReminderService(mapper).updateReminder(2L, request(
                originalTime.plusDays(1), "once", true
        ));

        assertThat(updated.completed()).isFalse();
        assertThat(existing.getLastCompletedDate()).isNull();
    }

    @Test
    void createWithExistingClientReminderIdIsIdempotent() {
        authenticateAs(42L);
        ReminderMapper mapper = mock(ReminderMapper.class);
        Reminder existing = reminder(9L, "daily", LocalDateTime.now());
        existing.setClientReminderId("rem-42-offline-1");
        existing.setTitle("离线服药");
        existing.setType("medicine");
        existing.setEnabled(true);
        when(mapper.selectOne(any())).thenReturn(existing);

        ReminderSaveDTO dto = new ReminderSaveDTO(
                "rem-42-offline-1",
                "重复提交",
                "medicine",
                null,
                null,
                LocalDateTime.now(),
                null,
                "daily",
                true
        );
        ReminderVO result = new ReminderService(mapper).createReminder(dto);

        assertThat(result.id()).isEqualTo(9L);
        assertThat(result.clientReminderId()).isEqualTo("rem-42-offline-1");
        verify(mapper, never()).insert(any(Reminder.class));
    }

    @Test
    void updateScheduleResetsRecurringCompletionForCurrentPeriod() {
        authenticateAs(42L);
        ReminderMapper mapper = mock(ReminderMapper.class);
        LocalDateTime originalTime = LocalDateTime.now().withHour(8).withMinute(0).withSecond(0).withNano(0);
        Reminder existing = reminder(3L, "daily", originalTime);
        existing.setCompleted(false);
        existing.setLastCompletedDate(LocalDate.now());
        when(mapper.selectById(3L)).thenReturn(existing);
        when(mapper.updateById(any(Reminder.class))).thenReturn(1);

        ReminderVO updated = new ReminderService(mapper).updateReminder(3L, request(
                originalTime.plusHours(1), "daily", true
        ));

        assertThat(updated.completed()).isFalse();
        assertThat(existing.getLastCompletedDate()).isNull();
    }

    @Test
    void updateRejectsReminderOwnedByAnotherUser() {
        authenticateAs(42L);
        ReminderMapper mapper = mock(ReminderMapper.class);
        Reminder existing = reminder(4L, "once", LocalDateTime.now());
        existing.setUserId(99L);
        when(mapper.selectById(4L)).thenReturn(existing);

        ReminderService service = new ReminderService(mapper);

        assertThatThrownBy(() -> service.updateReminder(
                4L,
                request(existing.getRemindAt(), "once", true)
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("提醒不存在");
    }

    @Test
    void uncompleteClearsStoredCompletionState() {
        authenticateAs(42L);
        ReminderMapper mapper = mock(ReminderMapper.class);
        Reminder existing = reminder(5L, "daily", LocalDateTime.now());
        existing.setCompleted(true);
        existing.setLastCompletedDate(LocalDate.now());
        when(mapper.selectById(5L)).thenReturn(existing);
        when(mapper.updateById(any(Reminder.class))).thenReturn(1);

        ReminderVO before = new ReminderService(mapper).updateReminder(
                5L,
                request(existing.getRemindAt(), "daily", true)
        );
        assertThat(before.completed()).isTrue();

        var result = new ReminderService(mapper).uncompleteReminder(5L);

        assertThat(result.completed()).isFalse();
        assertThat(existing.getCompleted()).isFalse();
        assertThat(existing.getLastCompletedDate()).isNull();
    }

    @Test
    void rejectsUnsupportedTypeAndRepeatType() {
        authenticateAs(42L);
        ReminderMapper mapper = mock(ReminderMapper.class);
        ReminderService service = new ReminderService(mapper);

        assertThatThrownBy(() -> service.createReminder(new ReminderSaveDTO(
                null,
                "提醒", "unknown", null, null, LocalDateTime.now(), null, "daily", true
        ))).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("不支持的提醒类型: unknown");
        assertThatThrownBy(() -> service.createReminder(new ReminderSaveDTO(
                null,
                "提醒", "medicine", null, null, LocalDateTime.now(), null, "monthly", true
        ))).isInstanceOf(IllegalArgumentException.class)
                .hasMessage("不支持的重复类型: monthly");
    }

    @Test
    void listAndPendingQueriesFilterCompletedItemsAndClampLimits() {
        authenticateAs(42L);
        ReminderMapper mapper = mock(ReminderMapper.class);
        Reminder onceDone = reminder(1L, "once", LocalDateTime.now());
        onceDone.setCompleted(true);
        onceDone.setEnabled(true);
        Reminder dailyDone = reminder(2L, "daily", LocalDateTime.now());
        dailyDone.setLastCompletedDate(LocalDate.now());
        dailyDone.setEnabled(true);
        Reminder weeklyDone = reminder(3L, "weekly", LocalDateTime.now());
        weeklyDone.setLastCompletedDate(LocalDate.now());
        weeklyDone.setEnabled(true);
        Reminder pending = reminder(4L, "daily", LocalDateTime.now());
        pending.setEnabled(true);
        when(mapper.selectList(any())).thenReturn(List.of(onceDone, dailyDone, weeklyDone, pending));
        ReminderService service = new ReminderService(mapper);

        assertThat(service.listReminders()).hasSize(4);
        assertThat(service.listRemindersByUserId(42L)).hasSize(4);
        assertThat(service.listPendingReminders(0)).extracting(ReminderVO::id).containsExactly(4L);
        assertThat(service.listPendingRemindersByUserId(42L, 100))
                .extracting(ReminderVO::id).containsExactly(4L);
        assertThatThrownBy(() -> service.listRemindersByUserId(null))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void createDeleteAndCompleteCoverDefaultsOwnershipAndRecurringRules() {
        authenticateAs(42L);
        ReminderMapper mapper = mock(ReminderMapper.class);
        when(mapper.insert(any(Reminder.class))).thenAnswer(invocation -> {
            invocation.<Reminder>getArgument(0).setId(10L);
            return 1;
        });
        ReminderService service = new ReminderService(mapper);
        ReminderVO created = service.createReminder(new ReminderSaveDTO(
                "  client-10  ", "Morning", null, "description", null,
                null, "07:30", null, null
        ));
        assertThat(created.id()).isEqualTo(10L);
        assertThat(created.type()).isEqualTo("other");
        assertThat(created.repeatType()).isEqualTo("once");
        assertThat(created.enabled()).isTrue();
        assertThat(created.remindTime()).isEqualTo("07:30");

        Reminder once = reminder(11L, "once", LocalDateTime.now());
        once.setUserId(42L);
        when(mapper.selectById(11L)).thenReturn(once);
        assertThat(service.completeReminder(11L).completed()).isTrue();

        Reminder daily = reminder(12L, "daily", LocalDateTime.now());
        when(mapper.selectById(12L)).thenReturn(daily);
        assertThat(service.completeReminder(12L).completed()).isTrue();

        when(mapper.selectById(13L)).thenReturn(null);
        service.deleteReminder(13L);
        Reminder foreign = reminder(14L, "once", LocalDateTime.now());
        foreign.setUserId(99L);
        when(mapper.selectById(14L)).thenReturn(foreign);
        service.deleteReminder(14L);
        when(mapper.selectById(15L)).thenReturn(reminder(15L, "once", LocalDateTime.now()));
        service.deleteReminder(15L);
        verify(mapper).deleteById(15L);
    }

    @Test
    void duplicateInsertReturnsConcurrentRowOrRethrows() {
        authenticateAs(42L);
        ReminderMapper mapper = mock(ReminderMapper.class);
        Reminder concurrent = reminder(20L, "daily", LocalDateTime.now());
        concurrent.setClientReminderId("dup");
        concurrent.setEnabled(true);
        when(mapper.insert(any(Reminder.class))).thenThrow(new DuplicateKeyException("duplicate"));
        when(mapper.selectOne(any())).thenReturn(null, null, null, concurrent);
        ReminderService service = new ReminderService(mapper);
        ReminderSaveDTO dto = new ReminderSaveDTO(
                "dup", "title", "other", null, null,
                null, null, "daily", true
        );

        assertThatThrownBy(() -> service.createReminder(dto))
                .isInstanceOf(DuplicateKeyException.class);
        assertThat(service.createReminder(dto).id()).isEqualTo(20L);
    }

    private Reminder reminder(Long id, String repeatType, LocalDateTime remindAt) {
        Reminder reminder = new Reminder();
        reminder.setId(id);
        reminder.setUserId(42L);
        reminder.setRepeatType(repeatType);
        reminder.setRemindAt(remindAt);
        return reminder;
    }

    private ReminderSaveDTO request(LocalDateTime remindAt, String repeatType, boolean enabled) {
        return new ReminderSaveDTO(
                null,
                "提醒",
                "medicine",
                null,
                null,
                remindAt,
                null,
                repeatType,
                enabled
        );
    }

    /** 构造与 JwtAuthenticationFilter 一致的测试登录上下文。 */
    private void authenticateAs(Long userId) {
        JwtService.JwtUser principal = new JwtService.JwtUser(userId, "reminder-test");
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(principal, null, List.of())
        );
    }
}
