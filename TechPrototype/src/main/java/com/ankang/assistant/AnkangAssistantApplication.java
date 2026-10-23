package com.ankang.assistant;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@MapperScan({
        "com.ankang.assistant.**.mapper",
        "com.ankang.assistant.agent.action"
})
@SpringBootApplication
public class AnkangAssistantApplication {

    public static void main(String[] args) {
        SpringApplication.run(AnkangAssistantApplication.class, args);
    }
}
