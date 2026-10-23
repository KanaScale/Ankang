package com.ankang.assistant.agent.tool;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class AgentToolPayloadsTest {

    @Test
    void convertsAllSupportedScalarAndCollectionTypes() {
        assertThat(AgentToolPayloads.string(null, "x")).isEmpty();
        assertThat(AgentToolPayloads.string(Map.of("x", " value "), "x")).isEqualTo("value");
        assertThat(AgentToolPayloads.integer(Map.of("x", 1), "x")).isEqualTo(1);
        assertThat(AgentToolPayloads.integer(Map.of("x", 2L), "x")).isEqualTo(2);
        assertThat(AgentToolPayloads.integer(Map.of("x", " 3 "), "x")).isEqualTo(3);
        assertThat(AgentToolPayloads.integer(Map.of("x", " "), "x")).isNull();
        assertThat(AgentToolPayloads.decimal(Map.of("x", new BigDecimal("1.2")), "x"))
                .isEqualByComparingTo("1.2");
        assertThat(AgentToolPayloads.decimal(Map.of("x", 2.5), "x")).isEqualByComparingTo("2.5");
        assertThat(AgentToolPayloads.decimal(Map.of("x", " 3.5 "), "x")).isEqualByComparingTo("3.5");
        assertThat(AgentToolPayloads.doubleValue(Map.of("x", "4.5"), "x")).isEqualTo(4.5);
        assertThat(AgentToolPayloads.doubleValue(Map.of(), "x")).isNull();
        assertThat(AgentToolPayloads.list(Map.of("x", List.of(1)), "x")).isEqualTo(List.of(1));
        assertThat(AgentToolPayloads.list(Map.of("x", "bad"), "x")).isEmpty();
    }

    @Test
    void parsesDatesTimesAndCalculatesDailyAndWeeklyNextOccurrence() {
        assertThat(AgentToolPayloads.dateTime(Map.of(), "x")).isNotNull();
        assertThat(AgentToolPayloads.dateTime(
                Map.of("x", "2026-07-30 08:30:00"), "x"
        )).isEqualTo(LocalDateTime.of(2026, 7, 30, 8, 30));
        assertThat(AgentToolPayloads.dateTime(
                Map.of("x", "2026-07-30T08:30:00"), "x"
        )).isEqualTo(LocalDateTime.of(2026, 7, 30, 8, 30));
        assertThat(AgentToolPayloads.time(Map.of(), "x").toString()).isEqualTo("08:00");

        LocalDateTime mondayNine = LocalDateTime.of(2026, 7, 27, 9, 0);
        assertThat(AgentToolPayloads.remindAt(
                Map.of("remindTime", "08:00", "repeatType", "daily"), mondayNine
        )).isEqualTo(LocalDateTime.of(2026, 7, 28, 8, 0));
        assertThat(AgentToolPayloads.remindAt(
                Map.of("remindTime", "10:00", "repeatType", "weekly", "dayOfWeek", 1), mondayNine
        )).isEqualTo(LocalDateTime.of(2026, 7, 27, 10, 0));
        assertThat(AgentToolPayloads.remindAt(
                Map.of("remindTime", "08:00", "repeatType", "weekly", "dayOfWeek", 1), mondayNine
        )).isEqualTo(LocalDateTime.of(2026, 8, 3, 8, 0));
        assertThat(AgentToolPayloads.remindAt(
                Map.of("remindTime", "10:00", "repeatType", "weekly", "dayOfWeek", 7), mondayNine
        )).isEqualTo(LocalDateTime.of(2026, 8, 2, 10, 0));
    }
}
