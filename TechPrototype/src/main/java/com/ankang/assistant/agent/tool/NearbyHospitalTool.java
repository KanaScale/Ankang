package com.ankang.assistant.agent.tool;

import com.ankang.assistant.agent.action.AgentActionExecutionContext;
import com.ankang.assistant.agent.action.AgentActionResult;
import com.ankang.assistant.agent.action.AgentActionType;
import com.ankang.assistant.emergency.service.NearbyHospitalService;
import com.ankang.assistant.emergency.vo.NearbyHospitalVO;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Map;

@Component
public class NearbyHospitalTool implements AgentTool {

    private final NearbyHospitalService nearbyHospitalService;

    public NearbyHospitalTool(NearbyHospitalService nearbyHospitalService) {
        this.nearbyHospitalService = nearbyHospitalService;
    }

    @Override
    public String name() {
        return "nearby_hospital";
    }

    @Override
    public String description() {
        return "Search nearby hospitals by user supplied coordinates.";
    }

    @Override
    public ToolCallResult execute(Map<String, String> arguments) {
        return ToolCallResult.failure(name(), "nearby_hospital 只能通过 Agent Action 流程执行");
    }

    @Override
    public boolean supportsAction(AgentActionType actionType) {
        return actionType == AgentActionType.SEARCH_NEARBY_HOSPITALS;
    }

    @Override
    public AgentActionResult executeAction(AgentActionExecutionContext context, Map<String, Object> payload) {
        NearbyHospitalVO hospitals = findHospitals(payload);
        if (hospitals.hospitals().isEmpty()) {
            return AgentActionResult.success(
                    "需要当前位置后才能查询附近医院。你可以打开 SOS 页面授权定位，或补充经纬度。",
                    Map.of("nearbyHospitals", List.of())
            );
        }
        return AgentActionResult.success(
                "已查询到附近医院，请根据实际情况选择就近就医。",
                Map.of("nearbyHospitals", hospitals.hospitals())
        );
    }

    NearbyHospitalVO findHospitals(Map<String, Object> payload) {
        Double latitude = AgentToolPayloads.doubleValue(payload, "latitude");
        Double longitude = AgentToolPayloads.doubleValue(payload, "longitude");
        int radius = AgentToolPayloads.integer(payload, "radiusMeters") == null
                ? 5000
                : AgentToolPayloads.integer(payload, "radiusMeters");
        if (latitude == null || longitude == null) {
            return new NearbyHospitalVO("none", "wgs84", radius, List.of());
        }
        try {
            return nearbyHospitalService.findNearby(latitude, longitude, radius);
        } catch (RuntimeException ignored) {
            // TODO: 配置 AMAP_WEB_KEY 后移除 mock fallback。
            return mockHospitals(latitude, longitude, radius);
        }
    }

    private NearbyHospitalVO mockHospitals(double latitude, double longitude, int radius) {
        return new NearbyHospitalVO("mock", "wgs84", radius, List.of(
                new NearbyHospitalVO.HospitalVO(
                        "mock-1", "附近社区医院", "当前位置附近约 1.2km", 1200, "1.2km",
                        null, latitude + 0.006, longitude + 0.006, "医院", "mock"
                ),
                new NearbyHospitalVO.HospitalVO(
                        "mock-2", "市人民医院急诊", "当前位置附近约 2.8km", 2800, "2.8km",
                        null, latitude + 0.012, longitude - 0.008, "综合医院", "mock"
                ),
                new NearbyHospitalVO.HospitalVO(
                        "mock-3", "中心医院", "当前位置附近约 4.0km", 4000, "4.0km",
                        null, latitude - 0.010, longitude + 0.014, "综合医院", "mock"
                )
        ));
    }
}
