const std = @import("std");
const rl = @import("raylib");
const Forza = @import("forza.zig");
const display = @import("display.zig");
const units = @import("units.zig");

pub const Screen = struct {
    width: i32 = 1024,
    height: i32 = 600,
};

pub const Gui = struct {
    screen: Screen,
    font_path: [:0]const u8,
    font_gear: rl.Font,
    font_xl: rl.Font,
    font_lg: rl.Font,
    font_md: rl.Font,
    font_sm: rl.Font,
    loaded_custom: bool,

    pub fn init(screen: Screen, font_path: [:0]const u8) !Gui {
        rl.setConfigFlags(.{ .window_undecorated = false });
        rl.initWindow(screen.width, screen.height, "FH6 Dashboard");
        rl.setTargetFPS(60);

        const mon_count = rl.getMonitorCount();
        var target_mon: i32 = 0;
        if (mon_count > 1) {
            var best_y: f32 = -999999;
            var i: i32 = 0;
            while (i < mon_count) : (i += 1) {
                const pos = rl.getMonitorPosition(i);
                if (pos.y > best_y) {
                    best_y = pos.y;
                    target_mon = i;
                }
            }
            rl.setWindowMonitor(target_mon);
        }
        rl.toggleFullscreen();
        

        const default_font = try rl.getFontDefault();
        var gui: Gui = .{
            .screen = screen,
            .font_path = font_path,
            .font_gear = default_font,
            .font_xl = default_font,
            .font_lg = default_font,
            .font_md = default_font,
            .font_sm = default_font,
            .loaded_custom = false,
        };

        if (rl.fileExists(font_path)) {
            gui.font_gear = rl.loadFontEx(font_path, 350, null) catch default_font;
            gui.font_xl  = rl.loadFontEx(font_path, 120, null) catch default_font;
            gui.font_lg  = rl.loadFontEx(font_path, 72,  null) catch default_font;
            gui.font_md  = rl.loadFontEx(font_path, 36,  null) catch default_font;
            gui.font_sm  = rl.loadFontEx(font_path, 20,  null) catch default_font;
            gui.loaded_custom = true;
        }

        return gui;
    }

    pub fn deinit(self: *Gui) void {
        if (self.loaded_custom) {
            rl.unloadFont(self.font_gear);
            rl.unloadFont(self.font_xl);
            rl.unloadFont(self.font_lg);
            rl.unloadFont(self.font_md);
            rl.unloadFont(self.font_sm);
        }
        rl.closeWindow();
    }

    pub fn shouldClose(self: *const Gui) bool {
        _ = self;
        return rl.windowShouldClose();
    }

    pub fn draw(self: *Gui, pkt: Forza.Packet, unit_mode: units.Units) void {
        const w = self.screen.width;
        const h = self.screen.height;
        const tick = rl.getTime() * 1000;

        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(.{ .r = 6, .g = 7, .b = 10, .a = 255 });

        // ── Panel backgrounds ─────────────────────────────────────────────
        // Left panel  (tyres, speed, rpm)  — x: 0..220
        const lp_w: i32 = 220;
        rl.drawRectangle(0, 0, lp_w, h - 80, display.panel);
        rl.drawRectangle(lp_w, 0, 2, h - 80, display.panel_edge);

        // Right panel (lap times, position) — x: 800..1024
        const rp_x: i32 = w - 224;
        rl.drawRectangle(rp_x, 0, 224, h - 80, display.panel);
        rl.drawRectangle(rp_x, 0, 2, h - 80, display.panel_edge);

        // ── RPM tachometer (top, full width) ──────────────────────────────
        const rpm_r = display.rpmRatio(pkt.current_engine_rpm, pkt.engine_max_rpm);
        drawTach(self, w, h, rpm_r);

        // ── LEFT PANEL ────────────────────────────────────────────────────
        // Tyre temperatures  y: 86..246
        const temps = [_]f32{
            units.tyreTemp(pkt.tire_temp_fl, unit_mode),
            units.tyreTemp(pkt.tire_temp_fr, unit_mode),
            units.tyreTemp(pkt.tire_temp_rl, unit_mode),
            units.tyreTemp(pkt.tire_temp_rr, unit_mode),
        };
        drawTyres(self, temps[0..], unit_mode);

        // Divider between tyres and speed
        rl.drawRectangle(8, 176, lp_w - 16, 1, display.panel_edge);

        // Speed  y: 266..406  (label above value)
        const speed = units.speed(pkt, unit_mode);
        drawLabel(self, 12, 186, units.speedLabel(unit_mode), self.font_sm, display.muted);
        drawValueBlock(self, 12, 204, "{d}", .{@as(i32, @intFromFloat(speed))}, self.font_xl, .white);

        // Divider between speed and rpm
        rl.drawRectangle(8, 332, lp_w - 16, 1, display.panel_edge);

        // RPM  y: 420..560
        drawLabel(self, 12, 340, "RPM", self.font_sm, display.muted);
        drawValueBlock(self, 12, 358, "{d}", .{@as(i32, @intFromFloat(pkt.current_engine_rpm))}, self.font_xl, .white);

        // ── CENTER — Gear (y: 90) ─────────────────────────────────────────
        // Measure the glyph with measureTextEx so we get both width and height
        // for accurate shift-light box sizing.
        var gear_zbuf: [16]u8 = undefined;
        var gear_buf: [8]u8 = undefined;
        const gear_str = display.gearString(&gear_buf, pkt.gear);
        const gear_col = display.gearColor(pkt.gear, rpm_r, @intFromFloat(tick));
        @memcpy(gear_zbuf[0..gear_str.len], gear_str);
        gear_zbuf[gear_str.len] = 0;
        const gear_size = rl.measureTextEx(
            self.font_gear,
            gear_zbuf[0..gear_str.len :0],
            @floatFromInt(self.font_gear.baseSize),
            1,
        );
        const gear_x: i32 = @divTrunc(w, 2) - @as(i32, @intFromFloat(gear_size.x * 0.5));
        const gear_y: i32 = 100;

        // ── Shift light: flash red box when in the last 10% of RPM range ─
        if (rpm_r > 0.9) {
            const tick_ms: u32 = @intFromFloat(tick);
            if ((tick_ms / 80) % 2 == 0) {
                const pad: i32 = 40;
                const box_x: i32 = gear_x - pad;
                const box_y: i32 = gear_y - pad;
                const box_w: i32 = @as(i32, @intFromFloat(gear_size.x)) + pad * 2;
                const box_h: i32 = @as(i32, @intFromFloat(gear_size.y)) + pad * 2;
                // Semi-transparent red fill
                rl.drawRectangle(box_x, box_y, box_w, box_h,
                    .{ .r = 180, .g = 0, .b = 0, .a = 210 });
                // Solid red border
                rl.drawRectangleLinesEx(
                    rl.Rectangle.init(
                        @floatFromInt(box_x),
                        @floatFromInt(box_y),
                        @floatFromInt(box_w),
                        @floatFromInt(box_h),
                    ),
                    5,
                    .{ .r = 255, .g = 40, .b = 40, .a = 255 },
                );
            }
        }

        drawTextZ(self.font_gear, gear_str, gear_x, gear_y, gear_col);

        // ── RIGHT PANEL — Lap times ───────────────────────────────────────
        drawLapPanel(self, pkt, w);

        // ── Throttle / Brake bars (flanking centre, below gear) ───────────
        // Bars are placed at x ≈ 352 and 658 — well outside the gear glyph
        // (centred at x=512, glyph ≈ ±110 px) and below the gear bottom.
        drawInputBars(self, pkt.throttle01(), pkt.brake01(), w, h);

        // ── Power & Torque (bottom centre strip) ──────────────────────────
        const pwr = units.power(pkt, unit_mode);
        const trq = units.torque(pkt, unit_mode);
        var pwr_buf: [32]u8 = undefined;
        var trq_buf: [32]u8 = undefined;
        const pwr_txt = std.fmt.bufPrint(&pwr_buf, "{d:.0} {s}", .{ pwr, units.powerLabel(unit_mode) }) catch "?";
        const trq_txt = std.fmt.bufPrint(&trq_buf, "{d:.0} {s}", .{ trq, units.torqueLabel(unit_mode) }) catch "?";
        // y = h - 126: 36pt text ends at h-90, 10px above the tach at h-80.
        drawLabel(self, @divTrunc(w, 2) - 120, h - 126, pwr_txt, self.font_md, .{ .r = 180, .g = 220, .b = 255, .a = 255 });
        drawLabel(self, @divTrunc(w, 2) + 40,  h - 126, trq_txt, self.font_md, .{ .r = 180, .g = 220, .b = 255, .a = 255 });

        // ── Waiting overlay ───────────────────────────────────────────────
        if (pkt.is_race_on == 0) {
            drawLabel(self, @divTrunc(w, 2) - 220, @divTrunc(h - 80, 2) - 18, "WAITING FOR TELEMETRY", self.font_md, display.muted);
        }
    }
};

// ── Drawing helpers ───────────────────────────────────────────────────────────

fn drawTach(gui: *Gui, width: i32, height: i32, rpm_ratio: f32) void {
    const tach_h: i32 = 80;
    const ty: i32 = height - tach_h;
    rl.drawRectangle(0, ty, width, tach_h, .{ .r = 22, .g = 24, .b = 30, .a = 255 });

    // Accent line at the top edge of the tach bar
    rl.drawRectangle(0, ty, width, 3, .{ .r = 0, .g = 180, .b = 255, .a = 120 });

    const fill_w: i32 = @intFromFloat(@as(f32, @floatFromInt(width)) * rpm_ratio);
    var x: i32 = 0;
    while (x < fill_w) : (x += 2) {
        const ratio = @as(f32, @floatFromInt(x)) / @as(f32, @floatFromInt(width));
        rl.drawRectangle(x, ty + 4, 2, tach_h - 4, display.rpmColor(ratio));
    }
    _ = gui;
}

fn drawTyres(gui: *Gui, temps: []const f32, unit_mode: units.Units) void {
    const labels = [_][]const u8{ "FL", "FR", "RL", "RR" };
    const tw: i32 = 92;
    const th: i32 = 64;
    const gap: i32 = 10;
    const x0: i32 = 16;
    const y0: i32 = 28;

    drawLabel(gui, x0, 6, units.tyreTempLabel(unit_mode), gui.font_sm, display.muted);

    for (temps, 0..) |t, i| {
        const col: i32 = @intCast(i % 2);
        const row: i32 = @intCast(i / 2);
        const x = x0 + col * (tw + gap);
        const y = y0 + row * (th + gap);
        const bg = display.tyreTempColor(t);
        rl.drawRectangle(x, y, tw, th, bg);
        rl.drawRectangleLinesEx(rl.Rectangle.init(@floatFromInt(x), @floatFromInt(y), @floatFromInt(tw), @floatFromInt(th)), 2, .black);

        drawLabel(gui, x + 6, y + 4, labels[i], gui.font_sm, .black);
        var buf: [8]u8 = undefined;
        const temp_txt = std.fmt.bufPrint(&buf, "{d:.0}", .{t}) catch "?";
        const tw_txt = measureTextZ(gui.font_sm, temp_txt);
        drawLabel(gui, x + tw - @as(i32, @intFromFloat(tw_txt)) - 6, y + th - 24, temp_txt, gui.font_sm, .black);
    }
}

fn drawLapPanel(gui: *Gui, pkt: Forza.Packet, width: i32) void {
    // Right-align values to width-20; labels start at width-212 (inside panel).
    const right: i32 = width - 20;
    const lx: i32    = width - 212;
    var tbuf: [16]u8 = undefined;

    // Current lap  y: 96..188
    drawLabel(gui, lx, 16, "CURRENT LAP", gui.font_sm, display.muted);
    const cur = display.formatLapTime(pkt.current_lap, &tbuf);
    drawRightText(gui, right, 36, cur, gui.font_lg, .white);

    rl.drawRectangle(lx, 120, 192, 1, display.panel_edge);

    // Best lap  y: 208..300
    drawLabel(gui, lx, 128, "BEST LAP", gui.font_sm, display.label);
    const best = display.formatLapTime(pkt.best_lap, &tbuf);
    drawRightText(gui, right, 148, best, gui.font_lg, display.label);

    rl.drawRectangle(lx, 234, 192, 1, display.panel_edge);

    // Last lap  y: 322..360
    drawLabel(gui, lx, 242, "LAST LAP", gui.font_sm, display.muted);
    const last = display.formatLapTime(pkt.last_lap, &tbuf);
    drawRightText(gui, right, 262, last, gui.font_lg, .white);

    rl.drawRectangle(lx, 348, 192, 1, display.panel_edge);

    // Race position  y: 404..440
    var pos_buf: [16]u8 = undefined;
    const pos_txt = std.fmt.bufPrint(&pos_buf, "P{d}", .{pkt.race_position}) catch "?";
    drawRightText(gui, right, 370, pos_txt, gui.font_lg, display.muted);
}

fn drawInputBars(gui: *Gui, throttle: f32, brake: f32, width: i32, height: i32) void {
    // bar_h=160, base_y=height-30 → bars span y: (height-190)..(height-30)
    // With height=600 that is y: 410..570 — below the gear (which ends ~y:370).
    // Bars are placed at x≈352 (brake) and x≈658 (throttle), flanking the centre.
    const bar_h: i32 = 480;
    const bar_w: i32 = 10;
    const base_y: i32 = height - 110;
    const brake_x: i32 = @divTrunc(width, 2) - 280; // ≈ 352
    const thr_x:   i32 = @divTrunc(width, 2) + 270; // ≈ 658

    drawVerticalBar(brake_x, base_y, bar_w, bar_h, brake,    .{ .r = 255, .g = 55,  .b = 55, .a = 255 });
    drawVerticalBar(thr_x,   base_y, bar_w, bar_h, throttle, .{ .r = 35,  .g = 230, .b = 90, .a = 255 });

    // Labels sit just above each bar
    drawLabel(gui, brake_x, base_y + 7, "B", gui.font_sm, display.muted);
    drawLabel(gui, thr_x, base_y + 7, "T", gui.font_sm, display.muted);
}

fn drawVerticalBar(x: i32, base_y: i32, w: i32, h: i32, value01: f32, color: rl.Color) void {
    const v = std.math.clamp(value01, 0, 1);
    const y_top = base_y - h;
    rl.drawRectangle(x, y_top, w, h, .{ .r = 28, .g = 30, .b = 38, .a = 255 });
    const filled: i32 = @intFromFloat(@round(v * @as(f32, @floatFromInt(h))));
    rl.drawRectangle(x, base_y - filled, w, filled, color);
    rl.drawRectangleLinesEx(rl.Rectangle.init(@floatFromInt(x), @floatFromInt(y_top), @floatFromInt(w), @floatFromInt(h)), 1, display.panel_edge);
}

fn toZ(buf: []u8, text: []const u8) [:0]const u8 {
    @memcpy(buf[0..text.len], text);
    buf[text.len] = 0;
    return buf[0..text.len :0];
}

fn measureTextZ(font: rl.Font, text: []const u8) f32 {
    var buf: [128]u8 = undefined;
    if (text.len >= buf.len) return 0;
    return rl.measureTextEx(font, toZ(&buf, text), @floatFromInt(font.baseSize), 1).x;
}

fn drawTextZ(font: rl.Font, text: []const u8, x: i32, y: i32, color: rl.Color) void {
    var buf: [128]u8 = undefined;
    if (text.len >= buf.len) return;
    rl.drawTextEx(
        font,
        toZ(&buf, text),
        rl.Vector2.init(@floatFromInt(x), @floatFromInt(y)),
        @floatFromInt(font.baseSize),
        1,
        color,
    );
}

fn drawValueBlock(_: *Gui, x: i32, y: i32, comptime fmt: []const u8, args: anytype, font: rl.Font, color: rl.Color) void {
    var buf: [32]u8 = undefined;
    const txt = std.fmt.bufPrint(&buf, fmt, args) catch "?";
    drawTextZ(font, txt, x, y, color);
}

fn drawLabel(_: *Gui, x: i32, y: i32, text: []const u8, font: rl.Font, color: rl.Color) void {
    drawTextZ(font, text, x, y, color);
}

fn drawRightText(gui: *Gui, right_x: i32, y: i32, text: []const u8, font: rl.Font, color: rl.Color) void {
    const tw = measureTextZ(font, text);
    drawLabel(gui, right_x - @as(i32, @intFromFloat(tw)), y, text, font, color);
}
