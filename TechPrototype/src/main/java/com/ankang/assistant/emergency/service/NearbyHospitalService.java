package com.ankang.assistant.emergency.service;

import com.ankang.assistant.emergency.vo.NearbyHospitalVO;
import com.fasterxml.jackson.databind.JsonNode;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.net.http.HttpClient;
import java.time.Duration;

/** 使用服务端高德 Web Key 查询附近医院，避免把密钥暴露在 APK 中。 */
@Service
public class NearbyHospitalService {

    private static final int MIN_RADIUS_METERS = 500;
    private static final int MAX_RADIUS_METERS = 20_000;
    private static final int RESULT_LIMIT = 10;

    private final RestClient restClient;
    private final String webKey;

    public NearbyHospitalService(
            RestClient.Builder restClientBuilder,
            @Value("${map.amap.web-key:}") String webKey
    ) {
        HttpClient httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(3))
                .build();
        JdkClientHttpRequestFactory requestFactory = new JdkClientHttpRequestFactory(httpClient);
        requestFactory.setReadTimeout(Duration.ofSeconds(5));
        this.restClient = restClientBuilder
                .baseUrl("https://restapi.amap.com")
                .requestFactory(requestFactory)
                .build();
        this.webKey = webKey == null ? "" : webKey.trim();
    }

    public NearbyHospitalVO findNearby(double latitude, double longitude, int radiusMeters) {
        validateCoordinates(latitude, longitude);
        int effectiveRadius = Math.max(MIN_RADIUS_METERS, Math.min(radiusMeters, MAX_RADIUS_METERS));
        if (webKey.isBlank()) {
            throw new IllegalStateException("附近医院服务尚未配置 AMAP_WEB_KEY");
        }

        try {
            String amapLocation = convertGpsToAmap(latitude, longitude);
            JsonNode response = restClient.get()
                    .uri(uriBuilder -> uriBuilder
                            .path("/v3/place/around")
                            .queryParam("key", webKey)
                            .queryParam("location", amapLocation)
                            .queryParam("keywords", "医院")
                            .queryParam("types", "090000")
                            .queryParam("radius", effectiveRadius)
                            .queryParam("sortrule", "distance")
                            .queryParam("offset", RESULT_LIMIT)
                            .queryParam("page", 1)
                            .queryParam("extensions", "all")
                            .queryParam("output", "JSON")
                            .build())
                    .retrieve()
                    .body(JsonNode.class);
            ensureAmapSuccess(response, "医院检索");
            return parseSearchResponse(response, effectiveRadius);
        } catch (RestClientException exception) {
            throw new IllegalStateException("附近医院服务暂时不可用，请稍后重试", exception);
        }
    }

    private String convertGpsToAmap(double latitude, double longitude) {
        String gpsLocation = String.format(Locale.ROOT, "%.6f,%.6f", longitude, latitude);
        JsonNode response = restClient.get()
                .uri(uriBuilder -> uriBuilder
                        .path("/v3/assistant/coordinate/convert")
                        .queryParam("key", webKey)
                        .queryParam("locations", gpsLocation)
                        .queryParam("coordsys", "gps")
                        .queryParam("output", "JSON")
                        .build())
                .retrieve()
                .body(JsonNode.class);
        ensureAmapSuccess(response, "坐标转换");
        String converted = text(response == null ? null : response.get("locations"));
        if (converted.isBlank() || !converted.contains(",")) {
            throw new IllegalStateException("高德坐标转换未返回有效位置");
        }
        return converted.split(";")[0];
    }

    NearbyHospitalVO parseSearchResponse(JsonNode response, int radiusMeters) {
        List<NearbyHospitalVO.HospitalVO> hospitals = new ArrayList<>();
        JsonNode pois = response == null ? null : response.get("pois");
        if (pois != null && pois.isArray()) {
            for (JsonNode poi : pois) {
                String name = text(poi.get("name"));
                if (name.isBlank()) {
                    continue;
                }
                Double[] location = parseLocation(text(poi.get("location")));
                Integer distanceMeters = integerValue(poi.get("distance"));
                hospitals.add(new NearbyHospitalVO.HospitalVO(
                        text(poi.get("id")),
                        name,
                        text(poi.get("address")),
                        distanceMeters,
                        formatDistance(distanceMeters),
                        text(poi.get("tel")),
                        location[1],
                        location[0],
                        text(poi.get("type")),
                        "amap"
                ));
            }
        }
        return new NearbyHospitalVO("amap", "gcj02", radiusMeters, hospitals);
    }

    private void ensureAmapSuccess(JsonNode response, String operation) {
        if (response == null || !"1".equals(response.path("status").asText())) {
            String info = response == null ? "无响应" : response.path("info").asText("未知错误");
            throw new IllegalStateException("高德" + operation + "失败：" + info);
        }
    }

    private void validateCoordinates(double latitude, double longitude) {
        if (!Double.isFinite(latitude) || latitude < -90 || latitude > 90) {
            throw new IllegalArgumentException("latitude 必须在 -90 到 90 之间");
        }
        if (!Double.isFinite(longitude) || longitude < -180 || longitude > 180) {
            throw new IllegalArgumentException("longitude 必须在 -180 到 180 之间");
        }
    }

    private Double[] parseLocation(String value) {
        if (value.isBlank()) {
            return new Double[]{null, null};
        }
        String[] parts = value.split(",");
        if (parts.length != 2) {
            return new Double[]{null, null};
        }
        try {
            return new Double[]{Double.parseDouble(parts[0]), Double.parseDouble(parts[1])};
        } catch (NumberFormatException ignored) {
            return new Double[]{null, null};
        }
    }

    private Integer integerValue(JsonNode node) {
        String value = text(node);
        if (value.isBlank()) {
            return null;
        }
        try {
            return Integer.parseInt(value);
        } catch (NumberFormatException ignored) {
            return null;
        }
    }

    private String formatDistance(Integer distanceMeters) {
        if (distanceMeters == null) {
            return "距离未知";
        }
        if (distanceMeters < 1000) {
            return distanceMeters + "m";
        }
        return String.format(Locale.ROOT, "%.1fkm", distanceMeters / 1000.0);
    }

    private String text(JsonNode node) {
        if (node == null || node.isNull() || node.isMissingNode()) {
            return "";
        }
        if (node.isArray()) {
            return node.isEmpty() ? "" : node.get(0).asText("");
        }
        return node.asText("");
    }
}
