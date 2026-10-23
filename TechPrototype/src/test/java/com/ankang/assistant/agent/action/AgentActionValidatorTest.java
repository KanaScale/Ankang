package com.ankang.assistant.agent.action;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class AgentActionValidatorTest {

    private final AgentActionValidator validator = new AgentActionValidator();
    private final AgentActionExecutionContext patient =
            new AgentActionExecutionContext("a", 1L, 1L, 2L, "PATIENT");

    @Test
    void validatesCreationRoleAndNoPayloadActions() {
        assertThatThrownBy(() -> validator.validateForCreation(null, "PATIENT"))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> validator.validateForCreation(
                new AgentActionRequest(null, "x", "x", false, Map.of()), "PATIENT"
        )).isInstanceOf(IllegalArgumentException.class);
        for (AgentActionType type : List.of(
                AgentActionType.EVALUATE_HEALTH_RISK,
                AgentActionType.NOTIFY_FAMILY_PREVIEW
        )) {
            assertThatCode(() -> validator.validateForCreation(
                    new AgentActionRequest(type, "x", "x", false, null), "CAREGIVER"
            )).doesNotThrowAnyException();
        }
        for (AgentActionType forbidden : List.of(
                AgentActionType.RECORD_HEALTH_DATA, AgentActionType.CREATE_HEALTH_PLAN
        )) {
            assertThatThrownBy(() -> validator.validateForCreation(
                    new AgentActionRequest(forbidden, "x", "x", true, Map.of()), "CAREGIVER"
            )).isInstanceOf(IllegalArgumentException.class);
        }
    }

    @Test
    void healthPayloadAcceptsAllValueTypesAndRejectsInvalidRanges() {
        Map<String, Object> valid = Map.of(
                "systolic", "120",
                "diastolic", 80L,
                "heartRate", new BigDecimal("70"),
                "bloodGlucose", 5.5d,
                "weight", "65.2",
                "recordedAt", LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"))
        );
        assertThatCode(() -> validator.validateForExecution(
                AgentActionType.RECORD_HEALTH_DATA, valid, patient
        )).doesNotThrowAnyException();
        assertThatCode(() -> validator.validateForExecution(
                AgentActionType.RECORD_HEALTH_DATA,
                Map.of("heartRate", "70", "recordedAt", LocalDateTime.now().toString()), patient
        )).doesNotThrowAnyException();

        for (Map<String, Object> invalid : List.<Map<String, Object>>of(
                Map.of(),
                Map.of("systolic", 120),
                Map.of("systolic", 70, "diastolic", 80),
                Map.of("heartRate", 20),
                Map.of("bloodGlucose", 50),
                Map.of("weight", 10),
                Map.of("heartRate", 70, "recordedAt", LocalDateTime.now().plusHours(1).toString())
        )) {
            assertThatThrownBy(() -> validator.validateForExecution(
                    AgentActionType.RECORD_HEALTH_DATA, invalid, patient
            )).isInstanceOf(IllegalArgumentException.class);
        }
    }

    @Test
    void planPayloadValidatesShapeFieldsTimeAndWeekday() {
        assertThatCode(() -> validator.validateForExecution(
                AgentActionType.CREATE_HEALTH_PLAN, Map.of(), patient
        )).doesNotThrowAnyException();
        assertThatCode(() -> validator.validateForExecution(
                AgentActionType.CREATE_HEALTH_PLAN,
                Map.of("reminders", List.of(Map.of(
                        "title", "Medicine", "type", "medicine", "repeatType", "weekly",
                        "remindTime", "08:30", "dayOfWeek", "7"
                ))), patient
        )).doesNotThrowAnyException();

        for (Object invalidReminder : List.of(
                "bad",
                Map.of("title", ""),
                Map.of("title", "x".repeat(129)),
                Map.of("title", "x", "type", "invalid"),
                Map.of("title", "x", "repeatType", "monthly"),
                Map.of("title", "x", "remindTime", "8:3"),
                Map.of("title", "x", "dayOfWeek", 0)
        )) {
            assertThatThrownBy(() -> validator.validateForExecution(
                    AgentActionType.CREATE_HEALTH_PLAN,
                    Map.of("reminders", List.of(invalidReminder)), patient
            )).isInstanceOf(IllegalArgumentException.class);
        }
    }

    @Test
    void coordinatePayloadSupportsAbsentAndBoundsButRejectsPartialOrOutOfRange() {
        for (AgentActionType type : List.of(
                AgentActionType.SEARCH_NEARBY_HOSPITALS, AgentActionType.PREPARE_SOS_PLAN
        )) {
            assertThatCode(() -> validator.validateForExecution(type, Map.of(), patient))
                    .doesNotThrowAnyException();
            assertThatCode(() -> validator.validateForExecution(
                    type, Map.of("latitude", "-90", "longitude", 180), patient
            )).doesNotThrowAnyException();
            for (Map<String, Object> invalid : List.<Map<String, Object>>of(
                    Map.of("latitude", 1),
                    Map.of("longitude", 1),
                    Map.of("latitude", -91, "longitude", 0),
                    Map.of("latitude", 0, "longitude", 181)
            )) {
                assertThatThrownBy(() -> validator.validateForExecution(type, invalid, patient))
                        .isInstanceOf(IllegalArgumentException.class);
            }
        }
    }

    @Test
    void coversOppositeShortCircuitSidesAndOptionalPayloadShapes() {
        assertThatCode(() -> validator.validateForExecution(
                AgentActionType.CREATE_HEALTH_PLAN, Map.of("reminders", "not-a-list"), patient
        )).doesNotThrowAnyException();
        assertThatCode(() -> validator.validateForExecution(
                AgentActionType.RECORD_HEALTH_DATA,
                Map.of("heartRate", 70, "recordedAt", " "), patient
        )).doesNotThrowAnyException();
        assertThatCode(() -> validator.validateForExecution(
                AgentActionType.RECORD_HEALTH_DATA,
                Map.of("heartRate", 70, "recordedAt", 123), patient
        )).doesNotThrowAnyException();

        for (Map<String, Object> invalid : List.<Map<String, Object>>of(
                Map.of("diastolic", 80),
                Map.of("systolic", 301, "diastolic", 80),
                Map.of("systolic", 120, "diastolic", 29),
                Map.of("systolic", 120, "diastolic", 201),
                Map.of("systolic", 80, "diastolic", 80),
                Map.of("heartRate", 221),
                Map.of("bloodGlucose", 0),
                Map.of("weight", 301)
        )) {
            assertThatThrownBy(() -> validator.validateForExecution(
                    AgentActionType.RECORD_HEALTH_DATA, invalid, patient
            )).isInstanceOf(IllegalArgumentException.class);
        }

        assertThatThrownBy(() -> validator.validateForExecution(
                AgentActionType.CREATE_HEALTH_PLAN,
                Map.of("reminders", List.of(Map.of("title", "x", "dayOfWeek", 8))), patient
        )).isInstanceOf(IllegalArgumentException.class);
    }
}
