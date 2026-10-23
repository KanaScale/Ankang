package com.ankang.assistant.advice.vo;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "健康建议")
public record HealthAdviceVO(
        Long id,
        String title,
        String content,
        String level
) {
}
