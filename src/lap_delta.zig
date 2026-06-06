const std = @import("std");

const BUCKET_METERS: f32 = 10.0;
const MAX_BUCKETS: usize = 6000;
const LAP_LENGTH_RATIO: f32 = 1.5;

pub const LapDelta = struct {
    best: [MAX_BUCKETS]f32,
    best_len: usize,
    best_total_time: f32,

    rec: [MAX_BUCKETS]f32,
    last_bucket: usize,

    recording_lap: u16,
    lap_start_dist: f32,
    initialized: bool,

    live_delta: ?f32,

    pub fn init() LapDelta {
        return .{
            .best = std.mem.zeroes([MAX_BUCKETS]f32),
            .best_len = 0,
            .best_total_time = 0.0,
            .rec = std.mem.zeroes([MAX_BUCKETS]f32),
            .last_bucket = 0,
            .recording_lap = 0,
            .lap_start_dist = 0.0,
            .initialized = false,
            .live_delta = null,
        };
    }

    pub fn update(self: *LapDelta, lap_number: u16, current_lap: f32, distance_traveled: f32) void {
        if (!self.initialized) {
            self.lap_start_dist = distance_traveled;
            self.recording_lap = lap_number;
            self.initialized = true;
            return;
        }

        if (lap_number != self.recording_lap) {
            const rec_len = self.last_bucket + 1;
            const total_time = self.rec[self.last_bucket];

            if (total_time > 0) {
                const best_is_short = self.best_len > 0 and
                    @as(f32, @floatFromInt(rec_len)) > @as(f32, @floatFromInt(self.best_len)) * LAP_LENGTH_RATIO;

                const is_faster = self.best_len == 0 or total_time < self.best_total_time;

                if (is_faster or best_is_short) {
                    @memcpy(self.best[0..rec_len], self.rec[0..rec_len]);
                    self.best_len = rec_len;
                    self.best_total_time = total_time;
                }
            }

            self.rec = std.mem.zeroes([MAX_BUCKETS]f32);
            self.last_bucket = 0;
            self.recording_lap = lap_number;
            self.lap_start_dist = distance_traveled;
            self.live_delta = null;
            return;
        }

        if (current_lap <= 0) return;

        const lap_dist = distance_traveled - self.lap_start_dist;
        if (lap_dist < 0) return;

        const bucket = @as(usize, @intFromFloat(lap_dist / BUCKET_METERS));
        if (bucket >= MAX_BUCKETS) return;

        self.rec[bucket] = current_lap;
        if (bucket > self.last_bucket) self.last_bucket = bucket;

        if (self.best_len == 0) {
            self.live_delta = null;
            return;
        }

        const best_is_short = @as(f32, @floatFromInt(self.last_bucket + 1)) > @as(f32, @floatFromInt(self.best_len)) * LAP_LENGTH_RATIO;
        if (best_is_short or bucket >= self.best_len) {
            self.live_delta = null;
            return;
        }

        self.live_delta = self.rec[bucket] - self.best[bucket];
    }

    pub fn format(self: *const LapDelta, buf: []u8) []const u8 {
        const delta = self.live_delta orelse return "--.---";
        const sign: u8 = if (delta >= 0) '+' else '-';
        const abs_ms: u32 = @intFromFloat(@abs(delta) * 1000.0);
        const secs = abs_ms / 1000;
        const millis = abs_ms % 1000;
        return std.fmt.bufPrint(buf, "{c}{d}.{d:0>3}", .{ sign, secs, millis }) catch "?";
    }
};
