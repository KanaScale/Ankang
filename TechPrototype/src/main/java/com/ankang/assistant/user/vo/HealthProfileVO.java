package com.ankang.assistant.user.vo;

import java.math.BigDecimal;
import java.util.List;

public record HealthProfileVO(
        BigDecimal height,
        BigDecimal weight,
        BigDecimal bmi,
        List<String> chronicDiseases,
        String allergies,
        String medicalHistory,
        String device
) {
}
