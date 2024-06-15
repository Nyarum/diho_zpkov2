// zig fmt: off
const std = @import("std");
const builtin = @import("builtin");
const string = []const u8;

pub const cache = ".zigmod/deps";

pub fn addAllTo(exe: *std.Build.Step.Compile) void {
    checkMinZig(builtin.zig_version, exe);
    @setEvalBranchQuota(1_000_000);
    for (packages) |pkg| {
        const module = pkg.module(exe);
        exe.root_module.addImport(pkg.import.?[0], module);
    }
}

var link_lib_c = false;
pub const Package = struct {
    directory: string,
    import: ?struct { string, std.Build.LazyPath } = null,
    dependencies: []const *Package,
    c_include_dirs: []const string = &.{},
    c_source_files: []const string = &.{},
    c_source_flags: []const string = &.{},
    system_libs: []const string = &.{},
    frameworks: []const string = &.{},
    module_memo: ?*std.Build.Module = null,

    pub fn module(self: *Package, exe: *std.Build.Step.Compile) *std.Build.Module {
        if (self.module_memo) |cached| {
            return cached;
        }
        const b = exe.step.owner;
        const result = b.createModule(.{});
        const dummy_library = b.addStaticLibrary(.{
            .name = "dummy",
            .target = exe.root_module.resolved_target orelse b.host,
            .optimize = exe.root_module.optimize.?,
        });
        if (self.import) |capture| {
            result.root_source_file = capture[1];
        }
        for (self.dependencies) |item| {
            const module_dep = item.module(exe);
            if (module_dep.root_source_file != null) {
                result.addImport(item.import.?[0], module_dep);
            }
            for (module_dep.include_dirs.items) |jtem| {
                switch (jtem) {
                    .path => result.addIncludePath(jtem.path),
                    .path_system, .path_after, .framework_path, .framework_path_system, .other_step, .config_header_step => {},
                }
            }
        }
        for (self.c_include_dirs) |item| {
            result.addIncludePath(b.path(b.fmt("{s}/{s}", .{ self.directory, item })));
            dummy_library.addIncludePath(b.path(b.fmt("{s}/{s}", .{ self.directory, item })));
            link_lib_c = true;
        }
        for (self.c_source_files) |item| {
            dummy_library.addCSourceFile(.{ .file = b.path(b.fmt("{s}/{s}", .{ self.directory, item })), .flags = self.c_source_flags });
        }
        for (self.system_libs) |item| {
            dummy_library.linkSystemLibrary(item);
        }
        for (self.frameworks) |item| {
            dummy_library.linkFramework(item);
        }
        if (self.c_source_files.len > 0 or self.system_libs.len > 0 or self.frameworks.len > 0) {
            dummy_library.linkLibC();
            exe.root_module.linkLibrary(dummy_library);
            link_lib_c = true;
        }
        if (link_lib_c) {
            result.link_libc = true;
        }
        self.module_memo = result;
        return result;
    }
};

fn checkMinZig(current: std.SemanticVersion, exe: *std.Build.Step.Compile) void {
    const min = std.SemanticVersion.parse("null") catch return;
    if (current.order(min).compare(.lt)) @panic(exe.step.owner.fmt("Your Zig version v{} does not meet the minimum build requirement of v{}", .{current, min}));
}

pub const dirs = struct {
    pub const _root = "";
    pub const _oqqy5j0erww7 = "/Users/nyarum/diho_zpkov2";
};

pub const package_data = struct {
    pub var _root = Package{
        .directory = dirs._root,
        .dependencies = &.{ &_oqqy5j0erww7 },
    };
    pub var _oqqy5j0erww7 = Package{
        .directory = dirs._oqqy5j0erww7,
        .dependencies = &.{ },
    };
};

pub const packages = &[_]*Package{
};

pub const pkgs = struct {
};

pub const imports = struct {
};
