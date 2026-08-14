const std = @import("std");

pub const FunctionCase = enum {
    lower_camel,
    pascal,
    snake,
    upper_snake,
    unchanged,
};

pub const TypeMapping = struct {
    type_name: []const u8,
    prefix: []const u8,
};

pub const TypePrefixMatch = struct {
    prefix: []const u8,
    consumed_pointer_depth: usize = 0,
};

pub const VariableStyle = enum {
    upper_snake,
};

pub const VariableCase = enum {
    lower_camel,
    pascal,
    snake,
    hungarian,
};

pub const Config = struct {
    local_prefix: []const u8 = "",
    static_local_prefix: []const u8 = "s_",
    member_prefix: []const u8 = "m_",
    static_member_prefix: []const u8 = "s_",
    global_prefix: []const u8 = "g_",
    static_global_prefix: []const u8 = "s_",

    member_function_case: FunctionCase = .lower_camel,
    free_function_case: FunctionCase = .lower_camel,
    inline_function_case: ?FunctionCase = null,
    variable_case: VariableCase = .pascal,

    scan_local: bool = true,
    scan_static_local: bool = true,
    scan_member: bool = true,
    scan_static_member: bool = true,
    scan_global: bool = true,
    scan_static_global: bool = true,
    scan_functions: bool = true,

    clang_downgrade_all_warnings: bool = false,
    clang_downgrade_warnings: std.ArrayList([]const u8) = .empty,

    use_canonical_type: bool = true,
    legacy_prefixes: bool = true,
    pointer_marker: []const u8 = "p",

    local_alternatives: std.ArrayList(VariableStyle) = .empty,
    static_local_alternatives: std.ArrayList(VariableStyle) = .empty,
    member_alternatives: std.ArrayList(VariableStyle) = .empty,
    static_member_alternatives: std.ArrayList(VariableStyle) = .empty,
    global_alternatives: std.ArrayList(VariableStyle) = .empty,
    static_global_alternatives: std.ArrayList(VariableStyle) = .empty,

    const_local_alternatives: std.ArrayList(VariableStyle) = .empty,
    const_static_local_alternatives: std.ArrayList(VariableStyle) = .empty,
    const_member_alternatives: std.ArrayList(VariableStyle) = .empty,
    const_static_member_alternatives: std.ArrayList(VariableStyle) = .empty,
    const_global_alternatives: std.ArrayList(VariableStyle) = .empty,
    const_static_global_alternatives: std.ArrayList(VariableStyle) = .empty,

    mappings: std.ArrayList(TypeMapping) = .empty,
    pointer_mappings: std.ArrayList(TypeMapping) = .empty,
    pointer_type_mappings: std.ArrayList(TypeMapping) = .empty,
    array_mappings: std.ArrayList(TypeMapping) = .empty,
    legacy_mappings: std.ArrayList(TypeMapping) = .empty,
    legacy_pointer_mappings: std.ArrayList(TypeMapping) = .empty,

    pub fn deinit(self: *Config, allocator: std.mem.Allocator) void {
        self.clang_downgrade_warnings.deinit(allocator);

        self.local_alternatives.deinit(allocator);
        self.static_local_alternatives.deinit(allocator);
        self.member_alternatives.deinit(allocator);
        self.static_member_alternatives.deinit(allocator);
        self.global_alternatives.deinit(allocator);
        self.static_global_alternatives.deinit(allocator);

        self.const_local_alternatives.deinit(allocator);
        self.const_static_local_alternatives.deinit(allocator);
        self.const_member_alternatives.deinit(allocator);
        self.const_static_member_alternatives.deinit(allocator);
        self.const_global_alternatives.deinit(allocator);
        self.const_static_global_alternatives.deinit(allocator);

        self.mappings.deinit(allocator);
        self.pointer_mappings.deinit(allocator);
        self.pointer_type_mappings.deinit(allocator);
        self.array_mappings.deinit(allocator);
        self.legacy_mappings.deinit(allocator);
        self.legacy_pointer_mappings.deinit(allocator);
    }

    pub fn initDefaults(allocator: std.mem.Allocator) !Config {
        var config = Config{};
        errdefer config.deinit(allocator);

        const legacy_defaults = [_]TypeMapping{
            .{ .type_name = "bool", .prefix = "b" },
            .{ .type_name = "char", .prefix = "ch" },
            .{ .type_name = "short", .prefix = "n" },
            .{ .type_name = "int", .prefix = "n" },
            .{ .type_name = "long", .prefix = "n" },
            .{ .type_name = "long long", .prefix = "n" },
            .{ .type_name = "unsigned int", .prefix = "n" },
            .{ .type_name = "unsigned long", .prefix = "n" },
            .{ .type_name = "float", .prefix = "f" },
            .{ .type_name = "double", .prefix = "d" },
            .{ .type_name = "std::string", .prefix = "s" },
            .{ .type_name = "std::basic_string<char>", .prefix = "s" },
            .{ .type_name = "std::vector", .prefix = "vec" },
            .{ .type_name = "std::map", .prefix = "map" },
        };
        const neutral_defaults = [_]TypeMapping{
            .{ .type_name = "bool", .prefix = "" },
            .{ .type_name = "char", .prefix = "" },
            .{ .type_name = "short", .prefix = "" },
            .{ .type_name = "int", .prefix = "" },
            .{ .type_name = "long", .prefix = "" },
            .{ .type_name = "long long", .prefix = "" },
            .{ .type_name = "unsigned int", .prefix = "" },
            .{ .type_name = "unsigned long", .prefix = "" },
            .{ .type_name = "float", .prefix = "" },
            .{ .type_name = "double", .prefix = "" },
            .{ .type_name = "std::string", .prefix = "" },
            .{ .type_name = "std::basic_string<char>", .prefix = "" },
            .{ .type_name = "std::vector", .prefix = "" },
            .{ .type_name = "std::map", .prefix = "" },
        };

        try config.legacy_mappings.appendSlice(allocator, &legacy_defaults);
        try config.mappings.appendSlice(allocator, &neutral_defaults);
        try config.legacy_pointer_mappings.append(allocator, .{ .type_name = "char", .prefix = "s" });
        try config.pointer_mappings.append(allocator, .{ .type_name = "char", .prefix = "" });

        return config;
    }

    pub fn typePrefix(self: *const Config, spelling: []const u8, pointer_depth: usize) ?[]const u8 {
        return self.typePrefixForShape(spelling, pointer_depth, 0);
    }

    pub fn typePrefixForShape(
        self: *const Config,
        spelling: []const u8,
        pointer_depth: usize,
        array_depth: usize,
    ) ?[]const u8 {
        const match = self.typePrefixMatchForShape(spelling, pointer_depth, array_depth) orelse return null;
        return match.prefix;
    }

    pub fn typePrefixMatchForShape(
        self: *const Config,
        spelling: []const u8,
        pointer_depth: usize,
        array_depth: usize,
    ) ?TypePrefixMatch {
        const normalized = normalizeTypeSpelling(spelling);

        if (findPointerTypeMapping(self.pointer_type_mappings.items, normalized, pointer_depth)) |match|
            return match;
        if (pointer_depth > 0) {
            if (findMapping(self.pointer_mappings.items, normalized)) |prefix| return .{ .prefix = prefix };
        }
        if (array_depth > 0) {
            if (findMapping(self.array_mappings.items, normalized)) |prefix| return .{ .prefix = prefix };
            return null;
        }

        if (findMapping(self.mappings.items, normalized)) |prefix| return .{ .prefix = prefix };
        return null;
    }

    fn findPointerTypeMapping(
        mappings: []const TypeMapping,
        spelling: []const u8,
        pointer_depth: usize,
    ) ?TypePrefixMatch {
        var best: ?TypePrefixMatch = null;
        var i = mappings.len;
        while (i > 0) {
            i -= 1;
            const mapping = mappings[i];
            const shape = pointerTypeShape(mapping.type_name) orelse continue;
            if (shape.pointer_depth > pointer_depth) continue;
            if (!typeNameMatchesNormalized(spelling, normalizeTypeSpelling(shape.base_type))) continue;
            if (best == null or shape.pointer_depth > best.?.consumed_pointer_depth) {
                best = .{
                    .prefix = mapping.prefix,
                    .consumed_pointer_depth = shape.pointer_depth,
                };
            }
        }

        return best;
    }

    fn findMapping(mappings: []const TypeMapping, spelling: []const u8) ?[]const u8 {
        var i = mappings.len;
        while (i > 0) {
            i -= 1;
            const mapping = mappings[i];

            if (typeNameMatchesNormalized(spelling, mapping.type_name)) return mapping.prefix;
        }

        return null;
    }

    fn normalizeTypeSpelling(spelling: []const u8) []const u8 {
        var result = std.mem.trim(u8, spelling, " \t");
        var changed = true;

        while (changed) {
            changed = false;
            inline for (.{ "const ", "volatile ", "restrict " }) |qualifier| {
                if (std.mem.startsWith(u8, result, qualifier)) {
                    result = std.mem.trimStart(u8, result[qualifier.len..], " \t");
                    changed = true;
                }
            }
        }

        return result;
    }
};

const PointerTypeShape = struct {
    base_type: []const u8,
    pointer_depth: usize,
};

fn pointerTypeShape(configured_type: []const u8) ?PointerTypeShape {
    var remaining = std.mem.trim(u8, configured_type, " \t");
    var pointer_depth: usize = 0;

    while (remaining.len > 0 and remaining[remaining.len - 1] == '*') {
        pointer_depth += 1;
        remaining = std.mem.trimEnd(u8, remaining[0 .. remaining.len - 1], " \t");
    }

    if (pointer_depth == 0 or remaining.len == 0) return null;
    return .{ .base_type = remaining, .pointer_depth = pointer_depth };
}

pub fn typeNameMatches(spelling: []const u8, configured_type: []const u8) bool {
    return typeNameMatchesNormalized(Config.normalizeTypeSpelling(spelling), configured_type);
}

fn typeNameMatchesNormalized(spelling: []const u8, configured_type: []const u8) bool {
    if (std.mem.eql(u8, spelling, configured_type)) return true;
    return std.mem.startsWith(u8, spelling, configured_type) and
        spelling.len > configured_type.len and
        spelling[configured_type.len] == '<';
}

pub fn load(io: std.Io, allocator: std.mem.Allocator, path: ?[]const u8) !Config {
    var config = try Config.initDefaults(allocator);
    errdefer config.deinit(allocator);

    const config_path = path orelse "ident-mod.toml";

    const contents = std.Io.Dir.cwd().readFileAlloc(io, config_path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => if (path == null) return config else return err,
        else => return err,
    };
    defer allocator.free(contents);

    var section: []const u8 = "";
    var lines = std.mem.splitScalar(u8, contents, '\n');
    var line_number: usize = 0;

    while (lines.next()) |raw_line| {
        line_number += 1;

        const without_comment = stripComment(raw_line);
        const line = std.mem.trim(u8, without_comment, " \t\r");
        if (line.len == 0) continue;

        if (line[0] == '[' and line[line.len - 1] == ']') {
            section = std.mem.trim(u8, line[1 .. line.len - 1], " \t");
            continue;
        }

        const equals = std.mem.indexOfScalar(u8, line, '=') orelse {
            std.log.err("{s}:{d}: expected key = value", .{ config_path, line_number });
            return error.InvalidConfig;
        };
        const key = std.mem.trim(u8, line[0..equals], " \t");
        const value_text = std.mem.trim(u8, line[equals + 1 ..], " \t");

        if (std.mem.eql(u8, section, "scope")) {
            const value = try parseString(allocator, value_text);
            if (!setScopePrefix(&config, key, value))
                return invalidKey(config_path, line_number, section, key);
        } else if (std.mem.eql(u8, section, "scan")) {
            const enabled = parseBool(value_text) orelse {
                std.log.err("{s}:{d}: scan switches must be true or false", .{ config_path, line_number });
                return error.InvalidConfig;
            };
            if (!setScanEnabled(&config, key, enabled))
                return invalidKey(config_path, line_number, section, key);
        } else if (std.mem.eql(u8, section, "clang")) {
            if (std.mem.eql(u8, key, "downgrade_all_warnings")) {
                config.clang_downgrade_all_warnings = parseBool(value_text) orelse {
                    std.log.err("{s}:{d}: downgrade_all_warnings must be true or false", .{ config_path, line_number });
                    return error.InvalidConfig;
                };
            } else if (std.mem.eql(u8, key, "downgrade_warnings")) {
                parseWarningGroups(allocator, value_text, &config.clang_downgrade_warnings) catch |err| {
                    std.log.err("{s}:{d}: downgrade_warnings must be an array of Clang warning group names", .{ config_path, line_number });
                    return err;
                };
            } else {
                return invalidKey(config_path, line_number, section, key);
            }
        } else if (std.mem.eql(u8, section, "migration")) {
            if (!std.mem.eql(u8, key, "legacy_prefixes"))
                return invalidKey(config_path, line_number, section, key);

            config.legacy_prefixes = parseBool(value_text) orelse {
                std.log.err("{s}:{d}: legacy_prefixes must be true or false", .{ config_path, line_number });
                return error.InvalidConfig;
            };
        } else if (std.mem.eql(u8, section, "variables")) {
            if (!std.mem.eql(u8, key, "case"))
                return invalidKey(config_path, line_number, section, key);

            const value = try parseString(allocator, value_text);
            config.variable_case = parseVariableCase(value) orelse {
                std.log.err("{s}:{d}: variable case must be camel, pascal, snake, or hungarian", .{ config_path, line_number });
                return error.InvalidConfig;
            };
        } else if (std.mem.eql(u8, section, "scope_alternatives") or
            std.mem.eql(u8, section, "scope_alternatives.const"))
        {
            const const_only = std.mem.eql(u8, section, "scope_alternatives.const");
            const alternatives = findScopeAlternatives(&config, key, const_only) orelse
                return invalidKey(config_path, line_number, section, key);

            parseVariableStyles(allocator, value_text, alternatives) catch |err| {
                std.log.err("{s}:{d}: scope alternatives must be an array containing upper_snake", .{ config_path, line_number });
                return err;
            };
        } else if (std.mem.eql(u8, section, "functions")) {
            const value = try parseString(allocator, value_text);
            const function_case = parseFunctionCase(value) orelse {
                std.log.err("{s}:{d}: function case must be camel, pascal, snake, upper_snake, or unchanged", .{ config_path, line_number });
                return error.InvalidConfig;
            };
            if (std.mem.eql(u8, key, "member")) {
                config.member_function_case = function_case;
            } else if (std.mem.eql(u8, key, "free")) {
                config.free_function_case = function_case;
            } else if (std.mem.eql(u8, key, "inline")) {
                config.inline_function_case = function_case;
            } else {
                return invalidKey(config_path, line_number, section, key);
            }
        } else if (std.mem.eql(u8, section, "types")) {
            const type_name = try parseKey(allocator, key);
            const prefix = try parseString(allocator, value_text);
            try config.mappings.append(allocator, .{ .type_name = type_name, .prefix = prefix });
        } else if (std.mem.eql(u8, section, "arrays")) {
            const type_name = try parseKey(allocator, key);
            const prefix = try parseString(allocator, value_text);
            try config.array_mappings.append(allocator, .{ .type_name = type_name, .prefix = prefix });
        } else if (std.mem.eql(u8, section, "pointer_types")) {
            const type_name = try parseKey(allocator, key);
            if (pointerTypeShape(type_name) == null) {
                std.log.err("{s}:{d}: pointer_types keys must end with one or more '*'", .{ config_path, line_number });
                return error.InvalidConfig;
            }
            const prefix = try parseString(allocator, value_text);
            try config.pointer_type_mappings.append(allocator, .{ .type_name = type_name, .prefix = prefix });
        } else if (std.mem.eql(u8, section, "pointers")) {
            const value = try parseString(allocator, value_text);
            if (std.mem.eql(u8, key, "marker")) {
                if (value.len == 0) return error.InvalidConfig;
                config.pointer_marker = value;
            } else {
                const type_name = try parseKey(allocator, key);
                try config.pointer_mappings.append(allocator, .{ .type_name = type_name, .prefix = value });
            }
        } else if (section.len == 0 and std.mem.eql(u8, key, "use_canonical_type")) {
            config.use_canonical_type = parseBool(value_text) orelse return error.InvalidConfig;
        } else {
            return invalidKey(config_path, line_number, section, key);
        }
    }

    return config;
}

fn setScopePrefix(config: *Config, key: []const u8, value: []const u8) bool {
    if (std.mem.eql(u8, key, "local")) {
        config.local_prefix = value;
    } else if (std.mem.eql(u8, key, "static_local")) {
        config.static_local_prefix = value;
    } else if (std.mem.eql(u8, key, "member")) {
        config.member_prefix = value;
    } else if (std.mem.eql(u8, key, "static_member")) {
        config.static_member_prefix = value;
    } else if (std.mem.eql(u8, key, "global")) {
        config.global_prefix = value;
    } else if (std.mem.eql(u8, key, "static_global")) {
        config.static_global_prefix = value;
    } else {
        return false;
    }

    return true;
}

fn setScanEnabled(config: *Config, key: []const u8, enabled: bool) bool {
    if (std.mem.eql(u8, key, "local")) {
        config.scan_local = enabled;
    } else if (std.mem.eql(u8, key, "static_local")) {
        config.scan_static_local = enabled;
    } else if (std.mem.eql(u8, key, "member")) {
        config.scan_member = enabled;
    } else if (std.mem.eql(u8, key, "static_member")) {
        config.scan_static_member = enabled;
    } else if (std.mem.eql(u8, key, "global")) {
        config.scan_global = enabled;
    } else if (std.mem.eql(u8, key, "static_global")) {
        config.scan_static_global = enabled;
    } else if (std.mem.eql(u8, key, "functions")) {
        config.scan_functions = enabled;
    } else {
        return false;
    }

    return true;
}

fn findScopeAlternatives(
    config: *Config,
    key: []const u8,
    const_only: bool,
) ?*std.ArrayList(VariableStyle) {
    if (std.mem.eql(u8, key, "local"))
        return if (const_only) &config.const_local_alternatives else &config.local_alternatives;
    if (std.mem.eql(u8, key, "static_local"))
        return if (const_only) &config.const_static_local_alternatives else &config.static_local_alternatives;
    if (std.mem.eql(u8, key, "member"))
        return if (const_only) &config.const_member_alternatives else &config.member_alternatives;
    if (std.mem.eql(u8, key, "static_member"))
        return if (const_only) &config.const_static_member_alternatives else &config.static_member_alternatives;
    if (std.mem.eql(u8, key, "global"))
        return if (const_only) &config.const_global_alternatives else &config.global_alternatives;
    if (std.mem.eql(u8, key, "static_global"))
        return if (const_only) &config.const_static_global_alternatives else &config.static_global_alternatives;

    return null;
}

fn parseKey(allocator: std.mem.Allocator, text: []const u8) ![]const u8 {
    const trimmed = std.mem.trim(u8, text, " \t");
    if (trimmed.len > 0 and trimmed[0] == '"') return parseString(allocator, trimmed);
    if (trimmed.len == 0) return error.InvalidConfig;

    for (trimmed) |ch| if (!(std.ascii.isAlphanumeric(ch) or ch == '_' or ch == '-'))
        return error.InvalidConfig;

    return allocator.dupe(u8, trimmed);
}

fn parseFunctionCase(value: []const u8) ?FunctionCase {
    if (std.mem.eql(u8, value, "camel")) return .lower_camel;
    if (std.mem.eql(u8, value, "pascal")) return .pascal;
    if (std.mem.eql(u8, value, "snake")) return .snake;
    if (std.mem.eql(u8, value, "upper_snake")) return .upper_snake;
    if (std.mem.eql(u8, value, "unchanged")) return .unchanged;

    return null;
}

fn parseVariableCase(value: []const u8) ?VariableCase {
    if (std.mem.eql(u8, value, "camel")) return .lower_camel;
    if (std.mem.eql(u8, value, "pascal")) return .pascal;
    if (std.mem.eql(u8, value, "snake")) return .snake;
    if (std.mem.eql(u8, value, "hungarian")) return .hungarian;

    return null;
}

fn parseBool(value: []const u8) ?bool {
    if (std.mem.eql(u8, value, "true")) return true;
    if (std.mem.eql(u8, value, "false")) return false;

    return null;
}

fn parseVariableStyles(
    allocator: std.mem.Allocator,
    text: []const u8,
    output: *std.ArrayList(VariableStyle),
) !void {
    var values = try parseStringArray(allocator, text);
    defer {
        for (values.items) |value| allocator.free(value);
        values.deinit(allocator);
    }

    for (values.items) |value| {
        const style: VariableStyle = if (std.mem.eql(u8, value, "upper_snake"))
            .upper_snake
        else
            return error.InvalidConfig;

        if (std.mem.indexOfScalar(VariableStyle, output.items, style) == null)
            try output.append(allocator, style);
    }
}

fn parseWarningGroups(
    allocator: std.mem.Allocator,
    text: []const u8,
    output: *std.ArrayList([]const u8),
) !void {
    var values = try parseStringArray(allocator, text);

    for (values.items) |value| {
        if (warningGroupName(value) == null) {
            for (values.items) |owned| allocator.free(owned);
            values.deinit(allocator);
            return error.InvalidConfig;
        }
    }

    for (values.items) |value| {
        const group = warningGroupName(value).?;

        var duplicate = false;
        for (output.items) |existing| {
            if (std.mem.eql(u8, warningGroupName(existing).?, group)) {
                duplicate = true;
                break;
            }
        }

        if (duplicate) {
            allocator.free(value);
        } else {
            try output.append(allocator, value);
        }
    }

    values.deinit(allocator);
}

fn parseStringArray(allocator: std.mem.Allocator, text: []const u8) !std.ArrayList([]const u8) {
    var values: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (values.items) |value| allocator.free(value);
        values.deinit(allocator);
    }

    const trimmed = std.mem.trim(u8, text, " \t");
    if (trimmed.len < 2 or trimmed[0] != '[' or trimmed[trimmed.len - 1] != ']')
        return error.InvalidConfig;

    var remaining = std.mem.trim(u8, trimmed[1 .. trimmed.len - 1], " \t");
    while (remaining.len > 0) {
        if (remaining[0] != '"') return error.InvalidConfig;

        var escaped = false;
        var end: ?usize = null;
        var i: usize = 1;
        while (i < remaining.len) : (i += 1) {
            if (escaped) {
                escaped = false;
            } else if (remaining[i] == '\\') {
                escaped = true;
            } else if (remaining[i] == '"') {
                end = i + 1;
                break;
            }
        }

        const string_end = end orelse return error.InvalidConfig;
        try values.append(allocator, try parseString(allocator, remaining[0..string_end]));

        remaining = std.mem.trim(u8, remaining[string_end..], " \t");
        if (remaining.len == 0) break;
        if (remaining[0] != ',') return error.InvalidConfig;

        remaining = std.mem.trim(u8, remaining[1..], " \t");
        if (remaining.len == 0) return error.InvalidConfig;
    }

    return values;
}

pub fn warningGroupName(value: []const u8) ?[]const u8 {
    const group = if (std.mem.startsWith(u8, value, "-W")) value[2..] else value;
    if (group.len == 0) return null;

    for (group) |ch| {
        if (!std.ascii.isAlphanumeric(ch) and ch != '-' and ch != '_' and ch != '+' and ch != '.')
            return null;
    }

    return group;
}

fn parseString(allocator: std.mem.Allocator, text: []const u8) ![]const u8 {
    const trimmed = std.mem.trim(u8, text, " \t");
    if (trimmed.len < 2 or trimmed[0] != '"' or trimmed[trimmed.len - 1] != '"')
        return error.InvalidConfig;

    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    var i: usize = 1;
    while (i + 1 < trimmed.len) : (i += 1) {
        if (trimmed[i] == '\\') {
            i += 1;
            if (i + 1 > trimmed.len) return error.InvalidConfig;
            try result.append(allocator, switch (trimmed[i]) {
                'n' => '\n',
                't' => '\t',
                'r' => '\r',
                '\\' => '\\',
                '"' => '"',
                else => return error.InvalidConfig,
            });
        } else {
            try result.append(allocator, trimmed[i]);
        }
    }

    return result.toOwnedSlice(allocator);
}

fn stripComment(line: []const u8) []const u8 {
    var quoted = false;
    var escaped = false;

    for (line, 0..) |ch, i| {
        if (escaped) {
            escaped = false;
            continue;
        }
        if (ch == '\\' and quoted) {
            escaped = true;
        } else if (ch == '"') {
            quoted = !quoted;
        } else if (ch == '#' and !quoted) {
            return line[0..i];
        }
    }

    return line;
}

fn invalidKey(path: []const u8, line: usize, section: []const u8, key: []const u8) error{InvalidConfig} {
    std.log.err("{s}:{d}: unknown key [{s}].{s}", .{ path, line, section, key });
    return error.InvalidConfig;
}

test "TOML type keys may be bare or quoted" {
    const allocator = std.testing.allocator;
    const bare = try parseKey(allocator, "int");
    defer allocator.free(bare);
    try std.testing.expectEqualStrings("int", bare);

    const quoted = try parseKey(allocator, "\"project::Request\"");
    defer allocator.free(quoted);
    try std.testing.expectEqualStrings("project::Request", quoted);
}

test "scope alternatives parse as a string array" {
    const allocator = std.testing.allocator;
    var styles: std.ArrayList(VariableStyle) = .empty;
    defer styles.deinit(allocator);

    try parseVariableStyles(allocator, "[\"upper_snake\"]", &styles);

    try std.testing.expectEqualSlices(VariableStyle, &.{.upper_snake}, styles.items);
}

test "scan switches are independently configurable" {
    var config = Config{};

    try std.testing.expect(setScanEnabled(&config, "local", false));
    try std.testing.expect(!config.scan_local);
    try std.testing.expect(config.scan_static_local);
    try std.testing.expect(!setScanEnabled(&config, "unknown", false));
}

test "Clang warning groups accept names copied from diagnostics" {
    const allocator = std.testing.allocator;
    var groups: std.ArrayList([]const u8) = .empty;
    defer {
        for (groups.items) |group| allocator.free(group);
        groups.deinit(allocator);
    }

    try parseWarningGroups(
        allocator,
        "[\"sign-conversion\", \"-Wconversion\", \"sign-conversion\"]",
        &groups,
    );

    try std.testing.expectEqual(@as(usize, 2), groups.items.len);
    try std.testing.expectEqualStrings("sign-conversion", warningGroupName(groups.items[0]).?);
    try std.testing.expectEqualStrings("conversion", warningGroupName(groups.items[1]).?);
}

test "built-in type mappings are neutral" {
    const allocator = std.testing.allocator;
    var config = try Config.initDefaults(allocator);
    defer config.deinit(allocator);

    try std.testing.expectEqualStrings("", config.typePrefix("int", 0).?);
    try std.testing.expectEqualStrings("", config.typePrefix("char", 1).?);
    try std.testing.expect(config.legacy_prefixes);
}

test "pointer and array mappings override ordinary type mappings" {
    const allocator = std.testing.allocator;
    var config = try Config.initDefaults(allocator);
    defer config.deinit(allocator);

    try config.mappings.append(allocator, .{ .type_name = "char", .prefix = "ch" });
    try config.array_mappings.append(allocator, .{ .type_name = "char", .prefix = "s" });
    try config.pointer_mappings.append(allocator, .{ .type_name = "char", .prefix = "ps" });
    try config.pointer_type_mappings.append(allocator, .{ .type_name = "char *", .prefix = "s" });
    try config.pointer_type_mappings.append(allocator, .{ .type_name = "char**", .prefix = "strings" });

    try std.testing.expectEqualStrings("ch", config.typePrefixForShape("const char", 0, 0).?);
    try std.testing.expectEqualStrings("s", config.typePrefixForShape("const char", 0, 1).?);
    try std.testing.expect(config.typePrefixForShape("int", 0, 1) == null);
    const single_pointer = config.typePrefixMatchForShape("const char", 1, 1).?;
    try std.testing.expectEqualStrings("s", single_pointer.prefix);
    try std.testing.expectEqual(@as(usize, 1), single_pointer.consumed_pointer_depth);

    const triple_pointer = config.typePrefixMatchForShape("char", 3, 0).?;
    try std.testing.expectEqualStrings("strings", triple_pointer.prefix);
    try std.testing.expectEqual(@as(usize, 2), triple_pointer.consumed_pointer_depth);
}

test "pointer type shapes require trailing pointer levels" {
    try std.testing.expect(pointerTypeShape("char") == null);
    try std.testing.expectEqual(@as(usize, 1), pointerTypeShape("const char *").?.pointer_depth);
    try std.testing.expectEqualStrings("const char", pointerTypeShape("const char *").?.base_type);
    try std.testing.expectEqual(@as(usize, 2), pointerTypeShape("char * *").?.pointer_depth);
}

test "migration section can disable legacy prefixes" {
    const io = std.testing.io;
    const allocator = std.testing.allocator;
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.writeFile(io, .{
        .sub_path = "ident-mod.toml",
        .data = "[migration]\nlegacy_prefixes = false\n",
    });
    const path = try temporary.dir.realPathFileAlloc(io, "ident-mod.toml", allocator);
    defer allocator.free(path);

    var config = try load(io, allocator, path);
    defer config.deinit(allocator);
    try std.testing.expect(!config.legacy_prefixes);
}

test "type matching shares lookup semantics" {
    try std.testing.expect(typeNameMatches("const std::vector<int>", "std::vector"));
    try std.testing.expect(typeNameMatches("volatile int", "int"));
    try std.testing.expect(!typeNameMatches("std::string", "int"));
}
