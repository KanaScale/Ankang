package com.ankang.assistant.reminder.service;

import com.ankang.assistant.config.SecurityUtils;
import com.ankang.assistant.reminder.dto.ReminderSaveDTO;
import com.ankang.assistant.reminder.entity.Reminder;
import com.ankang.assistant.reminder.mapper.ReminderMapper;
import com.ankang.assistant.reminder.vo.ReminderCompleteVO;
import com.ankang.assistant.reminder.vo.ReminderVO;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.temporal.WeekFields;
import java.util.List;
import java.util.Objects;
import java.util.Set;

/** 提醒领域的持久化服务：所有读写操作均按当前登录用户隔离数据。 */
@Service
public class ReminderService {

    private static final Set<String> SUPPORTED_TYPES = Set.of(
            "medicine", "bloodPressure", "bloodSugar", "checkup", "other"
    );
    private static final Set<String> SUPPORTED_REPEAT_TYPES = Set.of("once", "daily", "weekly");

    private final ReminderMapper reminderMapper;

    public ReminderService(ReminderMapper reminderMapper) {
        this.reminderMapper = reminderMapper;
    }

    /** 查询当前用户的全部提醒，并按计划时间和主键稳定排序。 */
    public List<ReminderVO> listReminders() {
        return listRemindersByUserId(SecurityUtils.currentUserId());
    }

    public List<ReminderVO> listRemindersByUserId(Long userId) {
        assertValidUserId(userId);
        return reminderMapper.selectList(new LambdaQueryWrapper<Reminder>()
                        .eq(Reminder::getUserId, userId)
                        .orderByAsc(Reminder::getRemindAt)
                        .orderByAsc(Reminder::getId))
                .stream()
                .map(this::toVO)
                .toList();
    }

    /** 查询当前用户仍需要处理的启用提醒，供 Agent 和待办入口使用。 */
    public List<ReminderVO> listPendingReminders(int limit) {
        return listPendingRemindersByUserId(SecurityUtils.currentUserId(), limit);
    }

    public List<ReminderVO> listPendingRemindersByUserId(Long userId, int limit) {
        assertValidUserId(userId);
        int safeLimit = Math.min(Math.max(limit, 1), 20);
        return reminderMapper.selectList(new LambdaQueryWrapper<Reminder>()
                        .eq(Reminder::getUserId, userId)
                        .eq(Reminder::getEnabled, true)
                        .orderByAsc(Reminder::getRemindAt)
                        .orderByAsc(Reminder::getId))
                .stream()
                .filter(reminder -> !isCompletedForToday(reminder))
                .limit(safeLimit)
                .map(this::toVO)
                .toList();
    }

    /** 创建提醒并初始化完成状态；实际写入由 MyBatis-Plus Mapper 执行。 */
    @Transactional
    public ReminderVO createReminder(ReminderSaveDTO dto) {
        Long userId = SecurityUtils.currentUserId();
        String clientReminderId = normalizeClientReminderId(dto.clientReminderId());
        if (clientReminderId != null) {
            Reminder existing = findByClientReminderId(userId, clientReminderId);
            if (existing != null) {
                return toVO(existing);
            }
        }
        Reminder reminder = new Reminder();
        reminder.setUserId(userId);
        reminder.setClientReminderId(clientReminderId);
        applySaveDTO(reminder, dto);
        reminder.setCompleted(false);
        reminder.setLastCompletedDate(null);
        try {
            reminderMapper.insert(reminder);
        } catch (DuplicateKeyException error) {
            Reminder existing = findByClientReminderId(userId, clientReminderId);
            if (existing == null) {
                throw error;
            }
            return toVO(existing);
        }
        return toVO(reminder);
    }

    /** 更新提醒内容；调度计划变化时清除旧完成记录，使新计划重新进入待办。 */
    @Transactional
    public ReminderVO updateReminder(Long id, ReminderSaveDTO dto) {
        Long userId = SecurityUtils.currentUserId();
        Reminder reminder = requireReminder(id, userId);
        String previousRepeatType = reminder.getRepeatType();
        LocalDateTime previousRemindAt = reminder.getRemindAt();
        applySaveDTO(reminder, dto);
        boolean scheduleChanged = !Objects.equals(previousRepeatType, reminder.getRepeatType())
                || !Objects.equals(previousRemindAt, reminder.getRemindAt());
        if (scheduleChanged) {
            reminder.setCompleted(false);
            reminder.setLastCompletedDate(null);
        }
        reminderMapper.updateById(reminder);
        return toVO(reminder);
    }

    /** DELETE 可安全重试：记录已经不存在时同样视为删除完成。 */
    @Transactional
    public void deleteReminder(Long id) {
        Long userId = SecurityUtils.currentUserId();
        Reminder reminder = reminderMapper.selectById(id);
        if (reminder != null && Objects.equals(userId, reminder.getUserId())) {
            reminderMapper.deleteById(id);
        }
    }

    /** 按提醒类型记录完成：一次性提醒使用 completed，重复提醒使用完成日期。 */
    @Transactional
    public ReminderCompleteVO completeReminder(Long id) {
        Long userId = SecurityUtils.currentUserId();
        Reminder reminder = requireReminder(id, userId);
        if ("once".equals(reminder.getRepeatType())) {
            reminder.setCompleted(true);
        } else {
            reminder.setLastCompletedDate(LocalDate.now());
        }
        reminderMapper.updateById(reminder);
        return new ReminderCompleteVO(id, isCompletedForToday(reminder));
    }

    /** 取消当前完成状态，使一次性提醒或当前重复周期重新进入待办。 */
    @Transactional
    public ReminderCompleteVO uncompleteReminder(Long id) {
        Long userId = SecurityUtils.currentUserId();
        Reminder reminder = requireReminder(id, userId);
        reminder.setCompleted(false);
        reminder.setLastCompletedDate(null);
        reminderMapper.updateById(reminder);
        return new ReminderCompleteVO(id, false);
    }

    /** 加载提醒并校验所有权，阻止当前用户修改其他用户的数据。 */
    private Reminder requireReminder(Long id, Long userId) {
        Reminder reminder = reminderMapper.selectById(id);
        if (reminder == null || !Objects.equals(userId, reminder.getUserId())) {
            throw new IllegalArgumentException("提醒不存在");
        }
        return reminder;
    }

    /** 将保存请求中的可编辑字段集中写入 Entity，并补齐默认值。 */
    private void applySaveDTO(Reminder reminder, ReminderSaveDTO dto) {
        validateReminderType(dto.type());
        validateRepeatType(dto.repeatType());
        reminder.setTitle(dto.title());
        reminder.setType(hasText(dto.type()) ? dto.type() : "other");
        reminder.setDescription(dto.description());
        reminder.setRemark(dto.remark() == null ? dto.description() : dto.remark());
        reminder.setRemindAt(resolveRemindAt(dto));
        reminder.setRemindTime(resolveRemindTime(dto));
        reminder.setRepeatType(hasText(dto.repeatType()) ? dto.repeatType() : "once");
        reminder.setEnabled(dto.enabled() == null || dto.enabled());
    }

    /** 将数据库 Entity 转换为对外 VO，避免 Controller 直接暴露持久化模型。 */
    private ReminderVO toVO(Reminder reminder) {
        return new ReminderVO(
                reminder.getId(),
                reminder.getClientReminderId(),
                reminder.getTitle(),
                reminder.getType(),
                reminder.getDescription(),
                reminder.getRemark(),
                reminder.getRemindAt(),
                reminder.getRemindTime() == null ? null : reminder.getRemindTime().toString(),
                reminder.getRepeatType(),
                reminder.getEnabled(),
                isCompletedForToday(reminder)
        );
    }

    /** 根据一次性、每日或每周规则计算提醒在当前周期是否已完成。 */
    private boolean isCompletedForToday(Reminder reminder) {
        if ("once".equals(reminder.getRepeatType())) {
            return Boolean.TRUE.equals(reminder.getCompleted());
        }
        LocalDate completedDate = reminder.getLastCompletedDate();
        if (completedDate == null) {
            return false;
        }
        LocalDate today = LocalDate.now();
        // weekly 按 ISO 周判断；daily 等重复类型只对当天完成记录返回 true。
        if ("weekly".equals(reminder.getRepeatType())) {
            WeekFields weekFields = WeekFields.ISO;
            return completedDate.get(weekFields.weekBasedYear()) == today.get(weekFields.weekBasedYear())
                    && completedDate.get(weekFields.weekOfWeekBasedYear()) == today.get(weekFields.weekOfWeekBasedYear());
        }
        return completedDate.equals(today);
    }

    /** 优先使用完整日期时间；兼容旧请求仅提交 remindTime 的情况。 */
    private LocalDateTime resolveRemindAt(ReminderSaveDTO dto) {
        if (dto.remindAt() != null) {
            return dto.remindAt();
        }
        return LocalDate.now().atTime(resolveRemindTime(dto));
    }

    /** 统一解析提醒时间，缺省时使用 08:00。 */
    private LocalTime resolveRemindTime(ReminderSaveDTO dto) {
        if (hasText(dto.remindTime())) {
            return LocalTime.parse(dto.remindTime());
        }
        if (dto.remindAt() != null) {
            return dto.remindAt().toLocalTime().withSecond(0).withNano(0);
        }
        return LocalTime.of(8, 0);
    }

    private boolean hasText(String value) {
        return value != null && !value.isBlank();
    }

    private String normalizeClientReminderId(String value) {
        return hasText(value) ? value.trim() : null;
    }

    private Reminder findByClientReminderId(Long userId, String clientReminderId) {
        if (clientReminderId == null) {
            return null;
        }
        return reminderMapper.selectOne(new LambdaQueryWrapper<Reminder>()
                .eq(Reminder::getUserId, userId)
                .eq(Reminder::getClientReminderId, clientReminderId)
                .last("LIMIT 1"));
    }

    private void assertValidUserId(Long userId) {
        if (userId == null || userId <= 0) {
            throw new IllegalArgumentException("用户 ID 不合法");
        }
    }

    private void validateReminderType(String type) {
        if (hasText(type) && !SUPPORTED_TYPES.contains(type)) {
            throw new IllegalArgumentException("不支持的提醒类型: " + type);
        }
    }

    private void validateRepeatType(String repeatType) {
        if (hasText(repeatType) && !SUPPORTED_REPEAT_TYPES.contains(repeatType)) {
            throw new IllegalArgumentException("不支持的重复类型: " + repeatType);
        }
    }
}
