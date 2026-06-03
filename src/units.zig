const Forza = @import("forza.zig");

pub const Units = enum { metric, imperial };

pub fn speed(pkt: Forza.Packet, units: Units) f32 {
    return switch (units) {
        .metric => pkt.speedKmh(),
        .imperial => pkt.speedMph(),
    };
}

pub fn speedLabel(units: Units) []const u8 {
    return switch (units) {
        .metric => "KM/H",
        .imperial => "MPH",
    };
}

/// Packet power is watts.
pub fn powerHp(watts: f32) f32 {
    return watts / 745.699872;
}

/// Packet torque is newton-meters.
pub fn torqueLbFt(nm: f32) f32 {
    return nm * 0.737562;
}

pub fn power(pkt: Forza.Packet, units: Units) f32 {
    return switch (units) {
        .metric => pkt.power_watts / 1000.0, // kW
        .imperial => powerHp(pkt.power_watts),
    };
}

pub fn powerLabel(units: Units) []const u8 {
    return switch (units) {
        .metric => "kW",
        .imperial => "HP",
    };
}

pub fn torque(pkt: Forza.Packet, units: Units) f32 {
    return switch (units) {
        .metric => pkt.torque_nm,
        .imperial => torqueLbFt(pkt.torque_nm),
    };
}

pub fn torqueLabel(units: Units) []const u8 {
    return switch (units) {
        .metric => "Nm",
        .imperial => "lb-ft",
    };
}

pub fn tyreTemp(ferinheight: f32, units: Units) f32 {
    return switch (units) {
        .metric => (ferinheight - 32) * (5.0 / 9.0),
        .imperial => ferinheight,
    };
}

pub fn tyreTempLabel(units: Units) []const u8 {
    return switch (units) {
        .metric => "TYRE C",
        .imperial => "TYRE F",
    };
}
