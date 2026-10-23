package com.ankang.assistant.emergency.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.MissingNode;
import com.fasterxml.jackson.databind.node.NullNode;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.client.RestClient;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class NearbyHospitalServiceBranchCoverageTest {

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    void coversConstructorAndEveryCoordinateBoundary() {
        NearbyHospitalService nullKey = new NearbyHospitalService(RestClient.builder(), null);
        NearbyHospitalService trimmedKey = new NearbyHospitalService(RestClient.builder(), " key ");
        assertThat((String) ReflectionTestUtils.getField(nullKey, "webKey")).isEmpty();
        assertThat((String) ReflectionTestUtils.getField(trimmedKey, "webKey")).isEqualTo("key");

        invoke(trimmedKey, "validateCoordinates", -90d, -180d);
        invoke(trimmedKey, "validateCoordinates", 90d, 180d);
        for (double latitude : new double[]{Double.NaN, -91d, 91d}) {
            assertThatThrownBy(() -> invoke(trimmedKey, "validateCoordinates", latitude, 0d))
                    .isInstanceOf(IllegalArgumentException.class);
        }
        for (double longitude : new double[]{Double.POSITIVE_INFINITY, -181d, 181d}) {
            assertThatThrownBy(() -> invoke(trimmedKey, "validateCoordinates", 0d, longitude))
                    .isInstanceOf(IllegalArgumentException.class);
        }
    }

    @Test
    void coversAmapResponseNullFailureAndSuccess() throws Exception {
        NearbyHospitalService service = service();
        assertThatThrownBy(() -> invoke(service, "ensureAmapSuccess", null, "test"))
                .isInstanceOf(IllegalStateException.class);
        JsonNode failure = objectMapper.readTree("{\"status\":\"0\",\"info\":\"bad\"}");
        assertThatThrownBy(() -> invoke(service, "ensureAmapSuccess", failure, "test"))
                .isInstanceOf(IllegalStateException.class);
        invoke(service, "ensureAmapSuccess", objectMapper.readTree("{\"status\":\"1\"}"), "test");

        assertThat(service.parseSearchResponse(null, 500).hospitals()).isEmpty();
        assertThat(service.parseSearchResponse(objectMapper.readTree("{\"pois\":{}}"), 500).hospitals()).isEmpty();
        JsonNode response = objectMapper.readTree("""
                {"pois":[
                  {"name":"","location":"1,2","distance":"1"},
                  {"name":"A","location":"","distance":""},
                  {"name":"B","location":"invalid","distance":"bad"},
                  {"name":"C","location":"120.1,30.2","distance":"1500"}
                ]}
                """);
        var result = service.parseSearchResponse(response, 2000);
        assertThat(result.hospitals()).hasSize(3);
        assertThat(result.hospitals().get(0).distanceMeters()).isNull();
        assertThat(result.hospitals().get(2).distance()).isEqualTo("1.5km");
    }

    @Test
    void coversTextArrayAndScalarVariants() {
        NearbyHospitalService service = service();
        assertThat((String) invoke(service, "text", (Object) null)).isEmpty();
        assertThat((String) invoke(service, "text", NullNode.instance)).isEmpty();
        assertThat((String) invoke(service, "text", MissingNode.getInstance())).isEmpty();
        ArrayNode empty = objectMapper.createArrayNode();
        assertThat((String) invoke(service, "text", empty)).isEmpty();
        ArrayNode populated = objectMapper.createArrayNode().add("first").add("second");
        assertThat((String) invoke(service, "text", populated)).isEqualTo("first");
        assertThat((String) invoke(service, "text", objectMapper.getNodeFactory().textNode("value")))
                .isEqualTo("value");
    }

    private NearbyHospitalService service() {
        return new NearbyHospitalService(RestClient.builder(), "key");
    }

    private <T> T invoke(NearbyHospitalService service, String name, Object... args) {
        return ReflectionTestUtils.invokeMethod(service, name, args);
    }
}
