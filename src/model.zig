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

alloc:      Allocator,
model:      String,
name:       String,
openai:     ai.Client,
system:     String,
temp:       f32,

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

pub fn init(alloc: Allocator, name: String, url: String, model: String, temp: f32, system: String) !Self {
    return .{
        .alloc = alloc,
        .model = model,
        .name = name,
        .openai = try ai.Client.init(alloc, url, "ollama", null),
        .system = system,
        .temp = temp,
    };
}

pub fn deinit(self: *Self) void {
    self.openai.deinit();
}

pub fn chat(self: *Self, history: std.ArrayList(ai.Message)) !ai.Message {
    var messages = std.ArrayList(ai.Message).init(self.alloc);
    defer messages.deinit();

    try messages.append(.{.role = "system", .content = self.system});
    //try messages.appendSlice(history.items);
    for (history.items) |next| {
        if (std.mem.eql(u8, next.role, self.name)) {
            try messages.append(.{.role = "assistant", .content = next.content});
        }
        else {
            try messages.append(.{.role = "user", .content = next.content});
        }
    }
    const payload: ai.ChatPayload = .{
        .model = self.model,
        .messages = messages.items,
        .max_tokens = 10000,
        .temperature = self.temp,
    };

    const response = try self.openai.chat(payload, false);
    defer response.deinit();

    return .{.role = self.name, .content = try self.alloc.dupe(u8, strip(response.value.choices[response.value.choices.len-1].message.content))};
}
