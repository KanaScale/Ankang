package com.ankang.assistant.eventmesh.controller;

import com.ankang.assistant.common.Result;
import com.ankang.assistant.config.SecurityUtils;
import com.ankang.assistant.eventmesh.service.HealthEventQueryService;
import com.ankang.assistant.eventmesh.service.HealthEventStreamService;
import com.ankang.assistant.eventmesh.vo.HealthEventVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.util.List;

@Tag(name = "HealthOps Event Mesh")
@RestController
@RequestMapping("/api/health-events")
public class HealthEventController {

    private final HealthEventQueryService queryService;
    private final HealthEventStreamService streamService;

    public HealthEventController(HealthEventQueryService queryService, HealthEventStreamService streamService) {
        this.queryService = queryService;
        this.streamService = streamService;
    }

    @Operation(summary = "查询最近健康事件")
    @GetMapping
    public Result<List<HealthEventVO>> list(@RequestParam(required = false) Integer limit) {
        return Result.success(queryService.list(limit));
    }

    @Operation(summary = "查询健康事件处理时间线")
    @GetMapping("/{eventId}")
    public Result<HealthEventVO> detail(@PathVariable String eventId) {
        return Result.success(queryService.detail(eventId));
    }

    @Operation(summary = "订阅健康风险实时推送")
    @GetMapping(value = "/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter stream() {
        return streamService.subscribe(SecurityUtils.currentUserId());
    }
}
