package com.ankang.assistant.advice.service;

import com.ankang.assistant.advice.vo.HealthAdviceVO;
import org.springframework.stereotype.Service;

@Service
public class AdviceService {

    public HealthAdviceVO todayAdvice() {
        return new HealthAdviceVO(
                1L,
                "今日建议",
                "今天的健康状态整体平稳，建议保持规律作息，继续记录血压和血糖。",
                "normal"
        );
    }
}
