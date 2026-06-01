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
                const pos = rl.getMonitorPostion(i);
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
            gui.font_md = rl.loadFontEx(font_path, 36, null) catch default_font;
            gui.font_sm = rl.loadFontEx(font_path, 20, null) catch default_font;
            gui.laoded_custom = true;
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
        rl.drawRectangle(lp_w, 20, 2, h - 160, display.panel_edge);
        
        //right panel box
        const rp_x: i32 = w - 250;
        rl.drawRectangle(rp_x, 80, 250, h - 160, display.panel);
        rl.drawRectangle(rp_x, 80, 2, h - 160, display.panel_edge);


        //rpm - top and bottom
        const rpm_r = display.rpmRatio(pkt.current_engine_rpm, pkt.engine_max_rpm);
        drawTach(self, w, h, rpm_r);

        //left panel filling
        const temps = [_]f32 {
            units.tyreTemp(pkt.tire_temp_fl, unit_mode),
            units.tyreTemp(pkt.tire_temp_fr, unit_mode),
            units.tyreTemp(pkt.tire_temp_rl, unit_mode),
            units.tyreTemp(pkt.tire_temp_rr, unit_mode),
        };
        drawTyres(self, temps[0..], unit_mode);

        

        



    }
};

fn drawTach(gui: *Gui, width: i32, height: i32, rpm_ratio: f32) void {
    const tach_h: i32 = 80;
    const ty_bottom: i32 = height - tach_h;
    const ty_top: i32 = tach_h;
    //bottom
    rl.drawRectangle(0, ty_bottom, width, tach_h, .{ .r = 22, .g = 24, .b = 30, .a = 255 });
    rl.drawRectangle(0, ty_bottom, width, 3, .{ .r = 0, .g = 180, .b = 255, .a = 120 });
    //top
    rl.drawRectangle(0, ty_top, width, tach_h, .{ .r = 22, .g = 24, .b = 30, .a = 255 });
    rl.drawRectangle(0, ty_top, width, 3, .{ .r = 0, .g = 180, .b = 255, .a = 120 });

    const fill_w: i32 = @intFromFloat(@as(f32, @floatFromInt(width)) * rpm_ratio);
    var x: i32 = 0;
    while (x < fill_w) : (x += 2) {
        const ratio =  @as(f32, @floatFromInt(x)) /  @as(f32, @floatFromInt(width));
        rl.drawRectangle(x, ty_bottom + 4, 2, tach_h - 4, display.rpmColor(ratio));
        rl.drawRectangle(x, ty_top + 4, 2, tach_h - 4, display.rpmColor(ratio));
    }
    _ = gui;
}

fn drawTyres(gui: *Gui, temps: []const f32, unit_mode: units.Units) void {
    const labels = [_][]const u8{ "FL", "FR", "RL", "RR" };
    const tw: i32 = 92;
    const th: i32 = 62;
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
        rl.drawRectanlge(x, y, tw, th, bg);
        rl.drawRectangle(rl.Rectangle.init(@floatFromInt(x), @floatFromInt(y), @floatFromInt(tw), @floatFromInt(th)), 2, .black);

        drawLabel(gui, x + 6, y + 4, labels[i], gui.font_sm, .black);
        var buf: [8]u8 = undefined;
        const temp_txt = std.fmt.bufPrint(&buf, "{d:.0}", .{t}) catch "?";
        const tw_txt = measureTextZ(gui.font_sm, temp_txt);
        drawLabel(gui, x + tw - @as(i32, @intFromFloat(tw_txt)) - 6, y + th - 24, temp_txt, gui.font_sm, .black);
    }
    // ----------------------Stopped Here ---------------------
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

fn drawLabel(_: *Gui, x: i32, y: i32, text: []const u8, font: rl.Font, color: rl.Color) void {
    drawTextZ(font, text, x, y, color);
}





































