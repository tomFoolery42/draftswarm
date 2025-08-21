const Hivemind = @import("hivemind.zig");

const std = @import("std");


const Allocator = std.mem.Allocator;
const String = []const u8;

fn readConfig(alloc: Allocator, path: []const u8) !std.json.Parsed(Hivemind.Config) {
  const data = try std.fs.cwd().readFileAlloc(alloc, path, 1024 * 5);
  defer alloc.free(data);
  return std.json.parseFromSlice(Hivemind.Config, alloc, data, .{.allocate = .alloc_always});
}

fn debug(alloc: Allocator, stephen: *Hivemind) !void {
    const running = true;
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    var buffer: [300]u8 = undefined;
    while (running) {
        try stdout.print(">", .{});
        const request = try stdin.readUntilDelimiter(&buffer, '\n');

        const response = try stephen.processRequest(request);
        defer alloc.free(response);
        try stdout.print("Response: {s}\n", .{response});
    }
}

fn linupPick(alloc: Allocator, stephen: *Hivemind) !void {
    const positions: [9]String = .{"Quarterback", "RunningBack", "Running Back", "Wide Receiver", "Wide Receiver", "Tight End", "Kicker", "Defense/special", "Flex"};
    var picks: [9]String = undefined;
    defer {
        for (picks) |next| {alloc.free(next);}
    }

    for (positions, 0..positions.len) |next, i| {
        const request = try std.fmt.allocPrint(alloc, "Please pick a First string {s}, second string {s} and a rookie {s}.", .{next, next, next});
        defer alloc.free(request);
        picks[i] = try stephen.processRequest(request);

        std.log.info("{s} pick is {s}", .{positions[i], picks[i]});
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const alloc = gpa.allocator();

    const stephen_config = try readConfig(alloc, "config.json");
    defer stephen_config.deinit();
    var stephen = try Hivemind.init(alloc, stephen_config.value);
    defer stephen.deinit();

    try linupPick(alloc, &stephen);
}
