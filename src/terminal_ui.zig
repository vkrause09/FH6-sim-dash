const std = @import("std");

pub const Units = enum { metric, imperial };

pub fn enableVirtualTerminal() void {
    // Zig 0.16 moved Windows console APIs around; modern Windows terminals
    // generally support ANSI escapes by default, so we keep this as a no-op.
    _ = std;
}

pub fn clearScreen(w: anytype) !void {
    try w.writeAll("\x1b[2J\x1b[H");
}

pub fn drawBar(w: anytype, label: []const u8, value01: f32, width: usize) !void {
    const v = std.math.clamp(value01, 0.0, 1.0);
    const filled: usize = @intFromFloat(@round(v * @as(f32, @floatFromInt(width))));
    try w.print("{s}: [", .{label});
    var i: usize = 0;
    while (i < width) : (i += 1) {
        if (i < filled) {
            try w.writeByte('#');
        } else {
            try w.writeByte('-');
        }
    }
    try w.print("] {d:>3.0}%\n", .{v * 100.0});
}

pub fn gearString(buf: []u8, gear: u8) []const u8 {
    // FH6 Data Out: 0 = R, 1–10 = forward gears, 11 = neutral
    if (gear == 0) return "R";
    if (gear == 11) return "N";
    const n = std.fmt.bufPrint(buf, "{d}", .{gear}) catch return "?";
    return n;
}

