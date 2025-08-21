const ai = @import("zig_ai");
const std = @import("std");


const Allocator = std.mem.Allocator;
const Self = @This();
const String = []const u8;

pub const Config = struct {
    model:          String,
    url:            String,
    temperature:    f32,
};

alloc: Allocator,
temp: f32,
model: String,
openai: ai.Client,
system: String,

fn strip(str: String) String {
    var start: u16 = 0;
    for (str) |c| {
        if (c == ' ' or c == '\n') {
            start += 1;
        }
        else {
            break;
        }
    }

    var stop: usize = str.len-1;
    while (stop > 0) {
        if (str[stop] == ' ' or str[stop] == '\n') {
            stop -= 1;
        }
        else {
            break;
        }
    }

    return str[start..stop+1];
}

pub fn init(alloc: Allocator, url: String, model: String, temp: f32, system: String) !Self {
    return .{
        .alloc = alloc,
        .temp = temp,
        .model = model,
        .openai = try ai.Client.init(alloc, url, "ollama", null),
        .system = system,
    };
}

pub fn deinit(self: *Self) void {
    self.openai.deinit();
}

pub fn chat(self: *Self, request: String) !String {
    std.log.debug("request: {s}", .{request});
    var messages = std.ArrayList(ai.Message).init(self.alloc);
    defer messages.deinit();

    try messages.append(.{.role = "system", .content = self.system});
    try messages.append(.{.role = "user", .content = request});

    const payload: ai.ChatPayload = .{
        .model = self.model,
        .messages = messages.items,
        .max_tokens = 10000,
        .temperature = self.temp,
    };

    const response = try self.openai.chat(payload, false);
    defer response.deinit();

    return self.alloc.dupe(u8, strip(response.value.choices[0].message.content));
}

pub fn moderate(self: *Self, requests: []String) !String {
    var messages = std.ArrayList(ai.Message).init(self.alloc);
    defer messages.deinit();

    try messages.append(.{.role = "system", .content = self.system});
    for (requests) |request| {
        try messages.append(.{.role = "user", .content = request});
    }

    const payload: ai.ChatPayload = .{
        .model = self.model,
        .messages = messages.items,
        .max_tokens = 10000,
        .temperature = self.temp,
    };

    const response = try self.openai.chat(payload, false);
    defer response.deinit();

    return self.alloc.dupe(u8, strip(response.value.choices[response.value.choices.len-1].message.content));
}
