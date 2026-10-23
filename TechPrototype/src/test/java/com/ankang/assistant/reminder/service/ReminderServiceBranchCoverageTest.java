package com.ankang.assistant.reminder.service;

import com.ankang.assistant.config.JwtService;
import com.ankang.assistant.reminder.dto.ReminderSaveDTO;
import com.ankang.assistant.reminder.entity.Reminder;
import com.ankang.assistant.reminder.mapper.ReminderMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class ReminderServiceBranchCoverageTest {

    @AfterEach
    void clearContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void updateCoversRepeatTypeOnlyScheduleChange() {
        authenticate(42L);
        ReminderMapper mapper = mock(ReminderMapper.class);
        Reminder reminder = reminder(1L, 42L, "daily");
        reminder.setCompleted(true);
        reminder.setLastCompletedDate(LocalDate.now());
        when(mapper.selectById(1L)).thenReturn(reminder);
        when(mapper.updateById(any(Reminder.class))).thenReturn(1);
        ReminderService service = new ReminderService(mapper);

        service.updateReminder(1L, new ReminderSaveDTO(
                null, "title", "other", "description", null,
                reminder.getRemindAt(), null, "weekly", true));
        assertThat(reminder.getCompleted()).isFalse();
        assertThat(reminder.getLastCompletedDate()).isNull();
    }

    @Test
    void requireReminderCoversWrongOwner() {
        authenticate(42L);
        ReminderMapper mapper = mock(ReminderMapper.class);
        when(mapper.selectById(2L)).thenReturn(reminder(2L, 99L, "once"));

        assertThatThrownBy(() -> new ReminderService(mapper).completeReminder(2L))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void weeklyCompletionCoversDifferentWeekAndDifferentYear() {
        ReminderService service = new ReminderService(mock(ReminderMapper.class));
        Reminder priorWeek = reminder(1L, 42L, "weekly");
        priorWeek.setLastCompletedDate(LocalDate.now().minusWeeks(1));
        Reminder priorYear = reminder(2L, 42L, "weekly");
        priorYear.setLastCompletedDate(LocalDate.now().minusYears(2));

        assertThat((Boolean) ReflectionTestUtils.invokeMethod(
                service, "isCompletedForToday", priorWeek)).isFalse();
        assertThat((Boolean) ReflectionTestUtils.invokeMethod(
                service, "isCompletedForToday", priorYear)).isFalse();
    }

    @Test
    void helperMethodsCoverNullBlankAndNonPositiveIds() {
        ReminderService service = new ReminderService(mock(ReminderMapper.class));
        assertThat((Boolean) ReflectionTestUtils.invokeMethod(
                service, "hasText", (Object) null)).isFalse();
        assertThat((Boolean) ReflectionTestUtils.invokeMethod(
                service, "hasText", " ")).isFalse();
        assertThat((Reminder) ReflectionTestUtils.invokeMethod(
                service, "findByClientReminderId", 42L, null)).isNull();

        assertThatThrownBy(() -> service.listRemindersByUserId(0L))
                .isInstanceOf(IllegalArgumentException.class);
    }

    private Reminder reminder(Long id, Long userId, String repeatType) {
        Reminder reminder = new Reminder();
        reminder.setId(id);
        reminder.setUserId(userId);
        reminder.setTitle("title");
        reminder.setType("other");
        reminder.setRepeatType(repeatType);
        reminder.setEnabled(true);
        reminder.setRemindAt(LocalDateTime.now().withSecond(0).withNano(0));
        reminder.setCompleted(false);
        return reminder;
    }

    private void authenticate(Long userId) {
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(
                        new JwtService.JwtUser(userId, "branch-user"), null, List.of()));
    }
}
