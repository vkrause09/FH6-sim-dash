const std = @import("std");
const rl = @import("raylib");

pub fn gearString(buf: []u8, gear: u8) []const u8 {
    if (gear == 0) return "R";
    if (gear == 11) return "N";
    return std.fmt.bufPrint(buf, "{d}", .{gear}) catch "?";
}

pub fn formatLapTime(seconds: f32, buf: []u8) []const u8 {
    if (seconds <= 0) return "--:--.---";
    const total_ms: u32 = @intFromFloat(seconds * 1000.0);
    const minutes = total_ms / 60000;
    const secs = (total_ms / 1000) % 60;
    const millis = total_ms % 1000;
    return std.fmt.bufPrint(buf, "{d}:{d:0>2}.{d:0>3}", .{ minutes, secs, millis }) catch "?";
}

pub fn rpmRatio(rpm: f32, max_rpm: f32) f32 {
    const max = @max(100.0, max_rpm);
    return std.math.clamp(rpm / max, 0.0, 1.0);
}

pub fn getRatio(unit: f32, max_unit: f32) f32 {
    return std.math.clamp(unit / max_unit, 0.0, 1.0);
}

pub fn rpmColor(ratio: f32) rl.Color {
    if (ratio < 0.7) {
        const t = ratio / 0.7;
        return .{ .r = @intFromFloat(255 * t), .g = 255, .b = 0, .a = 255 };
    }
    if (ratio < 0.9) {
        const t = (ratio - 0.7) / 0.2;
        return .{ .r = 255, .g = @intFromFloat(255 * (1 - t)), .b = 0, .a = 255 };
    }
    const t = (ratio - 0.9) / 0.1;
    return .{ .r = 255, .g = @intFromFloat(100 * (1 - t)), .b = 0, .a = 255 };
}

pub fn tyreTempColor(temp: f32) rl.Color {
    if (temp < 60) {
        const t = @max(0.0, temp / 60.0);
        return .{ .r = @intFromFloat(50 * t), .g = @intFromFloat(100 * t), .b = 255, .a = 255 };
    }
    if (temp < 85) {
        const t = (temp - 60) / 25.0;
        return .{ .r = 0, .g = @intFromFloat(180 + 75 * t), .b = @intFromFloat(255 * (1 - t)), .a = 255 };
    }
    if (temp < 105) {
        const t = (temp - 85) / 20.0;
        return .{ .r = @intFromFloat(200 * t), .g = 255, .b = 0, .a = 255 };
    }
    if (temp < 120) {
        const t = (temp - 105) / 15.0;
        return .{ .r = 255, .g = @intFromFloat(255 * (1 - t)), .b = 0, .a = 255 };
    }
    return .{ .r = 255, .g = 0, .b = 0, .a = 255 };
}

pub fn gearColor(gear: u8, rpm_ratio: f32, tick_ms: u32) rl.Color {
    if (gear == 0) return .{ .r = 255, .g = 40, .b = 40, .a = 255 };
    if (rpm_ratio > 0.95 and (tick_ms / 75) % 2 == 0) return .{ .r = 255, .g = 40, .b = 40, .a = 255 };
    return .{ .r = 245, .g = 245, .b = 250, .a = 255 };
}

pub const muted = rl.Color{ .r = 150, .g = 155, .b = 165, .a = 255 };
pub const label = rl.Color{ .r = 100, .g = 200, .b = 255, .a = 255 };
pub const panel = rl.Color{ .r = 18, .g = 20, .b = 26, .a = 255 };
pub const panel_edge = rl.Color{ .r = 40, .g = 48, .b = 62, .a = 255 };
pub const delta_blue = rl.Color{ .r = 100, .g = 210, .b = 255, .a = 255};
