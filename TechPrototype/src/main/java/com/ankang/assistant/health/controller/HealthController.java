package com.ankang.assistant.health.controller;

import com.ankang.assistant.common.Result;
import com.ankang.assistant.health.dto.HealthRecordCreateDTO;
import com.ankang.assistant.health.service.HealthService;
import com.ankang.assistant.health.vo.HealthRecordVO;
import com.ankang.assistant.health.vo.HealthSummaryVO;
import com.ankang.assistant.health.vo.HealthTrendVO;
import com.ankang.assistant.health.vo.PageVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;

@Tag(name = "健康数据模块")
@RestController
@RequestMapping("/api")
public class HealthController {

    private final HealthService healthService;

    public HealthController(HealthService healthService) {
        this.healthService = healthService;
    }

    @Operation(summary = "查询健康记录")
    @GetMapping({"/health/records", "/records"})
    public Result<PageVO<HealthRecordVO>> getRecords(
            @RequestParam(required = false) String type,
            @RequestParam(required = false) @DateTimeFormat(pattern = "yyyy-MM-dd") LocalDate startDate,
            @RequestParam(required = false) @DateTimeFormat(pattern = "yyyy-MM-dd") LocalDate endDate,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        return Result.success(healthService.getRecords(type, startDate, endDate, page, size));
    }

    @Operation(summary = "新增健康记录")
    @PostMapping({"/health/records", "/records"})
    public Result<HealthRecordVO> createRecord(@Valid @RequestBody HealthRecordCreateDTO dto) {
        return Result.success(healthService.createRecord(dto));
    }

    @Operation(summary = "获取健康记录详情")
    @GetMapping("/health/records/{id}")
    public Result<HealthRecordVO> getRecord(@PathVariable Long id) {
        return Result.success(healthService.getRecord(id));
    }

    @Operation(summary = "删除健康记录")
    @DeleteMapping("/health/records/{id}")
    public Result<Void> deleteRecord(@PathVariable Long id) {
        healthService.deleteRecord(id);
        return Result.success();
    }

    @Operation(summary = "首页健康摘要")
    @GetMapping("/health/summary")
    public Result<HealthSummaryVO> getSummary() {
        return Result.success(healthService.getSummary());
    }

    @Operation(summary = "健康趋势")
    @GetMapping({"/health/trend", "/records/trend"})
    public Result<HealthTrendVO> getTrend(
            @RequestParam String type,
            @RequestParam(required = false) Integer days,
            @RequestParam(required = false) String range
    ) {
        return Result.success(healthService.getTrend(type, days, range));
    }
}
