package com.ankang.assistant.config;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class InfrastructureConfigCoverageTest {

    @AfterEach
    void clearSecurity() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void redisCacheCoversHitMissCorruptionSerializationAndPatternDeletion() throws Exception {
        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        @SuppressWarnings("unchecked")
        ValueOperations<String, String> values = mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(values);
        RedisCacheSupport cache = new RedisCacheSupport(redis, new ObjectMapper());

        when(values.get("missing")).thenReturn(null);
        assertThat(cache.get("missing", Map.class)).isNull();
        when(values.get("good")).thenReturn("{\"value\":1}");
        assertThat(cache.get("good", Map.class)).containsEntry("value", 1);
        when(values.get("bad")).thenReturn("{");
        assertThat(cache.get("bad", Map.class)).isNull();
        verify(redis).delete("bad");

        cache.set("key", Map.of("x", true), Duration.ofMinutes(1));
        verify(values).set(any(), any(), any(Duration.class));
        when(redis.keys("none*")).thenReturn(null);
        cache.deleteByPattern("none*");
        when(redis.keys("empty*")).thenReturn(Set.of());
        cache.deleteByPattern("empty*");
        when(redis.keys("hit*")).thenReturn(Set.of("hit:1", "hit:2"));
        cache.deleteByPattern("hit*");
        verify(redis).delete(Set.of("hit:1", "hit:2"));

        ObjectMapper broken = mock(ObjectMapper.class);
        when(broken.writeValueAsString(any())).thenThrow(new JsonProcessingException("broken") {});
        assertThatThrownBy(() -> new RedisCacheSupport(redis, broken)
                .set("key", Map.of(), Duration.ofSeconds(1)))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void jwtFilterHandlesMissingValidInvalidAndExistingAuthentication() throws Exception {
        JwtService jwt = mock(JwtService.class);
        JwtAuthenticationFilter filter = new JwtAuthenticationFilter(jwt);

        filter.doFilter(new MockHttpServletRequest(), new MockHttpServletResponse(), new MockFilterChain());
        verify(jwt, never()).parseToken(any());

        MockHttpServletRequest valid = new MockHttpServletRequest();
        valid.addHeader("Authorization", "Bearer token");
        when(jwt.parseToken("token")).thenReturn(new JwtService.JwtUser(7L, "alice"));
        filter.doFilter(valid, new MockHttpServletResponse(), new MockFilterChain());
        assertThat(SecurityContextHolder.getContext().getAuthentication().getPrincipal())
                .isEqualTo(new JwtService.JwtUser(7L, "alice"));

        SecurityContextHolder.clearContext();
        MockHttpServletRequest invalid = new MockHttpServletRequest();
        invalid.addHeader("Authorization", "Bearer invalid");
        when(jwt.parseToken("invalid")).thenThrow(new IllegalArgumentException("bad"));
        filter.doFilter(invalid, new MockHttpServletResponse(), new MockFilterChain());
        assertThat(SecurityContextHolder.getContext().getAuthentication()).isNull();

        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken("existing", null, List.of())
        );
        MockHttpServletRequest existing = new MockHttpServletRequest();
        existing.addHeader("Authorization", "Bearer ignored");
        filter.doFilter(existing, new MockHttpServletResponse(), new MockFilterChain());
        assertThat(SecurityContextHolder.getContext().getAuthentication().getPrincipal())
                .isEqualTo("existing");

        SecurityContextHolder.clearContext();
        MockHttpServletRequest wrongPrefix = new MockHttpServletRequest();
        wrongPrefix.addHeader("Authorization", "Basic abc");
        filter.doFilter(wrongPrefix, new MockHttpServletResponse(), new MockFilterChain());
    }

    @Test
    void securityConfigurationProvidesPasswordEncoderAndCorsPolicy() {
        SecurityConfig config = new SecurityConfig(
                new JwtAuthenticationFilter(mock(JwtService.class)), new ObjectMapper()
        );
        String encoded = config.passwordEncoder().encode("secret");
        assertThat(config.passwordEncoder().matches("secret", encoded)).isTrue();
        var cors = config.corsConfigurationSource()
                .getCorsConfiguration(new MockHttpServletRequest("GET", "/api/health"));
        assertThat(cors).isNotNull();
        assertThat(cors.getAllowedOrigins()).contains("http://localhost:8081");
        assertThat(cors.getAllowedMethods()).contains("GET", "POST", "OPTIONS");
        assertThat(cors.getAllowedHeaders()).contains("*");
        assertThat(cors.getAllowCredentials()).isTrue();
        assertThat(cors.getMaxAge()).isEqualTo(3600L);
    }
}
