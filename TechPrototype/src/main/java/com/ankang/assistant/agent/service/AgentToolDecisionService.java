package com.ankang.assistant.agent.service;

import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class AgentToolDecisionService {

    private static final List<String> WEB_SEARCH_KEYWORDS = List.of(
            "最新", "最近", "现在", "今年", "指南", "政策", "新闻", "查询", "搜索",
            "文献", "依据", "来源", "药品", "副作用", "禁忌", "用法", "医保", "医院"
    );

    public boolean shouldUseWebSearch(String message) {
        if (message == null || message.isBlank()) {
            return false;
        }
        return WEB_SEARCH_KEYWORDS.stream().anyMatch(message::contains);
    }
}
