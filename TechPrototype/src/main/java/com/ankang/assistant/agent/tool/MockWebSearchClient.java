package com.ankang.assistant.agent.tool;

import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.List;

@Component
public class MockWebSearchClient implements WebSearchClient {

    @Override
    public List<WebSearchResult> search(String query, int maxResults) {
        if (query == null || query.isBlank() || maxResults <= 0) {
            return List.of();
        }
        List<WebSearchResult> results = new ArrayList<>();
        String normalized = query.trim();
        if (normalized.contains("高血压") || normalized.contains("血压")) {
            results.add(new WebSearchResult(
                    "高血压健康管理科普",
                    "https://example.com/health/hypertension-guide",
                    "高血压管理通常强调家庭血压监测、规律服药、限盐、运动和定期复诊；具体诊疗方案应由医生结合个体情况判断。",
                    "web_search"
            ));
            results.add(new WebSearchResult(
                    "家庭血压测量注意事项",
                    "https://example.com/health/blood-pressure-home",
                    "家庭测血压建议固定时间、安静休息后测量，并记录多日趋势，单次读数不能直接作为诊断依据。",
                    "web_search"
            ));
        } else if (normalized.contains("药") || normalized.contains("副作用") || normalized.contains("禁忌")) {
            results.add(new WebSearchResult(
                    "用药安全基础提醒",
                    "https://example.com/health/medication-safety",
                    "药物剂量、停药、换药和联合用药需要遵医嘱；出现疑似严重不良反应时应及时联系医生。",
                    "web_search"
            ));
            results.add(new WebSearchResult(
                    "药品不良反应科普",
                    "https://example.com/health/drug-side-effects",
                    "不同药品的不良反应和禁忌差异较大，应以药品说明书和医生建议为准。",
                    "web_search"
            ));
        } else {
            results.add(new WebSearchResult(
                    "健康问答资料摘要",
                    "https://example.com/health/general-advice",
                    "健康建议应结合年龄、基础病、近期指标和症状严重程度判断；信息不足时建议补充记录或就医咨询。",
                    "web_search"
            ));
            results.add(new WebSearchResult(
                    "慢病日常管理科普",
                    "https://example.com/health/chronic-care",
                    "慢病管理通常包括规律监测、生活方式调整、遵医嘱用药和定期复查。",
                    "web_search"
            ));
        }
        return results.stream().limit(maxResults).toList();
    }
}
