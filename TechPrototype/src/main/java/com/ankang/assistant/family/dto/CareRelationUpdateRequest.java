package com.ankang.assistant.family.dto;

import jakarta.validation.constraints.Size;

public record CareRelationUpdateRequest(
        @Size(max = 32) String relationType,
        @Size(max = 32) String status
) {
}
