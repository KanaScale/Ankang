package com.ankang.assistant.agent.gms;

import com.ankang.assistant.agent.config.AgentProperties;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;

class HttpGmsMemoryClientTest {

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    void writesAndReadsThroughGmsHttpContract() throws Exception {
        CountDownLatch writeLatch = new CountDownLatch(1);
        AtomicReference<JsonNode> writePayload = new AtomicReference<>();

        HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/memories", exchange -> {
            writePayload.set(objectMapper.readTree(exchange.getRequestBody()));
            writeJson(exchange, 200, "{\"status\":\"ok\"}");
            writeLatch.countDown();
        });
        server.createContext("/search", exchange -> {
            JsonNode request = objectMapper.readTree(exchange.getRequestBody());
            assertThat(request.path("user_id").asText()).isEqualTo("42");
            assertThat(request.path("query").asText()).isEqualTo("开会前要准备什么？");
            assertThat(request.path("limit").asInt()).isEqualTo(3);
            writeJson(exchange, 200, """
                    {
                      "status": "ok",
                      "results": [
                        {
                          "memory": "用户在会议场景中持续关注 Project X",
                          "metadata": {
                            "data_type": "subconscious_insight",
                            "source_app": "SubconsciousMiner"
                          },
                          "score": 0.91
                        }
                      ]
                    }
                    """);
        });
        server.start();
        try {
            AgentProperties properties = new AgentProperties();
            AgentProperties.Gms gms = properties.getGms();
            gms.setEnabled(true);
            gms.setBaseUrl("http://127.0.0.1:" + server.getAddress().getPort());
            gms.setReadLimit(3);

            HttpGmsMemoryClient client = new HttpGmsMemoryClient(properties, objectMapper);

            client.addMemoryAsync(
                    42L,
                    "AnkangAgentChat",
                    "我开会前总会看 Project X 的资料。",
                    "conversation",
                    List.of("agent_chat", "patient")
            );

            assertThat(writeLatch.await(2, TimeUnit.SECONDS)).isTrue();
            assertThat(writePayload.get().path("user_id").asText()).isEqualTo("42");
            assertThat(writePayload.get().path("source_app").asText()).isEqualTo("AnkangAgentChat");
            assertThat(writePayload.get().path("content").asText()).contains("Project X");
            assertThat(writePayload.get().path("data_type").asText()).isEqualTo("conversation");
            assertThat(writePayload.get().path("context_tags").get(0).asText()).isEqualTo("agent_chat");

            List<GmsMemoryItem> memories = client.searchMemories(42L, "开会前要准备什么？");

            assertThat(memories).hasSize(1);
            assertThat(memories.get(0).content()).contains("Project X");
            assertThat(memories.get(0).dataType()).isEqualTo("subconscious_insight");
            assertThat(memories.get(0).sourceApp()).isEqualTo("SubconsciousMiner");
            assertThat(memories.get(0).score()).isEqualTo(0.91);
        } finally {
            server.stop(0);
        }
    }

    @Test
    void disabledInvalidAndAlternateSearchResultsAreHandledSafely() {
        AgentProperties disabledProperties = new AgentProperties();
        HttpGmsMemoryClient disabled = new HttpGmsMemoryClient(disabledProperties, objectMapper);
        disabled.addMemoryAsync(null, null, null, null, null);
        assertThat(disabled.searchMemories(null, "query")).isEmpty();
        assertThat(disabled.searchMemories(1L, " ")).isEmpty();

        @SuppressWarnings("unchecked")
        List<GmsMemoryItem> notArray = ReflectionTestUtils.invokeMethod(
                disabled, "parseSearchResults", "{\"results\":{}}"
        );
        assertThat(notArray).isEmpty();
        @SuppressWarnings("unchecked")
        List<GmsMemoryItem> alternate = ReflectionTestUtils.invokeMethod(
                disabled, "parseSearchResults", """
                        {"results":[
                          {"content":" first ", "metadata":{"dataType":"fact","sourceApp":"app"}},
                          {"text":"second", "metadata":{"agentId":"agent"}, "score":"bad"},
                          {"memory":" ", "metadata":{}}
                        ]}
                        """
        );
        assertThat(alternate).hasSize(2);
        assertThat(alternate.get(0).content()).isEqualTo("first");
        assertThat(alternate.get(1).score()).isNull();
        @SuppressWarnings("unchecked")
        List<GmsMemoryItem> malformed = ReflectionTestUtils.invokeMethod(
                disabled, "parseSearchResults", "{"
        );
        assertThat(malformed).isEmpty();

        assertThat((String) ReflectionTestUtils.invokeMethod(
                disabled, "firstText", null, new String[]{"a"}
        )).isNull();
    }

    @Test
    void coversWriteGateHttpFailuresTrailingSlashAndParserEdgeCases() throws Exception {
        CountDownLatch writeLatch = new CountDownLatch(1);
        HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/memories", exchange -> {
            writeJson(exchange, 503, "{\"status\":\"unavailable\"}");
            writeLatch.countDown();
        });
        server.createContext("/search", exchange ->
                writeJson(exchange, 500, "{\"status\":\"failed\"}"));
        server.start();
        try {
            AgentProperties properties = new AgentProperties();
            AgentProperties.Gms gms = properties.getGms();
            gms.setEnabled(true);
            gms.setWriteEnabled(false);
            gms.setBaseUrl("http://127.0.0.1:" + server.getAddress().getPort() + "/");
            HttpGmsMemoryClient client = new HttpGmsMemoryClient(properties, objectMapper);

            client.addMemoryAsync(1L, "app", "content", "fact", List.of());
            assertThat(writeLatch.await(100, TimeUnit.MILLISECONDS)).isFalse();

            gms.setWriteEnabled(true);
            client.addMemoryAsync(1L, " ", " content ", " ", null);
            assertThat(writeLatch.await(2, TimeUnit.SECONDS)).isTrue();
            assertThat(client.searchMemories(1L, " query ")).isEmpty();

            assertThat((String) ReflectionTestUtils.invokeMethod(
                    client, "firstText", objectMapper.createObjectNode(), (Object) null
            )).isNull();
            assertThat((String) ReflectionTestUtils.invokeMethod(
                    client, "firstText", objectMapper.readTree("{\"a\":\" \",\"b\":\"value\"}"),
                    new String[]{"a", "b"}
            )).isEqualTo("value");

            @SuppressWarnings("unchecked")
            List<GmsMemoryItem> numericScore = ReflectionTestUtils.invokeMethod(
                    client, "parseSearchResults",
                    "{\"results\":[{\"memory\":\"m\",\"score\":0,\"metadata\":{}}]}"
            );
            assertThat(numericScore).singleElement().extracting(GmsMemoryItem::score).isEqualTo(0.0);
        } finally {
            server.stop(0);
        }
    }

    private static void writeJson(com.sun.net.httpserver.HttpExchange exchange, int status, String body) throws IOException {
        byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "application/json");
        exchange.sendResponseHeaders(status, bytes.length);
        exchange.getResponseBody().write(bytes);
        exchange.close();
    }
}
