const std = @import("std");

fn readIntLe(comptime T: type, bytes: []const u8, off: *usize) !T {
    const n = @sizeOf(T);
    if (off.* + n > bytes.len) return error.PacketTooShort;
    const v = std.mem.readInt(T, bytes[off.*..][0..n], .little);
    off.* += n;
    return v;
}

fn readF32Le(bytes: []const u8, off: *usize) !f32 {
    const raw = try readIntLe(u32, bytes, off);
    return @bitCast(raw);
}

pub const Packet = struct {
    // Forza Horizon 6 "Data Out" — 324 bytes, little-endian.
    // https://support.forza.net/hc/en-us/articles/51744149102611
    is_race_on: i32,
    timestamp_ms: u32,

    engine_max_rpm: f32,
    engine_idle_rpm: f32,
    current_engine_rpm: f32,

    acceleration_x: f32,
    acceleration_y: f32,
    acceleration_z: f32,

    velocity_x: f32,
    velocity_y: f32,
    velocity_z: f32,

    angular_velocity_x: f32,
    angular_velocity_y: f32,
    angular_velocity_z: f32,

    yaw: f32,
    pitch: f32,
    roll: f32,

    norm_susp_travel_fl: f32,
    norm_susp_travel_fr: f32,
    norm_susp_travel_rl: f32,
    norm_susp_travel_rr: f32,

    tire_slip_ratio_fl: f32,
    tire_slip_ratio_fr: f32,
    tire_slip_ratio_rl: f32,
    tire_slip_ratio_rr: f32,

    wheel_rot_speed_fl: f32,
    wheel_rot_speed_fr: f32,
    wheel_rot_speed_rl: f32,
    wheel_rot_speed_rr: f32,

    wheel_on_rumble_fl: i32,
    wheel_on_rumble_fr: i32,
    wheel_on_rumble_rl: i32,
    wheel_on_rumble_rr: i32,

    wheel_in_puddle_fl: f32,
    wheel_in_puddle_fr: f32,
    wheel_in_puddle_rl: f32,
    wheel_in_puddle_rr: f32,

    surface_rumble_fl: f32,
    surface_rumble_fr: f32,
    surface_rumble_rl: f32,
    surface_rumble_rr: f32,

    tire_slip_angle_fl: f32,
    tire_slip_angle_fr: f32,
    tire_slip_angle_rl: f32,
    tire_slip_angle_rr: f32,

    tire_combined_slip_fl: f32,
    tire_combined_slip_fr: f32,
    tire_combined_slip_rl: f32,
    tire_combined_slip_rr: f32,

    susp_travel_m_fl: f32,
    susp_travel_m_fr: f32,
    susp_travel_m_rl: f32,
    susp_travel_m_rr: f32,

    car_ordinal: i32,
    car_class: i32,
    car_performance_index: i32,
    drivetrain_type: i32,
    num_cylinders: i32,

    // FH6-only fields (not in FM / older Horizon Dash format)
    car_group: u32,
    smashable_vel_diff: f32,
    smashable_mass: f32,

    position_x: f32,
    position_y: f32,
    position_z: f32,

    speed_mps: f32,
    power_watts: f32,
    torque_nm: f32,

    tire_temp_fl: f32,
    tire_temp_fr: f32,
    tire_temp_rl: f32,
    tire_temp_rr: f32,

    boost: f32,
    fuel: f32,
    distance_traveled: f32,
    best_lap: f32,
    last_lap: f32,
    current_lap: f32,
    current_race_time: f32,

    lap_number: u16,
    race_position: u8,
    accel: u8,
    brake: u8,
    clutch: u8,
    handbrake: u8,
    gear: u8,
    steer: i8,
    normalized_driving_line: i8,
    normalized_ai_brake_diff: i8,

    pub fn waiting() Packet {
        var p = std.mem.zeroes(Packet);
        p.engine_max_rpm = 9000;
        p.engine_idle_rpm = 800;
        p.gear = 11;
        return p;
    }

    pub fn parse(bytes: []const u8) !Packet {
        if (bytes.len != 324) return error.PacketWrongSize;
        var off: usize = 0;

        return .{
            .is_race_on = try readIntLe(i32, bytes, &off),
            .timestamp_ms = try readIntLe(u32, bytes, &off),

            .engine_max_rpm = try readF32Le(bytes, &off),
            .engine_idle_rpm = try readF32Le(bytes, &off),
            .current_engine_rpm = try readF32Le(bytes, &off),

            .acceleration_x = try readF32Le(bytes, &off),
            .acceleration_y = try readF32Le(bytes, &off),
            .acceleration_z = try readF32Le(bytes, &off),

            .velocity_x = try readF32Le(bytes, &off),
            .velocity_y = try readF32Le(bytes, &off),
            .velocity_z = try readF32Le(bytes, &off),

            .angular_velocity_x = try readF32Le(bytes, &off),
            .angular_velocity_y = try readF32Le(bytes, &off),
            .angular_velocity_z = try readF32Le(bytes, &off),

            .yaw = try readF32Le(bytes, &off),
            .pitch = try readF32Le(bytes, &off),
            .roll = try readF32Le(bytes, &off),

            .norm_susp_travel_fl = try readF32Le(bytes, &off),
            .norm_susp_travel_fr = try readF32Le(bytes, &off),
            .norm_susp_travel_rl = try readF32Le(bytes, &off),
            .norm_susp_travel_rr = try readF32Le(bytes, &off),

            .tire_slip_ratio_fl = try readF32Le(bytes, &off),
            .tire_slip_ratio_fr = try readF32Le(bytes, &off),
            .tire_slip_ratio_rl = try readF32Le(bytes, &off),
            .tire_slip_ratio_rr = try readF32Le(bytes, &off),

            .wheel_rot_speed_fl = try readF32Le(bytes, &off),
            .wheel_rot_speed_fr = try readF32Le(bytes, &off),
            .wheel_rot_speed_rl = try readF32Le(bytes, &off),
            .wheel_rot_speed_rr = try readF32Le(bytes, &off),

            .wheel_on_rumble_fl = try readIntLe(i32, bytes, &off),
            .wheel_on_rumble_fr = try readIntLe(i32, bytes, &off),
            .wheel_on_rumble_rl = try readIntLe(i32, bytes, &off),
            .wheel_on_rumble_rr = try readIntLe(i32, bytes, &off),

            .wheel_in_puddle_fl = try readF32Le(bytes, &off),
            .wheel_in_puddle_fr = try readF32Le(bytes, &off),
            .wheel_in_puddle_rl = try readF32Le(bytes, &off),
            .wheel_in_puddle_rr = try readF32Le(bytes, &off),

            .surface_rumble_fl = try readF32Le(bytes, &off),
            .surface_rumble_fr = try readF32Le(bytes, &off),
            .surface_rumble_rl = try readF32Le(bytes, &off),
            .surface_rumble_rr = try readF32Le(bytes, &off),

            .tire_slip_angle_fl = try readF32Le(bytes, &off),
            .tire_slip_angle_fr = try readF32Le(bytes, &off),
            .tire_slip_angle_rl = try readF32Le(bytes, &off),
            .tire_slip_angle_rr = try readF32Le(bytes, &off),

            .tire_combined_slip_fl = try readF32Le(bytes, &off),
            .tire_combined_slip_fr = try readF32Le(bytes, &off),
            .tire_combined_slip_rl = try readF32Le(bytes, &off),
            .tire_combined_slip_rr = try readF32Le(bytes, &off),

            .susp_travel_m_fl = try readF32Le(bytes, &off),
            .susp_travel_m_fr = try readF32Le(bytes, &off),
            .susp_travel_m_rl = try readF32Le(bytes, &off),
            .susp_travel_m_rr = try readF32Le(bytes, &off),

            .car_ordinal = try readIntLe(i32, bytes, &off),
            .car_class = try readIntLe(i32, bytes, &off),
            .car_performance_index = try readIntLe(i32, bytes, &off),
            .drivetrain_type = try readIntLe(i32, bytes, &off),
            .num_cylinders = try readIntLe(i32, bytes, &off),

            .car_group = try readIntLe(u32, bytes, &off),
            .smashable_vel_diff = try readF32Le(bytes, &off),
            .smashable_mass = try readF32Le(bytes, &off),

            .position_x = try readF32Le(bytes, &off),
            .position_y = try readF32Le(bytes, &off),
            .position_z = try readF32Le(bytes, &off),

            .speed_mps = try readF32Le(bytes, &off),
            .power_watts = try readF32Le(bytes, &off),
            .torque_nm = try readF32Le(bytes, &off),

            .tire_temp_fl = try readF32Le(bytes, &off),
            .tire_temp_fr = try readF32Le(bytes, &off),
            .tire_temp_rl = try readF32Le(bytes, &off),
            .tire_temp_rr = try readF32Le(bytes, &off),

            .boost = try readF32Le(bytes, &off),
            .fuel = try readF32Le(bytes, &off),
            .distance_traveled = try readF32Le(bytes, &off),
            .best_lap = try readF32Le(bytes, &off),
            .last_lap = try readF32Le(bytes, &off),
            .current_lap = try readF32Le(bytes, &off),
            .current_race_time = try readF32Le(bytes, &off),

            .lap_number = try readIntLe(u16, bytes, &off),
            .race_position = try readIntLe(u8, bytes, &off),
            .accel = try readIntLe(u8, bytes, &off),
            .brake = try readIntLe(u8, bytes, &off),
            .clutch = try readIntLe(u8, bytes, &off),
            .handbrake = try readIntLe(u8, bytes, &off),
            .gear = try readIntLe(u8, bytes, &off),
            .steer = @bitCast(try readIntLe(u8, bytes, &off)),
            .normalized_driving_line = @bitCast(try readIntLe(u8, bytes, &off)),
            .normalized_ai_brake_diff = @bitCast(try readIntLe(u8, bytes, &off)),
        };
    }

    pub fn speedKmh(self: Packet) f32 {
        return self.speed_mps * 3.6;
    }

    pub fn speedMph(self: Packet) f32 {
        return self.speed_mps * 2.2369363;
    }

    pub fn throttle01(self: Packet) f32 {
        return @as(f32, @floatFromInt(self.accel)) / 255.0;
    }

    pub fn brake01(self: Packet) f32 {
        return @as(f32, @floatFromInt(self.brake)) / 255.0;
    }

    pub fn ebrake01(self: Packet) f32 {
        return @as(f32, @floatFromInt(self.handbrake)) / 255.0;
    }

    pub fn clutch01(self: Packet) f32 {
        return @as(f32, @floatFromInt(self.clutch)) / 255.0;
    }
};

