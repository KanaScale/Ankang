package com.ankang.assistant.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class Knife4jConfig {

    @Bean
    public OpenAPI ankangOpenApi() {
        return new OpenAPI()
                .info(new Info()
                        .title("安康助手 API")
                        .description("健康安全智能助手后端接口文档")
                        .version("0.1.0"));
    }
}
