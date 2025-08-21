const ai = @import("zig_ai");
const Model = @import("model.zig");
const std = @import("std");


const Allocator = std.mem.Allocator;
const Self = @This();
const String = []const u8;

pub const Config = struct {
    determine_agreement:    String,
    determine_disagreement:  String,
    name:       String,
    models:     []Model.Config,
    moderate:   String,
    moderator:  Model.Config,
    picker_system:  String,
    regen_system:   String,
    system:     String,
};

alloc:      Allocator,
history:    std.ArrayList(String),
models:     std.ArrayList(Model),
moderator:  Model,
picker:     Model,
regen:      Model,

fn strip(str: []const u8) []const u8 {
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

pub fn init(alloc: Allocator, config: Config) !Self {
    var models = std.ArrayList(Model).init(alloc);
    for (config.models) |next| {
        try models.append(try Model.init(alloc, next.url, next.model, next.temperature, config.system));
    }
    return .{
        .alloc = alloc,
        .history = std.ArrayList(String).init(alloc),
        .models = models,
        .moderator = try Model.init(alloc, config.moderator.url, config.moderator.model, config.moderator.temperature, config.moderate),
        .picker = try Model.init(alloc, config.moderator.url, config.moderator.model, config.moderator.temperature, config.picker_system),
        .regen = try Model.init(alloc, config.moderator.url, config.moderator.model, config.moderator.temperature, config.regen_system),
    };
}

pub fn deinit(self: *Self) void {
    self.models.deinit();
}

pub fn processRequest(self: *Self, request: String) !String {
    var responses: [4]String = undefined;

    var prompt = request;
    var pick: []const u8 = undefined;
    var deliberating = true;
    while (deliberating) {
        defer {
            for (responses) |response| {self.alloc.free(response);}
        }

        for (self.models.items, 0..self.models.items.len) |*model, i| {
            responses[i] = try model.chat(prompt);
            try self.history.append(responses[i]);
        }
        const agree_check = try self.moderator.moderate(&responses);
        defer self.alloc.free(agree_check);
        deliberating = std.mem.eql(u8, strip(agree_check), "Agree") == false;
        std.log.debug("agree check: {s}", .{agree_check});
        std.log.debug("still deliberating: {any}", .{deliberating});
        if (deliberating) {
            prompt = try self.regen.moderate(&responses);
        }
        else {
            pick = try self.picker.moderate(&responses);
        }
    }

    return pick;
}
