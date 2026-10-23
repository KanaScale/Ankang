package com.ankang.assistant.emergency.service;

import com.ankang.assistant.emergency.vo.NearbyHospitalVO;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.client.RestClient;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.http.MediaType;
import org.springframework.http.client.ClientHttpRequestFactory;
import org.springframework.web.client.RestClientException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withServerError;
import static org.hamcrest.Matchers.containsString;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class NearbyHospitalServiceTest {

    private final NearbyHospitalService service = new NearbyHospitalService(
            RestClient.builder(), "test-key"
    );

    @Test
    void mapsAmapPoiResponseWithoutAmbiguousCoordinateOrder() throws Exception {
        JsonNode response = new ObjectMapper().readTree("""
                {
                  "status": "1",
                  "pois": [{
                    "id": "B001",
                    "name": "市人民医院",
                    "address": "人民路100号",
                    "distance": "1250",
                    "tel": "021-12345678",
                    "location": "121.473700,31.230400",
                    "type": "医疗保健服务;综合医院"
                  }]
                }
                """);

        NearbyHospitalVO result = service.parseSearchResponse(response, 5000);

        assertThat(result.source()).isEqualTo("amap");
        assertThat(result.coordinateSystem()).isEqualTo("gcj02");
        assertThat(result.hospitals()).hasSize(1);
        NearbyHospitalVO.HospitalVO hospital = result.hospitals().get(0);
        assertThat(hospital.name()).isEqualTo("市人民医院");
        assertThat(hospital.distanceMeters()).isEqualTo(1250);
        assertThat(hospital.distance()).isEqualTo("1.3km");
        assertThat(hospital.latitude()).isEqualTo(31.230400);
        assertThat(hospital.longitude()).isEqualTo(121.473700);
    }

    @Test
    void rejectsCoordinatesOutsideWgs84RangeBeforeCallingAmap() {
        assertThatThrownBy(() -> service.findNearby(91, 121.47, 5000))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("latitude");
    }

    @Test
    void parsingToleratesMissingMalformedAndArrayFields() throws Exception {
        JsonNode response = new ObjectMapper().readTree("""
                {
                  "status": "1",
                  "pois": [
                    {"name": "", "location": "121,31", "distance": "10"},
                    {"id": "2", "name": "A", "address": ["first", "second"],
                     "location": "", "distance": ""},
                    {"id": "3", "name": "B", "address": null,
                     "location": "bad", "distance": "not-a-number"},
                    {"id": "4", "name": "C", "location": "x,y", "distance": "999"}
                  ]
                }
                """);

        NearbyHospitalVO result = service.parseSearchResponse(response, 100);

        assertThat(result.hospitals()).hasSize(3);
        assertThat(result.hospitals().get(0).address()).isEqualTo("first");
        assertThat(result.hospitals().get(0).distanceMeters()).isNull();
        assertThat(result.hospitals().get(2).distance()).isEqualTo("999m");
        assertThat(service.parseSearchResponse(null, 200).hospitals()).isEmpty();
    }

    @Test
    void privateValidationAndFormattingHelpersCoverAllBoundaries() throws Exception {
        ReflectionTestUtils.invokeMethod(service, "validateCoordinates", -90.0, -180.0);
        ReflectionTestUtils.invokeMethod(service, "validateCoordinates", 90.0, 180.0);
        assertThatThrownBy(() -> ReflectionTestUtils.invokeMethod(
                service, "validateCoordinates", 0.0, 181.0
        )).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> ReflectionTestUtils.invokeMethod(
                service, "validateCoordinates", Double.NaN, 0.0
        )).isInstanceOf(IllegalArgumentException.class);

        assertThat((String) ReflectionTestUtils.invokeMethod(service, "formatDistance", (Object) null))
                .isNotBlank();
        assertThat((String) ReflectionTestUtils.invokeMethod(service, "formatDistance", 1000))
                .isEqualTo("1.0km");

        ObjectMapper mapper = new ObjectMapper();
        assertThatThrownBy(() -> ReflectionTestUtils.invokeMethod(
                service, "ensureAmapSuccess", null, "test"
        )).isInstanceOf(IllegalStateException.class);
        assertThatThrownBy(() -> ReflectionTestUtils.invokeMethod(
                service, "ensureAmapSuccess", mapper.readTree("{\"status\":\"0\",\"info\":\"bad\"}"), "test"
        )).isInstanceOf(IllegalStateException.class);
        ReflectionTestUtils.invokeMethod(
                service, "ensureAmapSuccess", mapper.readTree("{\"status\":\"1\"}"), "test"
        );
    }

    @Test
    void findNearbyExecutesCoordinateConversionAndSearchWithRadiusClamping() {
        RestClient.Builder builder = mock(RestClient.Builder.class);
        RestClient rest = mock(RestClient.class);
        @SuppressWarnings("rawtypes")
        RestClient.RequestHeadersUriSpec uriSpec = mock(RestClient.RequestHeadersUriSpec.class);
        RestClient.RequestHeadersSpec<?> headers = mock(RestClient.RequestHeadersSpec.class);
        RestClient.ResponseSpec response = mock(RestClient.ResponseSpec.class);
        when(builder.baseUrl(anyString())).thenReturn(builder);
        when(builder.requestFactory(any(ClientHttpRequestFactory.class))).thenReturn(builder);
        when(builder.build()).thenReturn(rest);
        when(rest.get()).thenReturn(uriSpec);
        when(uriSpec.uri(any(java.util.function.Function.class))).thenReturn(headers);
        when(headers.retrieve()).thenReturn(response);
        try {
            when(response.body(JsonNode.class)).thenReturn(
                    new ObjectMapper().readTree(
                            "{\"status\":\"1\",\"locations\":\"121.500000,31.200000;ignored\"}"
                    ),
                    new ObjectMapper().readTree(
                            "{\"status\":\"1\",\"pois\":[{\"id\":\"1\",\"name\":\"Hospital\",\"location\":\"121.5,31.2\",\"distance\":\"10\"}]}"
                    )
            );
        } catch (Exception ex) {
            throw new AssertionError(ex);
        }
        NearbyHospitalService live = new NearbyHospitalService(builder, " web-key ");

        NearbyHospitalVO result = live.findNearby(31.2, 121.5, 100);

        assertThat(result.radiusMeters()).isEqualTo(500);
        assertThat(result.hospitals()).hasSize(1);
    }

    @Test
    void findNearbyCoversMissingKeyAndRemoteTransportFailure() {
        assertThatThrownBy(() -> new NearbyHospitalService(RestClient.builder(), " ")
                .findNearby(31.2, 121.5, 500))
                .isInstanceOf(IllegalStateException.class);

        RestClient.Builder builder = mock(RestClient.Builder.class);
        RestClient rest = mock(RestClient.class);
        @SuppressWarnings("rawtypes")
        RestClient.RequestHeadersUriSpec uriSpec = mock(RestClient.RequestHeadersUriSpec.class);
        RestClient.RequestHeadersSpec<?> headers = mock(RestClient.RequestHeadersSpec.class);
        RestClient.ResponseSpec response = mock(RestClient.ResponseSpec.class);
        when(builder.baseUrl(anyString())).thenReturn(builder);
        when(builder.requestFactory(any(ClientHttpRequestFactory.class))).thenReturn(builder);
        when(builder.build()).thenReturn(rest);
        when(rest.get()).thenReturn(uriSpec);
        when(uriSpec.uri(any(java.util.function.Function.class))).thenReturn(headers);
        when(headers.retrieve()).thenReturn(response);
        when(response.body(JsonNode.class)).thenThrow(new RestClientException("down") {});
        NearbyHospitalService live = new NearbyHospitalService(builder, "key");
        assertThatThrownBy(() -> live.findNearby(31.2, 121.5, 50_000))
                .isInstanceOf(IllegalStateException.class);
    }
}
