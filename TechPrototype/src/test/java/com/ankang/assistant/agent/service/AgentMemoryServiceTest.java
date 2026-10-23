package com.ankang.assistant.agent.service;

import com.ankang.assistant.agent.entity.AgentMemory;
import com.ankang.assistant.agent.mapper.AgentMemoryMapper;
import com.baomidou.mybatisplus.core.MybatisConfiguration;
import com.baomidou.mybatisplus.core.metadata.TableInfoHelper;
import org.apache.ibatis.builder.MapperBuilderAssistant;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AgentMemoryServiceTest {

    @BeforeAll
    static void initTableInfo() {
        TableInfoHelper.initTableInfo(
                new MapperBuilderAssistant(new MybatisConfiguration(), ""), AgentMemory.class
        );
    }

    @Test
    void listsMemoriesAndRecognizesEveryExplicitFactCategory() {
        AgentMemoryMapper mapper = mock(AgentMemoryMapper.class);
        AgentMemory listed = new AgentMemory();
        listed.setMemoryValue("fact");
        when(mapper.selectList(any())).thenReturn(List.of(listed));
        when(mapper.selectOne(any())).thenReturn(null);
        AgentMemoryService service = new AgentMemoryService(mapper);

        assertThat(service.listMemories(7L)).containsExactly(listed);
        service.rememberExplicitUserFact(7L, null);
        service.rememberExplicitUserFact(7L, "ordinary chat");
        for (String fact : List.of(
                "我对青霉素过敏",
                "我有高血压",
                "我长期服用药物",
                "我每周运动三次",
                "医生要求我少盐",
                "家人提醒我照护事项",
                "请记住这个健康信息"
        )) {
            service.rememberExplicitUserFact(7L, fact);
        }
        verify(mapper, org.mockito.Mockito.times(7)).insert(any(AgentMemory.class));
    }

    @Test
    void updatesExistingMemoryInsteadOfDuplicatingIt() {
        AgentMemoryMapper mapper = mock(AgentMemoryMapper.class);
        AgentMemory existing = new AgentMemory();
        existing.setMemoryKey("allergy");
        existing.setMemoryValue("old");
        when(mapper.selectOne(any())).thenReturn(existing);

        new AgentMemoryService(mapper).rememberExplicitUserFact(7L, "花粉过敏");

        assertThat(existing.getMemoryValue()).isEqualTo("花粉过敏");
        verify(mapper).updateById(existing);
    }
}
