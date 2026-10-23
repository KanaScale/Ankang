package com.ankang.assistant.report.controller;

import com.ankang.assistant.common.Result;
import com.ankang.assistant.report.service.ReportService;
import com.ankang.assistant.report.vo.WeeklyHealthReportVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;

@Tag(name = "健康报告模块")
@RestController
@RequestMapping("/api/reports")
public class ReportController {

    private final ReportService reportService;

    public ReportController(ReportService reportService) {
        this.reportService = reportService;
    }

    @Operation(summary = "周健康报告")
    @GetMapping("/weekly")
    public Result<WeeklyHealthReportVO> weeklyReport(
            @RequestParam(required = false) @DateTimeFormat(pattern = "yyyy-MM-dd") LocalDate weekStart
    ) {
        return Result.success(reportService.weeklyReport(weekStart));
    }
}
