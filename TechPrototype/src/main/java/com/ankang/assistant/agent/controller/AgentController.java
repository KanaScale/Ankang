package com.ankang.assistant.agent.controller;

import com.ankang.assistant.agent.action.AgentActionConfirmRequest;
import com.ankang.assistant.agent.action.AgentActionService;
import com.ankang.assistant.agent.action.AgentActionVO;
import com.ankang.assistant.agent.dto.AgentChatDTO;
import com.ankang.assistant.agent.service.AgentService;
import com.ankang.assistant.agent.service.AgentStreamService;
import com.ankang.assistant.agent.vo.AgentMessageVO;
import com.ankang.assistant.agent.vo.AgentReplyVO;
import com.ankang.assistant.agent.vo.AgentSessionVO;
import com.ankang.assistant.common.Result;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.http.MediaType;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.util.List;

@Tag(name = "智能问答模块")
@RestController
@RequestMapping("/api/agent")
public class AgentController {

    private final AgentService agentService;
    private final AgentStreamService agentStreamService;
    private final AgentActionService agentActionService;

    public AgentController(
            AgentService agentService,
            AgentStreamService agentStreamService,
            AgentActionService agentActionService
    ) {
        this.agentService = agentService;
        this.agentStreamService = agentStreamService;
        this.agentActionService = agentActionService;
    }

    @Operation(summary = "健康 Agent 问答")
    @PostMapping("/chat")
    public Result<AgentReplyVO> chat(@Valid @RequestBody AgentChatDTO dto) {
        return Result.success(agentService.chat(dto));
    }

    @Operation(summary = "健康 Agent 流式问答")
    @PostMapping(value = "/chat/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter chatStream(@Valid @RequestBody AgentChatDTO dto) {
        return agentStreamService.chatStream(dto);
    }

    @Operation(summary = "确认执行 Agent Action")
    @PostMapping("/actions/confirm")
    public Result<AgentActionVO> confirmAction(@Valid @RequestBody AgentActionConfirmRequest request) {
        return Result.success(agentActionService.confirm(request));
    }

    @Operation(summary = "Agent 会话列表")
    @GetMapping("/sessions")
    public Result<List<AgentSessionVO>> listSessions() {
        return Result.success(agentService.listSessions());
    }

    @Operation(summary = "Agent 会话消息")
    @GetMapping("/sessions/{id}/messages")
    public Result<List<AgentMessageVO>> listMessages(@PathVariable Long id) {
        return Result.success(agentService.listMessages(id));
    }

    @Operation(summary = "删除 Agent 会话")
    @DeleteMapping("/sessions/{id}")
    public Result<Void> deleteSession(@PathVariable Long id) {
        agentService.deleteSession(id);
        return Result.success();
    }
}
