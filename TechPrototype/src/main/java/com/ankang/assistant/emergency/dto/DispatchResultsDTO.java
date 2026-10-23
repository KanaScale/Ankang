package com.ankang.assistant.emergency.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;

import java.util.List;

public record DispatchResultsDTO(
        @NotEmpty List<@Valid DispatchAttemptDTO> attempts
) {
}
