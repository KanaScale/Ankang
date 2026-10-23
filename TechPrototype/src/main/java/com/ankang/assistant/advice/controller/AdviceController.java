package com.ankang.assistant.advice.controller;

import com.ankang.assistant.advice.service.AdviceService;
import com.ankang.assistant.advice.vo.HealthAdviceVO;
import com.ankang.assistant.common.Result;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "健康建议模块")
@RestController
@RequestMapping("/api/advice")
public class AdviceController {

    private final AdviceService adviceService;

    public AdviceController(AdviceService adviceService) {
        this.adviceService = adviceService;
    }

    @Operation(summary = "今日健康建议")
    @GetMapping("/today")
    public Result<HealthAdviceVO> todayAdvice() {
        return Result.success(adviceService.todayAdvice());
    }
}
