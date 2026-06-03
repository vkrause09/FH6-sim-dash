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
            gui.font_xl = rl.loadFontEx(font_path, 120, null) catch default_font;
            gui.font_lg = rl.loadFontEx(font_path, 72, null) catch default_font;
            gui.font_md = rl.loadFontEx(font_path, 55, null) catch default_font;
            gui.font_sm = rl.loadFontEx(font_path, 20, null) catch default_font;
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

        // left panel box
        const lp_w: i32 = 250;
        rl.drawRectangle(0, 80, lp_w, h - 160, display.panel);
        rl.drawRectangle(lp_w, 80, 2, h - 160, display.panel_edge);
        rl.drawRectangle(125, 80, 2, 280, display.panel_edge);
        rl.drawRectangle(0, 220, 250, 2, display.panel_edge);

        //right panel box
        const rp_x: i32 = w - 250;
        rl.drawRectangle(rp_x, 80, 250, h - 160, display.panel);
        rl.drawRectangle(rp_x, 80, 2, h - 160, display.panel_edge);

        //left quarter box
        const lq_x: i32 = 252;
        const q_w: i32 = 98;
        rl.drawRectangle(lq_x, 80, q_w, h - 160, display.panel);
        rl.drawRectangle(lq_x + q_w, 80, 1, h - 160, display.panel_edge);
        rl.drawRectangle(lq_x + 33, 80, 1, h - 160, display.panel_edge);
        rl.drawRectangle(lq_x + 66, 80, 1, h - 160, display.panel_edge);

        //right quarter box
        const rq_x: i32 = 674;
        rl.drawRectangle(rq_x + 2, 80, q_w, h - 160, display.panel);
        rl.drawRectangle(rq_x, 80, 1, h - 160, display.panel_edge);
        rl.drawRectangle(rq_x + 33, 80, 1, h - 160, display.panel_edge);
        rl.drawRectangle(rq_x + 66, 80, 1, h - 160, display.panel_edge);

        //rpm - top and bottom
        const rpm_r = display.rpmRatio(pkt.current_engine_rpm, pkt.engine_max_rpm);
        drawTach(self, w, h, rpm_r);

        //left panel filling

        //tires
        const temps = [_]f32{
            units.tyreTemp(pkt.tire_temp_fl, unit_mode),
            units.tyreTemp(pkt.tire_temp_fr, unit_mode),
            units.tyreTemp(pkt.tire_temp_rl, unit_mode),
            units.tyreTemp(pkt.tire_temp_rr, unit_mode),
        };
        drawTyres(self, temps[0..]);

        rl.drawRectangle(0, 360, lp_w, 2, display.panel_edge);

        //center (gear)
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
        const gear_y: i32 = 169; //nice

        //shift light
        if (rpm_r > 0.9) {
            const tick_ms: u32 = @intFromFloat(tick);
            if ((tick_ms / 80) % 2 == 0) {
                const w_pad: i32 = 48;
                const h_pad: i32 = 1;
                const box_x: i32 = gear_x - w_pad;
                const box_y: i32 = gear_y - h_pad;
                const box_w: i32 = @as(i32, @intFromFloat(gear_size.x)) + w_pad * 2;
                const box_h: i32 = @as(i32, @intFromFloat(gear_size.y)) + h_pad * 2;

                rl.drawRectangle(box_x, box_y, box_w, box_h, .{ .r = 210, .g = 0, .b = 0, .a = 210 });
                rl.drawRectangleLinesEx(
                    rl.Rectangle.init(
                        @floatFromInt(box_x),
                        @floatFromInt(box_y),
                        @floatFromInt(box_w),
                        @floatFromInt(box_h),
                    ),
                    5,
                    .{ .r = 255, .g = 0, .b = 0, .a = 255 },
                );
            }
        }

        drawTextZ(self.font_gear, gear_str, gear_x, gear_y, gear_col);

        //right panel filling

        //speed label
        const speed = units.speed(pkt, unit_mode);
        drawLabel(self, 785, 360, units.speedLabel(unit_mode), self.font_sm, display.muted);
        drawValueBlock(self, 830, 365, "{d}", .{@as(i32, @intFromFloat(speed))}, self.font_lg, .white);

        //divider between speed and rpm
        rl.drawRectangle(774, 440, 250, 1, display.panel_edge);

        //rpm label
        drawLabel(self, 785, 440, "RPM", self.font_sm, display.muted);
        drawValueBlock(self, 830, 450, "{d}", .{@as(i32, @intFromFloat(pkt.current_engine_rpm))}, self.font_lg, .white);

        //laps panel
        drawLapPanel(self, pkt, w);
    }
};

fn drawTach(gui: *Gui, width: i32, height: i32, rpm_ratio: f32) void {
    const tach_h: i32 = 80;
    const ty_bottom: i32 = height - tach_h;
    const ty_top: i32 = 0;
    //bottom
    rl.drawRectangle(0, ty_bottom, width, tach_h, .{ .r = 22, .g = 24, .b = 30, .a = 255 });
    rl.drawRectangle(0, ty_bottom, width, 3, .{ .r = 0, .g = 180, .b = 255, .a = 120 });
    //top
    rl.drawRectangle(0, ty_top, width, tach_h, .{ .r = 22, .g = 24, .b = 30, .a = 255 });
    rl.drawRectangle(0, ty_top, width, 3, .{ .r = 0, .g = 180, .b = 255, .a = 120 });

    const fill_w: i32 = @intFromFloat(@as(f32, @floatFromInt(width)) * rpm_ratio);
    var x: i32 = 0;
    while (x < fill_w) : (x += 2) {
        const ratio = @as(f32, @floatFromInt(x)) / @as(f32, @floatFromInt(width));
        rl.drawRectangle(x, ty_bottom + 4, 2, tach_h - 4, display.rpmColor(ratio));
        rl.drawRectangle(x, ty_top + 4, 2, tach_h - 4, display.rpmColor(ratio));
    }
    _ = gui;
}

fn drawTyres(gui: *Gui, temps: []const f32) void {
    const labels = [_][]const u8{ "FL", "FR", "RL", "RR" };
    const tw: i32 = 90;
    const th: i32 = 60;
    const gap: i32 = 15;
    const x0: i32 = 25;
    const y0: i32 = 372;

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
    const right: i32 = width - 20;
    const lx: i32 = width - 250;
    var tbuf: [16]u8 = undefined;

    //current lap
    drawLabel(gui, lx + 10, 85, "CURRENT LAP", gui.font_sm, display.muted);
    const cur = display.formatLapTime(pkt.current_lap, &tbuf);
    drawRightText(gui, right, 100, cur, gui.font_md, .white);

    rl.drawRectangle(lx, 167, 250, 1, display.panel_edge);

    //best lap
    drawLabel(gui, lx + 10, 172, "BEST LAP", gui.font_sm, display.label);
    const best = display.formatLapTime(pkt.best_lap, &tbuf);
    drawRightText(gui, right, 187, best, gui.font_md, display.label);

    rl.drawRectangle(lx, 253, 250, 1, display.panel_edge);

    //last lap
    drawLabel(gui, lx + 10, 258, "LAST LAP", gui.font_sm, display.label);
    const last = display.formatLapTime(pkt.last_lap, &tbuf);
    drawRightText(gui, right, 273, last, gui.font_md, .white);

    rl.drawRectangle(lx, 340, 250, 1, display.panel_edge);
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
