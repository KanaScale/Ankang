package com.ankang.assistant.test;

import com.ankang.assistant.common.Result;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "测试接口")
@RestController
@RequestMapping("/api/test")
public class TestController {

    @Operation(summary = "后端连通性检查")
    @GetMapping("/ping")
    public Result<String> ping() {
        return Result.success("backend is running");
    }
}
