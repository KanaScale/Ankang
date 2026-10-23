package com.ankang.assistant.emergency.service;

import com.google.i18n.phonenumbers.NumberParseException;
import com.google.i18n.phonenumbers.PhoneNumberUtil;
import com.google.i18n.phonenumbers.Phonenumber.PhoneNumber;

import java.util.Locale;

/** 使用官方号码元数据校验号码，并为设备端提供可拨打/可短信能力。 */
final class PhoneNumberCapability {

    private static final PhoneNumberUtil PHONE_UTIL = PhoneNumberUtil.getInstance();

    private PhoneNumberCapability() {
    }

    static Result resolve(String rawPhone) {
        String phone = rawPhone == null ? "" : rawPhone.trim();
        if (!phone.matches("^1[3-9]\\d{9}$")) {
            throw new IllegalArgumentException("请输入正确的大陆手机号");
        }
        try {
            PhoneNumber parsed = PHONE_UTIL.parse(phone, "CN");
            PhoneNumberUtil.PhoneNumberType numberType = PHONE_UTIL.getNumberType(parsed);
            if (!PHONE_UTIL.isValidNumberForRegion(parsed, "CN")
                    || numberType != PhoneNumberUtil.PhoneNumberType.MOBILE) {
                throw new IllegalArgumentException("请输入正确的大陆手机号");
            }
            return new Result(
                    PHONE_UTIL.format(parsed, PhoneNumberUtil.PhoneNumberFormat.E164),
                    numberType.name().toLowerCase(Locale.ROOT),
                    true
            );
        } catch (NumberParseException ex) {
            throw new IllegalArgumentException("请输入正确的大陆手机号", ex);
        }
    }

    static Result resolveLegacy(String rawPhone) {
        try {
            return resolve(rawPhone);
        } catch (IllegalArgumentException ex) {
            return new Result(null, "unknown", false);
        }
    }

    record Result(String e164, String type, boolean smsCapable) {
    }
}
