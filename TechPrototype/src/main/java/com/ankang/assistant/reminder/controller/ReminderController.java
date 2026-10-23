package com.ankang.assistant.reminder.controller;

import com.ankang.assistant.common.Result;
import com.ankang.assistant.reminder.dto.ReminderSaveDTO;
import com.ankang.assistant.reminder.service.ReminderService;
import com.ankang.assistant.reminder.vo.ReminderCompleteVO;
import com.ankang.assistant.reminder.vo.ReminderVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@Tag(name = "健康提醒模块")
@RestController
@RequestMapping("/api/reminders")
public class ReminderController {

    private final ReminderService reminderService;

    public ReminderController(ReminderService reminderService) {
        this.reminderService = reminderService;
    }

    @Operation(summary = "提醒列表")
    @GetMapping
    public Result<List<ReminderVO>> listReminders() {
        return Result.success(reminderService.listReminders());
    }

    @Operation(summary = "新增提醒")
    @PostMapping
    public Result<ReminderVO> createReminder(@Valid @RequestBody ReminderSaveDTO dto) {
        return Result.success(reminderService.createReminder(dto));
    }

    @Operation(summary = "更新提醒")
    @PutMapping("/{id}")
    public Result<ReminderVO> updateReminder(@PathVariable Long id, @Valid @RequestBody ReminderSaveDTO dto) {
        return Result.success(reminderService.updateReminder(id, dto));
    }

    @Operation(summary = "删除提醒")
    @DeleteMapping("/{id}")
    public Result<Void> deleteReminder(@PathVariable Long id) {
        reminderService.deleteReminder(id);
        return Result.success();
    }

    @Operation(summary = "标记提醒完成")
    @PutMapping("/{id}/complete")
    public Result<ReminderCompleteVO> completeReminder(@PathVariable Long id) {
        return Result.success(reminderService.completeReminder(id));
    }

    @Operation(summary = "取消提醒完成状态")
    @PutMapping("/{id}/uncomplete")
    public Result<ReminderCompleteVO> uncompleteReminder(@PathVariable Long id) {
        return Result.success(reminderService.uncompleteReminder(id));
    }
}
