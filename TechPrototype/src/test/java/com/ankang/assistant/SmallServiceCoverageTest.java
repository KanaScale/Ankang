package com.ankang.assistant;

import com.ankang.assistant.advice.service.AdviceService;
import com.ankang.assistant.agent.config.AgentProperties;
import com.ankang.assistant.agent.service.AgentRagService;
import com.ankang.assistant.auth.service.AuthSessionException;
import com.ankang.assistant.common.GlobalExceptionHandler;
import org.junit.jupiter.api.Test;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.validation.BindingResult;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class SmallServiceCoverageTest {

    @Test
    void adviceAndRagFallbacksAreStable() {
        assertThat(new AdviceService().todayAdvice().title()).isNotBlank();
        AgentProperties properties = new AgentProperties();
        AgentRagService rag = new AgentRagService(properties);
        assertThat(rag.retrieve(1L, null)).isEmpty();
        assertThat(rag.retrieve(1L, " ")).isEmpty();
        assertThat(rag.retrieve(1L, "health")).isEmpty();
    }

    @Test
    void globalExceptionHandlerMapsEveryGeneralExceptionCategory() {
        GlobalExceptionHandler handler = new GlobalExceptionHandler();
        assertThat(handler.handleBadRequest(new Exception("bad")).getMessage()).isEqualTo("bad");
        assertThat(handler.handleIllegalArgument(new IllegalArgumentException("argument")).getMessage())
                .isEqualTo("argument");
        assertThat(handler.handleAuthSession(new AuthSessionException("session")).getMessage())
                .isEqualTo("session");
        assertThat(handler.handleAccessDenied(new AccessDeniedException("denied")).getMessage())
                .isEqualTo("denied");
        assertThat(handler.handleException(new RuntimeException("failure")).getMessage())
                .isEqualTo("failure");
    }

    @Test
    void globalValidationHandlerUsesFirstFieldErrorAndFallbackMessage() {
        GlobalExceptionHandler handler = new GlobalExceptionHandler();
        MethodArgumentNotValidException exception = mock(MethodArgumentNotValidException.class);
        BindingResult binding = mock(BindingResult.class);
        when(exception.getBindingResult()).thenReturn(binding);
        when(binding.getFieldErrors()).thenReturn(List.of(
                new FieldError("dto", "username", "must not be blank")
        ));
        assertThat(handler.handleMethodArgumentNotValid(exception).getMessage())
                .isEqualTo("username must not be blank");

        when(binding.getFieldErrors()).thenReturn(List.of());
        assertThat(handler.handleMethodArgumentNotValid(exception).getMessage()).isNotBlank();
    }
}
