const std = @import("std");

const WasmEngine = opaque {};
const WasmByteVec = extern struct {
    size: usize,
    data: [*]u8,
};
const WasmFuncType = opaque {};

const WasmTimeStore = opaque {};
const WasmTimeContext = opaque {};
const WasmTimeModule = opaque {};
const WasmTimeError = opaque {};
const WasmTimeVal = extern struct {
    kind: Kind,
    of: Union,

    pub const Kind = enum(c_int) {
        i32 = 0,
        i64 = 1,
        f32 = 2,
        f64 = 3,
        v128 = 4,
        funcref = 5,
        externref = 6,
        anyref = 7,
    };

    pub const Union = union {
        i32: i32,
        i64: i64,
        f32: f32,
        f64: f64,
        anyref: WasmTimeAnyRef,
        externref: WasmTimeExternRef,
        funcref: WasmTimeFunc,
        v128: [16]c_int,
    };
};
const WasmTimeCaller = opaque {};
const WasmTimeFunc = opaque {};
const WasmTimeFuncCallback = *const fn (
    env: *anyopaque,
    caller: *WasmTimeCaller,
    args: [*]const WasmTimeVal,
    nargs: usize,
    results: [*]WasmTimeVal,
    nresults: usize,
) *WasmTrap;
const WasmTimeAnyRef = opaque {}; // TODO: Not opaque
const WasmTimeExternRef = opaque {}; // TODO: Not opaque
const WasmTrap = opaque {}; // TODO: Not opaque

extern "wasmtime" fn wasm_engine_new() ?*WasmEngine;
extern "wasmtime" fn wasmtime_store_new() ?*WasmTimeStore;
extern "wasmtime" fn wasmtime_store_context(*WasmTimeStore) *WasmTimeContext;
extern "wasmtime" fn wasm_byte_vec_new_uninitialized(*WasmByteVec, usize) void;
extern "wasmtime" fn wasm_byte_vec_delete(*WasmByteVec) void;
extern "wasmtime" fn wasmtime_wat2wasm([*]u8, usize, *WasmByteVec) ?*WasmTimeError;
extern "wasmtime" fn wasmtime_module_new(*WasmEngine, [*]u8, usize, **WasmTimeModule) ?*WasmTimeError;
extern "wasmtime" fn wasm_functype_new_0_0() *WasmFuncType;
extern "wasmtime" fn wasmtime_func_new() *WasmFuncType;
