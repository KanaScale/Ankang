package com.ankang.assistant.emergency.vo;

import java.util.List;

public record NearbyHospitalVO(
        String source,
        String coordinateSystem,
        Integer radiusMeters,
        List<HospitalVO> hospitals
) {
    public record HospitalVO(
            String poiId,
            String name,
            String address,
            Integer distanceMeters,
            String distance,
            String phone,
            Double latitude,
            Double longitude,
            String category,
            String source
    ) {
    }
}
