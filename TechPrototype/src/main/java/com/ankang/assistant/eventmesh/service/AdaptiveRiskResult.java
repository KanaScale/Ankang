package com.ankang.assistant.eventmesh.service;

import java.util.List;

/**
 * 个体化算法输出。
 *
 * @param score        个体基线、趋势和联合异常产生的总增量
 * @param currentScore 本次触发记录自身产生的增量
 * @param reasons      面向用户的可解释原因
 */
public record AdaptiveRiskResult(int score, int currentScore, List<String> reasons) {

    static AdaptiveRiskResult none() {
        return new AdaptiveRiskResult(0, 0, List.of());
    }
}
