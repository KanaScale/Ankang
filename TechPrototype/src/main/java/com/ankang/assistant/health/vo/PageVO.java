package com.ankang.assistant.health.vo;

import java.util.List;

public record PageVO<T>(
        List<T> items,
        long total,
        int page,
        int pageSize
) {
}
