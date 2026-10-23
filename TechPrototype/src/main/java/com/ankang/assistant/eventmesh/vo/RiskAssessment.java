package com.ankang.assistant.eventmesh.vo;

import java.util.List;

public record RiskAssessment(String level, int score, String summary, List<String> reasons) {
}
