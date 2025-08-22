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
history:    std.ArrayList(ai.Message),
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
    for (config.models, 0..config.models.len) |next, i| {
        const model_name = try std.fmt.allocPrint(alloc, "model {d}", .{i});
        try models.append(try Model.init(alloc, model_name, next.url, next.model, next.temperature, config.system));
    }
    return .{
        .alloc = alloc,
        .history = std.ArrayList(ai.Message).init(alloc),
        .models = models,
        .moderator = try Model.init(alloc, "moderator", config.moderator.url, config.moderator.model, config.moderator.temperature, config.moderate),
        .picker = try Model.init(alloc, "picker", config.moderator.url, config.moderator.model, config.moderator.temperature, config.picker_system),
        .regen = try Model.init(alloc, "regen", config.moderator.url, config.moderator.model, config.moderator.temperature, config.regen_system),
    };
}

pub fn deinit(self: *Self) void {
    self.models.deinit();
}

pub fn processRequest(self: *Self, request: String) !String {
    var last_message: ai.Message = .{.role = "user", .content = request};
    var pick: ai.Message = undefined;
    var deliberating = true;
    while (deliberating) {
        try self.history.append(last_message);
        for (self.models.items) |*model| {
            last_message = try model.chat(last_message);
            try self.history.append(last_message);
        }
        const agree_check = try self.moderator.moderate(self.history);
        defer self.alloc.free(agree_check.content);
        deliberating = std.mem.eql(u8, strip(agree_check.content), "Agree") == false;
        std.log.debug("agree check: {s}", .{agree_check.content});
        std.log.debug("still deliberating: {any}", .{deliberating});
        if (deliberating) {
            last_message = try self.regen.moderate(self.history);
            try self.history.append(last_message);
        }
        else {
            pick = try self.picker.moderate(self.history);
        }
    }

    return pick.content;
}
