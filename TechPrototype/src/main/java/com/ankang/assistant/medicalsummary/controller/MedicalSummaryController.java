package com.ankang.assistant.medicalsummary.controller;

import com.ankang.assistant.common.Result;
import com.ankang.assistant.medicalsummary.service.MedicalSummaryService;
import com.ankang.assistant.medicalsummary.vo.MedicalSummaryVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "就医摘要")
@RestController
@RequestMapping("/api/medical-summary")
public class MedicalSummaryController {

    private final MedicalSummaryService medicalSummaryService;

    public MedicalSummaryController(MedicalSummaryService medicalSummaryService) {
        this.medicalSummaryService = medicalSummaryService;
    }

    @Operation(summary = "生成当前用户的结构化就医展示摘要")
    @GetMapping
    public Result<MedicalSummaryVO> generate(
            @RequestParam(required = false, defaultValue = "14") Integer days
    ) {
        return Result.success(medicalSummaryService.generate(days));
    }
}
