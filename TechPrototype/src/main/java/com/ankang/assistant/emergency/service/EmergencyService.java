package com.ankang.assistant.emergency.service;

import com.ankang.assistant.config.SecurityUtils;
import com.ankang.assistant.emergency.dto.DispatchAttemptDTO;
import com.ankang.assistant.emergency.dto.DispatchResultsDTO;
import com.ankang.assistant.emergency.dto.EmergencyContactSaveDTO;
import com.ankang.assistant.emergency.dto.SosCreateDTO;
import com.ankang.assistant.emergency.entity.EmergencyContact;
import com.ankang.assistant.emergency.entity.EmergencyDeliveryAttempt;
import com.ankang.assistant.emergency.entity.EmergencyEvent;
import com.ankang.assistant.emergency.mapper.EmergencyContactMapper;
import com.ankang.assistant.emergency.mapper.EmergencyDeliveryAttemptMapper;
import com.ankang.assistant.emergency.mapper.EmergencyEventMapper;
import com.ankang.assistant.emergency.vo.DispatchAttemptVO;
import com.ankang.assistant.emergency.vo.EmergencyContactVO;
import com.ankang.assistant.emergency.vo.EmergencyEventVO;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;
import java.util.Set;

/** 联系人、SOS 事件和设备投递结果的持久化服务。 */
@Service
public class EmergencyService {

    private static final Set<String> LOCATION_SOURCES = Set.of("fresh", "cached", "unavailable");
    private static final Set<String> CHANNELS = Set.of("sms", "call");
    private static final Set<String> ATTEMPT_STATUSES = Set.of(
            "requested", "sent", "delivered", "launched", "failed", "skipped_not_sms_capable"
    );
    private static final Set<String> TERMINAL_STATUSES = Set.of(
            "delivered", "launched", "failed", "skipped_not_sms_capable"
    );

    private final EmergencyContactMapper emergencyContactMapper;
    private final EmergencyEventMapper emergencyEventMapper;
    private final EmergencyDeliveryAttemptMapper emergencyDeliveryAttemptMapper;

    public EmergencyService(
            EmergencyContactMapper emergencyContactMapper,
            EmergencyEventMapper emergencyEventMapper,
            EmergencyDeliveryAttemptMapper emergencyDeliveryAttemptMapper
    ) {
        this.emergencyContactMapper = emergencyContactMapper;
        this.emergencyEventMapper = emergencyEventMapper;
        this.emergencyDeliveryAttemptMapper = emergencyDeliveryAttemptMapper;
    }

    public List<EmergencyContactVO> listContacts() {
        Long userId = SecurityUtils.currentUserId();
        return contactsForUser(userId).stream().map(this::toContactVO).toList();
    }

    public List<EmergencyContactVO> listContactsByUserId(Long userId) {
        assertValidUserId(userId);
        return contactsForUser(userId).stream().map(this::toContactVO).toList();
    }

    @Transactional
    public EmergencyContactVO createContact(EmergencyContactSaveDTO dto) {
        Long userId = SecurityUtils.currentUserId();
        String clientContactId = hasText(dto.clientContactId()) ? dto.clientContactId().trim() : null;
        if (clientContactId != null) {
            EmergencyContact existing = findContactByClientId(userId, clientContactId);
            if (existing != null) return toContactVO(existing);
        }
        List<EmergencyContact> existingContacts = contactsForUser(userId);
        ensureUniquePhone(userId, dto.phone(), null);
        EmergencyContact contact = new EmergencyContact();
        contact.setUserId(userId);
        contact.setClientContactId(clientContactId);
        applyContactDTO(contact, dto);
        contact.setPriority(existingContacts.isEmpty() || Integer.valueOf(1).equals(dto.priority())
                ? 1
                : existingContacts.size() + 1);
        try {
            emergencyContactMapper.insert(contact);
        } catch (DuplicateKeyException ex) {
            EmergencyContact existing = findContactByClientId(userId, clientContactId);
            if (existing != null) return toContactVO(existing);
            throw ex;
        }
        resequenceContacts(userId, contact.getPriority() == 1 ? contact.getId() : null);
        return toContactVO(requireContact(contact.getId(), userId));
    }

    @Transactional
    public EmergencyContactVO updateContact(Long id, EmergencyContactSaveDTO dto) {
        Long userId = SecurityUtils.currentUserId();
        EmergencyContact contact = requireContact(id, userId);
        ensureUniquePhone(userId, dto.phone(), id);
        boolean wasPrimary = Integer.valueOf(1).equals(contact.getPriority());
        applyContactDTO(contact, dto);
        boolean makePrimary = Integer.valueOf(1).equals(dto.priority());
        boolean removePrimary = wasPrimary && Integer.valueOf(0).equals(dto.priority());
        if (makePrimary) {
            contact.setPriority(1);
        } else if (removePrimary) {
            contact.setPriority(contactsForUser(userId).size() + 1);
        }
        emergencyContactMapper.updateById(contact);
        resequenceContacts(userId, makePrimary ? id : null);
        return toContactVO(requireContact(id, userId));
    }

    @Transactional
    public void deleteContact(Long id) {
        Long userId = SecurityUtils.currentUserId();
        EmergencyContact contact = emergencyContactMapper.selectById(id);
        if (contact == null || !Objects.equals(userId, contact.getUserId())) {
            return;
        }
        emergencyContactMapper.deleteById(id);
        resequenceContacts(userId, null);
    }

    /** 幂等记录设备端创建的 SOS 事件；阶段一不触发真实电话或短信。 */
    @Transactional
    public EmergencyEventVO createSosEvent(SosCreateDTO dto) {
        Long userId = SecurityUtils.currentUserId();
        validateSosCreateDTO(dto);
        if (hasText(dto.clientEventId())) {
            EmergencyEvent existing = findEventByClientId(userId, dto.clientEventId());
            if (existing != null) {
                return toEventVO(existing);
            }
        }
        LocalDateTime now = LocalDateTime.now();
        EmergencyEvent event = new EmergencyEvent();
        event.setUserId(userId);
        event.setClientEventId(hasText(dto.clientEventId()) ? dto.clientEventId().trim() : null);
        event.setTriggeredAt(dto.triggeredAt() == null ? now : dto.triggeredAt());
        event.setLatitude(dto.latitude());
        event.setLongitude(dto.longitude());
        event.setAccuracyMeters(dto.accuracyMeters());
        event.setLocationSource(resolveLocationSource(dto));
        event.setAddress(dto.address());
        event.setMessage(hasText(dto.message()) ? dto.message() : "已记录求助事件");
        event.setStatus("dispatching");
        event.setContactsNotified(0);
        event.setCreatedAt(now);
        event.setUpdatedAt(now);
        try {
            emergencyEventMapper.insert(event);
        } catch (DuplicateKeyException ex) {
            EmergencyEvent concurrent = findEventByClientId(userId, dto.clientEventId());
            if (concurrent != null) {
                return toEventVO(concurrent);
            }
            throw ex;
        }
        return toEventVO(event, List.of());
    }

    /** 批量幂等写入设备端短信/电话结果，并重新计算事件汇总状态。 */
    @Transactional
    public EmergencyEventVO updateDispatchResults(String clientEventId, DispatchResultsDTO dto) {
        Long userId = SecurityUtils.currentUserId();
        EmergencyEvent event = findEventByClientId(userId, clientEventId);
        if (event == null) {
            throw new IllegalArgumentException("SOS 事件不存在");
        }
        for (DispatchAttemptDTO attemptDTO : dto.attempts()) {
            upsertAttempt(event, userId, attemptDTO);
        }
        List<EmergencyDeliveryAttempt> attempts = attemptsForEvent(event.getId(), userId);
        event.setContactsNotified(countDeliveredContacts(attempts));
        event.setStatus(aggregateStatus(attempts));
        event.setUpdatedAt(LocalDateTime.now());
        emergencyEventMapper.updateById(event);
        return toEventVO(event, attempts);
    }

    public List<EmergencyEventVO> listEvents() {
        return listEventsByUserId(SecurityUtils.currentUserId());
    }

    public List<EmergencyEventVO> listEventsByUserId(Long userId) {
        assertValidUserId(userId);
        return emergencyEventMapper.selectList(new LambdaQueryWrapper<EmergencyEvent>()
                        .eq(EmergencyEvent::getUserId, userId)
                        .orderByDesc(EmergencyEvent::getCreatedAt)
                        .orderByDesc(EmergencyEvent::getId))
                .stream()
                .map(this::toEventVO)
                .toList();
    }

    private List<EmergencyContact> contactsForUser(Long userId) {
        return emergencyContactMapper.selectList(new LambdaQueryWrapper<EmergencyContact>()
                .eq(EmergencyContact::getUserId, userId)
                .orderByAsc(EmergencyContact::getPriority)
                .orderByAsc(EmergencyContact::getId));
    }

    private EmergencyContact requireContact(Long id, Long userId) {
        EmergencyContact contact = emergencyContactMapper.selectById(id);
        if (contact == null || !Objects.equals(userId, contact.getUserId())) {
            throw new IllegalArgumentException("紧急联系人不存在");
        }
        return contact;
    }

    private void ensureUniquePhone(Long userId, String phone, Long excludedContactId) {
        LambdaQueryWrapper<EmergencyContact> query = new LambdaQueryWrapper<EmergencyContact>()
                .eq(EmergencyContact::getUserId, userId)
                .eq(EmergencyContact::getPhone, phone.trim());
        if (excludedContactId != null) {
            query.ne(EmergencyContact::getId, excludedContactId);
        }
        if (emergencyContactMapper.selectCount(query) > 0) {
            throw new IllegalArgumentException("该手机号已经是当前账号的紧急联系人");
        }
    }

    private void resequenceContacts(Long userId, Long preferredPrimaryId) {
        List<EmergencyContact> contacts = contactsForUser(userId);
        if (contacts.isEmpty()) {
            return;
        }
        EmergencyContact primary = preferredPrimaryId == null
                ? contacts.stream().min(Comparator.comparing(EmergencyContact::getPriority)
                        .thenComparing(EmergencyContact::getId)).orElseThrow()
                : contacts.stream().filter(item -> item.getId().equals(preferredPrimaryId)).findFirst().orElseThrow();
        contacts.remove(primary);
        contacts.add(0, primary);
        for (int index = 0; index < contacts.size(); index++) {
            EmergencyContact contact = contacts.get(index);
            int expectedPriority = index + 1;
            if (!Integer.valueOf(expectedPriority).equals(contact.getPriority())) {
                contact.setPriority(expectedPriority);
                emergencyContactMapper.updateById(contact);
            }
        }
    }

    private void applyContactDTO(EmergencyContact contact, EmergencyContactSaveDTO dto) {
        validatePriority(dto.priority());
        PhoneNumberCapability.resolve(dto.phone());
        String relation = hasText(dto.relation()) ? dto.relation() : dto.relationship();
        contact.setName(dto.name());
        contact.setRelation(relation);
        contact.setRelationship(hasText(dto.relationship()) ? dto.relationship() : relation);
        contact.setPhone(dto.phone().trim());
    }

    private EmergencyContactVO toContactVO(EmergencyContact contact) {
        PhoneNumberCapability.Result capability = PhoneNumberCapability.resolveLegacy(contact.getPhone());
        return new EmergencyContactVO(
                contact.getId(), contact.getClientContactId(), contact.getName(), contact.getRelation(), contact.getRelationship(),
                contact.getPhone(), contact.getPriority(), capability.e164(), capability.type(), capability.smsCapable()
        );
    }

    private EmergencyContact findContactByClientId(Long userId, String clientContactId) {
        if (!hasText(clientContactId)) return null;
        return emergencyContactMapper.selectOne(new LambdaQueryWrapper<EmergencyContact>()
                .eq(EmergencyContact::getUserId, userId)
                .eq(EmergencyContact::getClientContactId, clientContactId)
                .last("LIMIT 1"));
    }

    private EmergencyEventVO toEventVO(EmergencyEvent event) {
        return toEventVO(event, attemptsForEvent(event.getId(), event.getUserId()));
    }

    private EmergencyEventVO toEventVO(EmergencyEvent event, List<EmergencyDeliveryAttempt> attempts) {
        return new EmergencyEventVO(
                event.getId(), event.getId(), event.getCreatedAt(), event.getLatitude(), event.getLongitude(),
                event.getAddress(), event.getStatus(), event.getMessage(), event.getContactsNotified(),
                event.getClientEventId(), event.getTriggeredAt(), event.getAccuracyMeters(), event.getLocationSource(),
                attempts.stream().map(this::toAttemptVO).toList()
        );
    }

    private DispatchAttemptVO toAttemptVO(EmergencyDeliveryAttempt attempt) {
        return new DispatchAttemptVO(
                attempt.getAttemptId(), attempt.getContactId(), attempt.getChannel(), attempt.getStatus(),
                attempt.getErrorCode(), attempt.getOccurredAt()
        );
    }

    private void validatePriority(Integer priority) {
        if (priority != null && priority != 0 && priority != 1) {
            throw new IllegalArgumentException("priority 只能为 0 或 1");
        }
    }

    private void validateSosCreateDTO(SosCreateDTO dto) {
        if (dto == null) {
            throw new IllegalArgumentException("SOS 请求不能为空");
        }
        if (hasText(dto.clientEventId()) && dto.clientEventId().trim().length() > 36) {
            throw new IllegalArgumentException("clientEventId 长度不能超过 36");
        }
        if ((dto.latitude() == null) != (dto.longitude() == null)) {
            throw new IllegalArgumentException("经纬度必须同时提供");
        }
        if (dto.accuracyMeters() != null && dto.accuracyMeters().signum() < 0) {
            throw new IllegalArgumentException("定位精度不能为负数");
        }
        if (hasText(dto.locationSource()) && !LOCATION_SOURCES.contains(dto.locationSource())) {
            throw new IllegalArgumentException("不支持的定位来源: " + dto.locationSource());
        }
    }

    private String resolveLocationSource(SosCreateDTO dto) {
        if (hasText(dto.locationSource())) {
            return dto.locationSource();
        }
        return dto.latitude() == null ? "unavailable" : "fresh";
    }

    private EmergencyEvent findEventByClientId(Long userId, String clientEventId) {
        if (!hasText(clientEventId)) {
            return null;
        }
        return emergencyEventMapper.selectOne(new LambdaQueryWrapper<EmergencyEvent>()
                .eq(EmergencyEvent::getUserId, userId)
                .eq(EmergencyEvent::getClientEventId, clientEventId.trim()));
    }

    private List<EmergencyDeliveryAttempt> attemptsForEvent(Long eventId, Long userId) {
        if (eventId == null) {
            return List.of();
        }
        return emergencyDeliveryAttemptMapper.selectList(new LambdaQueryWrapper<EmergencyDeliveryAttempt>()
                .eq(EmergencyDeliveryAttempt::getEventId, eventId)
                .eq(EmergencyDeliveryAttempt::getUserId, userId)
                .orderByAsc(EmergencyDeliveryAttempt::getOccurredAt)
                .orderByAsc(EmergencyDeliveryAttempt::getId));
    }

    private void upsertAttempt(EmergencyEvent event, Long userId, DispatchAttemptDTO dto) {
        validateAttempt(dto);
        EmergencyDeliveryAttempt attempt = findAttempt(event.getId(), dto.attemptId());
        LocalDateTime now = LocalDateTime.now();
        if (attempt == null) {
            attempt = new EmergencyDeliveryAttempt();
            attempt.setEventId(event.getId());
            attempt.setUserId(userId);
            attempt.setAttemptId(dto.attemptId());
            attempt.setCreatedAt(now);
        } else if (isTerminal(attempt.getStatus()) && statusRank(dto.status()) < statusRank(attempt.getStatus())) {
            return;
        }
        attempt.setContactId(dto.contactId());
        attempt.setChannel(dto.channel());
        attempt.setStatus(dto.status());
        attempt.setErrorCode(dto.errorCode());
        attempt.setOccurredAt(dto.occurredAt() == null ? now : dto.occurredAt());
        attempt.setUpdatedAt(now);
        if (attempt.getId() == null) {
            try {
                emergencyDeliveryAttemptMapper.insert(attempt);
            } catch (DuplicateKeyException ex) {
                EmergencyDeliveryAttempt concurrent = findAttempt(event.getId(), dto.attemptId());
                if (concurrent == null) {
                    throw ex;
                }
                applyAttemptUpdate(concurrent, dto, now);
                emergencyDeliveryAttemptMapper.updateById(concurrent);
            }
        } else {
            emergencyDeliveryAttemptMapper.updateById(attempt);
        }
    }

    private EmergencyDeliveryAttempt findAttempt(Long eventId, String attemptId) {
        return emergencyDeliveryAttemptMapper.selectOne(new LambdaQueryWrapper<EmergencyDeliveryAttempt>()
                .eq(EmergencyDeliveryAttempt::getEventId, eventId)
                .eq(EmergencyDeliveryAttempt::getAttemptId, attemptId));
    }

    private void applyAttemptUpdate(
            EmergencyDeliveryAttempt attempt,
            DispatchAttemptDTO dto,
            LocalDateTime now
    ) {
        if (isTerminal(attempt.getStatus()) && statusRank(dto.status()) < statusRank(attempt.getStatus())) {
            return;
        }
        attempt.setContactId(dto.contactId());
        attempt.setChannel(dto.channel());
        attempt.setStatus(dto.status());
        attempt.setErrorCode(dto.errorCode());
        attempt.setOccurredAt(dto.occurredAt() == null ? now : dto.occurredAt());
        attempt.setUpdatedAt(now);
    }

    private void validateAttempt(DispatchAttemptDTO dto) {
        if (!CHANNELS.contains(dto.channel())) {
            throw new IllegalArgumentException("不支持的通知渠道: " + dto.channel());
        }
        if (!ATTEMPT_STATUSES.contains(dto.status())) {
            throw new IllegalArgumentException("不支持的通知状态: " + dto.status());
        }
        if ("call".equals(dto.channel())
                && Set.of("sent", "delivered", "skipped_not_sms_capable").contains(dto.status())) {
            throw new IllegalArgumentException("电话渠道不支持状态: " + dto.status());
        }
        if ("sms".equals(dto.channel()) && "launched".equals(dto.status())) {
            throw new IllegalArgumentException("短信渠道不支持状态: launched");
        }
    }

    private int countDeliveredContacts(List<EmergencyDeliveryAttempt> attempts) {
        return (int) attempts.stream()
                .filter(item -> "sms".equals(item.getChannel()) && "delivered".equals(item.getStatus()))
                .map(EmergencyDeliveryAttempt::getContactId)
                .filter(Objects::nonNull)
                .distinct()
                .count();
    }

    private String aggregateStatus(List<EmergencyDeliveryAttempt> attempts) {
        if (attempts.isEmpty() || attempts.stream().anyMatch(item -> !isTerminal(item.getStatus()))) {
            return "dispatching";
        }
        long successes = attempts.stream()
                .filter(item -> Set.of("delivered", "launched").contains(item.getStatus()))
                .count();
        long failures = attempts.stream().filter(item -> "failed".equals(item.getStatus())).count();
        if (successes == 0 && failures > 0) {
            return "failed";
        }
        return failures > 0 ? "partial_failure" : "completed";
    }

    private boolean isTerminal(String status) {
        return TERMINAL_STATUSES.contains(status);
    }

    private int statusRank(String status) {
        return switch (status) {
            case "requested" -> 0;
            case "sent" -> 1;
            default -> 2;
        };
    }

    private boolean hasText(String value) {
        return value != null && !value.isBlank();
    }

    private void assertValidUserId(Long userId) {
        if (userId == null || userId <= 0) {
            throw new IllegalArgumentException("用户 ID 不合法");
        }
    }
}
