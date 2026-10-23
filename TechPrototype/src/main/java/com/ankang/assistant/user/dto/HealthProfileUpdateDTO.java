package com.ankang.assistant.user.dto;

import java.math.BigDecimal;
import java.util.List;

public record HealthProfileUpdateDTO(
        BigDecimal height,
        BigDecimal weight,
        List<String> chronicDiseases,
        String allergies,
        String medicalHistory,
        String device
) {
}
