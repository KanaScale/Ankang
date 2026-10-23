package com.ankang.assistant.agent.gms;

import com.ankang.assistant.agent.config.AgentProperties;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;

@Service
public class HttpGmsMemoryClient implements GmsMemoryClient {

    private static final Logger log = LoggerFactory.getLogger(HttpGmsMemoryClient.class);

    private final AgentProperties.Gms properties;
    private final ObjectMapper objectMapper;
    private final HttpClient httpClient;

    public HttpGmsMemoryClient(AgentProperties properties, ObjectMapper objectMapper) {
        this.properties = properties.getGms();
        this.objectMapper = objectMapper;
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(timeout())
                .build();
    }

    @Override
    public void addMemoryAsync(
            Long userId,
            String sourceApp,
            String content,
            String dataType,
            List<String> contextTags
    ) {
        if (!properties.isEnabled() || !properties.isWriteEnabled() || userId == null || isBlank(content)) {
            return;
        }
        CompletableFuture.runAsync(() -> addMemory(userId, sourceApp, content, dataType, contextTags));
    }

    @Override
    public List<GmsMemoryItem> searchMemories(Long userId, String query) {
        if (!properties.isEnabled() || userId == null || isBlank(query)) {
            return List.of();
        }

        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("user_id", String.valueOf(userId));
        payload.put("query", query.trim());
        payload.put("limit", properties.getReadLimit());

        try {
            HttpResponse<String> response = post("/search", payload);
            if (!success(response)) {
                log.warn("GMS search failed: status={}, userId={}", response.statusCode(), userId);
                return List.of();
            }
            return parseSearchResults(response.body());
        } catch (RuntimeException ex) {
            log.warn("GMS search unavailable: userId={}, error={}", userId, ex.getMessage());
            return List.of();
        }
    }

    private void addMemory(
            Long userId,
            String sourceApp,
            String content,
            String dataType,
            List<String> contextTags
    ) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("user_id", String.valueOf(userId));
        payload.put("source_app", isBlank(sourceApp) ? "AnkangAgent" : sourceApp.trim());
        payload.put("content", content.trim());
        payload.put("data_type", isBlank(dataType) ? "conversation" : dataType.trim());
        payload.put("context_tags", contextTags == null ? List.of() : contextTags);
        payload.put("timestamp", OffsetDateTime.now(ZoneOffset.UTC).toString());

        try {
            HttpResponse<String> response = post("/memories", payload);
            if (!success(response)) {
                log.warn("GMS write failed: status={}, userId={}", response.statusCode(), userId);
            }
        } catch (RuntimeException ex) {
            log.warn("GMS write unavailable: userId={}, error={}", userId, ex.getMessage());
        }
    }

    private HttpResponse<String> post(String path, Map<String, Object> payload) {
        try {
            String body = objectMapper.writeValueAsString(payload);
            HttpRequest request = HttpRequest.newBuilder(endpoint(path))
                    .timeout(timeout())
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(body, StandardCharsets.UTF_8))
                    .build();
            return httpClient.send(request, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
        } catch (Exception ex) {
            throw new RuntimeException(ex.getMessage(), ex);
        }
    }

    private URI endpoint(String path) {
        String baseUrl = properties.getBaseUrl();
        if (baseUrl.endsWith("/")) {
            baseUrl = baseUrl.substring(0, baseUrl.length() - 1);
        }
        return URI.create(baseUrl + path);
    }

    private Duration timeout() {
        return Duration.ofMillis(properties.getTimeoutMillis());
    }

    private boolean success(HttpResponse<?> response) {
        return response.statusCode() >= 200 && response.statusCode() < 300;
    }

    private List<GmsMemoryItem> parseSearchResults(String body) {
        try {
            JsonNode root = objectMapper.readTree(body);
            JsonNode results = root.path("results");
            if (!results.isArray()) {
                return List.of();
            }

            List<GmsMemoryItem> memories = new ArrayList<>();
            for (JsonNode item : results) {
                String content = firstText(item, "memory", "content", "text");
                if (isBlank(content)) {
                    continue;
                }
                JsonNode metadata = item.path("metadata");
                Double score = item.hasNonNull("score") && item.get("score").isNumber()
                        ? item.get("score").doubleValue()
                        : null;
                memories.add(new GmsMemoryItem(
                        content.trim(),
                        firstText(metadata, "data_type", "dataType"),
                        firstText(metadata, "source_app", "sourceApp", "agent_id", "agentId"),
                        score
                ));
            }
            return memories;
        } catch (Exception ex) {
            log.warn("GMS search response parse failed: error={}", ex.getMessage());
            return List.of();
        }
    }

    private String firstText(JsonNode node, String... fields) {
        if (node == null || node.isMissingNode() || fields == null) {
            return null;
        }
        for (String field : fields) {
            JsonNode value = node.get(field);
            if (value != null && value.isTextual() && !value.asText().isBlank()) {
                return value.asText();
            }
        }
        return null;
    }

    private boolean isBlank(String value) {
        return value == null || value.isBlank();
    }
}
