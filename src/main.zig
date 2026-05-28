const std = @import("std");
const Forza = @import("forza.zig");
const gui = @import("gui.zig");
const units = @import("units.zig");
const display = @import("display.zig");
const tui = @import("terminal_ui.zig");

const default_font = "C:/Windows/Fonts/arialbd.ttf";

pub const TelemetryBus = struct {
    mutex: std.Io.Mutex = .init,
    latest: ?Forza.Packet = null,
    show_when_not_racing: bool = true,
    io: std.Io,

    pub fn update(self: *TelemetryBus, pkt: Forza.Packet) void {
        if (!self.show_when_not_racing and pkt.is_race_on == 0) return;
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        self.latest = pkt;
    }

    pub fn snapshot(self: *TelemetryBus) ?Forza.Packet {
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        return self.latest;
    }
};

const Config = struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 20067,
    units: units.Units = .imperial,
    show_when_not_racing: bool = true,
    terminal: bool = false,
    font_path: []const u8 = default_font,
    window_x: i32 = 0,
    window_y: i32 = 0,
};

fn parseArgs(args: []const []const u8) !Config {
    var cfg = Config{};
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a = args[i];
        if (std.mem.eql(u8, a, "--host")) {
            i += 1;
            if (i >= args.len) return error.MissingHostValue;
            cfg.host = args[i];
        } else if (std.mem.eql(u8, a, "--port")) {
            i += 1;
            if (i >= args.len) return error.MissingPortValue;
            cfg.port = try std.fmt.parseInt(u16, args[i], 10);
        } else if (std.mem.eql(u8, a, "--metric")) {
            cfg.units = .metric;
        } else if (std.mem.eql(u8, a, "--imperial")) {
            cfg.units = .imperial;
        } else if (std.mem.eql(u8, a, "--only-racing")) {
            cfg.show_when_not_racing = false;
        } else if (std.mem.eql(u8, a, "--terminal")) {
            cfg.terminal = true;
        } else if (std.mem.eql(u8, a, "--font")) {
            i += 1;
            if (i >= args.len) return error.MissingFontValue;
            cfg.font_path = args[i];
        } else if (std.mem.eql(u8, a, "--pos")) {
            i += 1;
            if (i >= args.len) return error.MissingPosValue;
            var iter = std.mem.splitScalar(u8, args[i], ',');
            const xs = iter.next() orelse return error.InvalidPos;
            const ys = iter.next() orelse return error.InvalidPos;
            cfg.window_x = try std.fmt.parseInt(i32, xs, 10);
            cfg.window_y = try std.fmt.parseInt(i32, ys, 10);
        } else if (std.mem.eql(u8, a, "--help")) {
            return error.ShowHelp;
        } else {
            return error.UnknownArg;
        }
    }
    return cfg;
}

fn printHelp(io: std.Io) !void {
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    try stdout.writeAll(
        \\zig-dashboard — Forza Horizon 6 telemetry dashboard
        \\
        \\Usage:
        \\  zig-dashboard [options]
        \\
        \\Options:
        \\  --host 127.0.0.1     UDP bind address (default)
        \\  --port 20067         UDP port (default)
        \\  --imperial           mph, HP, lb-ft, °F (default)
        \\  --metric             km/h, kW, Nm, °C
        \\  --only-racing        Ignore packets when not racing
        \\  --terminal           Text UI instead of graphical window
        \\  --font PATH          TTF for dashboard text
        \\  --pos X,Y            Window position (graphical mode)
        \\
    );
    try stdout.flush();
}

fn receiveLoop(bus: *TelemetryBus, sock: *const std.Io.net.Socket, io: std.Io) void {
    var buf: [2048]u8 = undefined;
    while (true) {
        const msg = sock.receive(io, &buf) catch break;
        const pkt = Forza.Packet.parse(msg.data) catch continue;
        bus.update(pkt);
    }
}

fn runTerminal(cfg: Config, sock: *const std.Io.net.Socket, io: std.Io) !void {
    tui.enableVirtualTerminal();
    var stdout_buffer: [8192]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;

    try stdout.print("Listening on {s}:{d} (terminal mode)\n", .{ cfg.host, cfg.port });
    try stdout.flush();

    var buf: [2048]u8 = undefined;
    while (true) {
        const msg = try sock.receive(io, &buf);
        const pkt = try Forza.Packet.parse(msg.data);
        if (!cfg.show_when_not_racing and pkt.is_race_on == 0) continue;

        try tui.clearScreen(stdout);
        const speed = units.speed(pkt, cfg.units);
        var gear_buf: [8]u8 = undefined;
        const gear_str = display.gearString(&gear_buf, pkt.gear);

        try stdout.print(
            \\FH6  Speed: {d:.0} {s}   Gear: {s}   RPM: {d:.0}
            \\      {d:.0} {s}   {d:.0} {s}
            \\
        , .{
            speed,
            units.speedLabel(cfg.units),
            gear_str,
            pkt.current_engine_rpm,
            units.power(pkt, cfg.units),
            units.powerLabel(cfg.units),
            units.torque(pkt, cfg.units),
            units.torqueLabel(cfg.units),
        });
        try tui.drawBar(stdout, "Throttle", pkt.throttle01(), 30);
        try tui.drawBar(stdout, "Brake", pkt.brake01(), 30);
        try stdout.flush();
    }
}

fn runGui(cfg: Config, sock: *const std.Io.net.Socket, io: std.Io) !void {
    var bus: TelemetryBus = .{ .show_when_not_racing = cfg.show_when_not_racing, .io = io };
    const thread = try std.Thread.spawn(.{}, receiveLoop, .{ &bus, sock, io });
    defer thread.join();

    const font_z = try std.heap.page_allocator.dupeZ(u8, cfg.font_path);
    defer std.heap.page_allocator.free(font_z);

    var g = try gui.Gui.init(.{}, font_z);
    defer g.deinit();
    const rl = @import("raylib");
    rl.setWindowPosition(cfg.window_x, cfg.window_y);

    const idle = Forza.Packet.waiting();

    while (!g.shouldClose()) {
        const pkt = bus.snapshot() orelse idle;
        g.draw(pkt, cfg.units);
    }
}

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);

    const cfg = parseArgs(args) catch |e| switch (e) {
        error.ShowHelp => {
            try printHelp(init.io);
            return;
        },
        else => return e,
    };

    const net = std.Io.net;
    const io = init.io;

    var bind_addr = try net.IpAddress.parse(cfg.host, cfg.port);
    var sock = try bind_addr.bind(io, .{ .mode = .dgram, .protocol = .udp });
    defer sock.close(io);

    if (cfg.terminal) {
        try runTerminal(cfg, &sock, io);
    } else {
        try runGui(cfg, &sock, io);
    }
}
