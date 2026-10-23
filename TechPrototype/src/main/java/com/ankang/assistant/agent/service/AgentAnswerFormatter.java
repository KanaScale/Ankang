package com.ankang.assistant.agent.service;

import org.springframework.stereotype.Service;

import java.util.Arrays;
import java.util.stream.Collectors;

@Service
public class AgentAnswerFormatter {

    public String format(String answer) {
        if (answer == null || answer.isBlank()) {
            return "";
        }
        String text = answer
                .replace("```", "")
                .replace("**", "")
                .replace("__", "")
                .replace("`", "");
        text = text.replaceAll("(?m)^\\s{0,3}#{1,6}\\s*", "");
        text = text.replaceAll("(?m)^\\s{0,3}>\\s?", "");
        text = text.replaceAll("(?m)^\\s*[-*+]\\s+", "");
        text = text.replaceAll("[ \\t]+\\n", "\n");
        text = text.replaceAll("\\n{3,}", "\n\n");
        return Arrays.stream(text.split("\\R"))
                .map(String::trim)
                .collect(Collectors.joining("\n"))
                .trim();
    }
}
