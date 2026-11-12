"""离线用精确匹配的本地 PDB 解析 VM Service 采样中的 Flutter 引擎地址。"""

import argparse
import collections
import ctypes
from ctypes import wintypes
import hashlib
import json
from pathlib import Path
import re
import sys


_REPO = Path(__file__).resolve().parents[3]
_DEFAULT_TRACE = _REPO / ".dart_tool/benchmarks/profile-pipeline-20261112/cpu.json"
_DEFAULT_ENGINE = Path("D:/app/fvm/default/bin/cache/artifacts/engine/windows-x64-profile")
_DEFAULT_APP = _REPO / "example/build/windows/x64/runner/Profile/flutter_windows.dll"
_ADDRESS = re.compile(r"flutter_windows\.dll\+0x([0-9a-f]+)", re.IGNORECASE)
_FAKE_BASE = 0x100000000
_DWORD64 = ctypes.c_ulonglong


class _SymbolInfo(ctypes.Structure):
    _fields_ = [
        ("SizeOfStruct", wintypes.DWORD),
        ("TypeIndex", wintypes.DWORD),
        ("Reserved", _DWORD64 * 2),
        ("Index", wintypes.DWORD),
        ("Size", wintypes.DWORD),
        ("ModBase", _DWORD64),
        ("Flags", wintypes.DWORD),
        ("Value", _DWORD64),
        ("Address", _DWORD64),
        ("Register", wintypes.DWORD),
        ("Scope", wintypes.DWORD),
        ("Tag", wintypes.DWORD),
        ("NameLen", wintypes.DWORD),
        ("MaxNameLen", wintypes.DWORD),
        ("Name", ctypes.c_char * 1),
    ]


class _Guid(ctypes.Structure):
    _fields_ = [
        ("Data1", wintypes.DWORD),
        ("Data2", wintypes.WORD),
        ("Data3", wintypes.WORD),
        ("Data4", ctypes.c_ubyte * 8),
    ]


class _ModuleInfo(ctypes.Structure):
    _fields_ = [
        ("SizeOfStruct", wintypes.DWORD),
        ("BaseOfImage", _DWORD64),
        ("ImageSize", wintypes.DWORD),
        ("TimeDateStamp", wintypes.DWORD),
        ("CheckSum", wintypes.DWORD),
        ("NumSyms", wintypes.DWORD),
        ("SymType", wintypes.DWORD),
        ("ModuleName", ctypes.c_char * 32),
        ("ImageName", ctypes.c_char * 256),
        ("LoadedImageName", ctypes.c_char * 256),
        ("LoadedPdbName", ctypes.c_char * 256),
        ("CVSig", wintypes.DWORD),
        ("CVData", ctypes.c_char * 780),
        ("PdbSig", wintypes.DWORD),
        ("PdbSig70", _Guid),
        ("PdbAge", wintypes.DWORD),
        ("PdbUnmatched", wintypes.BOOL),
        ("DbgUnmatched", wintypes.BOOL),
        ("LineNumbers", wintypes.BOOL),
        ("GlobalSymbols", wintypes.BOOL),
        ("TypeInfo", wintypes.BOOL),
        ("SourceIndexed", wintypes.BOOL),
        ("Publics", wintypes.BOOL),
        ("MachineType", wintypes.DWORD),
        ("Reserved", wintypes.DWORD),
    ]


def _sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _sampled_offsets(trace):
    functions = trace["functions"]
    offsets = {}
    for index, function in enumerate(functions):
        name = function.get("function", {}).get("name", "")
        match = _ADDRESS.search(name)
        if function.get("kind") == "Native" and match:
            offsets[index] = int(match.group(1), 16)

    inclusive = collections.Counter()
    leaves = collections.Counter()
    used = set()
    for sample in trace["samples"]:
        stack = sample.get("stack", [])
        present = {offsets[index] for index in stack if index in offsets}
        inclusive.update(present)
        used.update(index for index in stack if index in offsets)
        if stack and stack[0] in offsets:
            leaves[offsets[stack[0]]] += 1
    groups = collections.defaultdict(list)
    for index in sorted(used):
        groups[offsets[index]].append(index)
    ordered = sorted(groups, key=lambda offset: (-inclusive[offset], -leaves[offset], offset))
    return ordered, groups, inclusive, leaves


class _LocalSymbols:
    def __init__(self, engine_dir):
        self.engine_dir = engine_dir.resolve()
        self.dll = self.engine_dir / "flutter_windows.dll"
        self.dbg = ctypes.WinDLL("dbghelp", use_last_error=True)
        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel.GetCurrentProcess.argtypes = []
        kernel.GetCurrentProcess.restype = wintypes.HANDLE
        self.handle = kernel.GetCurrentProcess()
        self.base = 0
        self.initialized = False
        self.dbg.SymSetOptions.argtypes = [wintypes.DWORD]
        self.dbg.SymSetOptions.restype = wintypes.DWORD
        self.dbg.SymInitializeW.argtypes = [wintypes.HANDLE, wintypes.LPCWSTR, wintypes.BOOL]
        self.dbg.SymInitializeW.restype = wintypes.BOOL
        self.dbg.SymLoadModuleExW.argtypes = [
            wintypes.HANDLE, wintypes.HANDLE, wintypes.LPCWSTR, wintypes.LPCWSTR,
            _DWORD64, wintypes.DWORD, ctypes.c_void_p, wintypes.DWORD,
        ]
        self.dbg.SymLoadModuleExW.restype = _DWORD64
        self.dbg.SymFromAddr.argtypes = [
            wintypes.HANDLE, _DWORD64, ctypes.POINTER(_DWORD64), ctypes.POINTER(_SymbolInfo),
        ]
        self.dbg.SymFromAddr.restype = wintypes.BOOL
        self.dbg.SymGetModuleInfo64.argtypes = [wintypes.HANDLE, _DWORD64, ctypes.POINTER(_ModuleInfo)]
        self.dbg.SymGetModuleInfo64.restype = wintypes.BOOL
        self.dbg.SymUnloadModule64.argtypes = [wintypes.HANDLE, _DWORD64]
        self.dbg.SymUnloadModule64.restype = wintypes.BOOL
        self.dbg.SymCleanup.argtypes = [wintypes.HANDLE]
        self.dbg.SymCleanup.restype = wintypes.BOOL

    def __enter__(self):
        # 仅查指定本地目录；拒绝错配 PDB、环境符号路径、网络符号库自动探测和弹窗。
        self.options = self.dbg.SymSetOptions(
            0x00000002 | 0x00000400 | 0x00000200 | 0x00080000 |
            0x00001000 | 0x00000100 | 0x02000000
        )
        if not self.dbg.SymInitializeW(self.handle, str(self.engine_dir), False):
            raise ctypes.WinError(ctypes.get_last_error())
        self.initialized = True
        # 这里只装入符号表，使用虚构基址；没有 LoadLibrary、附加或读取应用进程。
        self.base = self.dbg.SymLoadModuleExW(
            self.handle, None, str(self.dll), "flutter_windows", _FAKE_BASE, 0, None, 0,
        )
        if not self.base:
            error = ctypes.get_last_error()
            self.close()
            raise ctypes.WinError(error)
        info = _ModuleInfo()
        info.SizeOfStruct = ctypes.sizeof(_ModuleInfo)
        if not self.dbg.SymGetModuleInfo64(self.handle, self.base, ctypes.byref(info)):
            error = ctypes.get_last_error()
            self.close()
            raise ctypes.WinError(error)
        loaded_pdb = Path(info.LoadedPdbName.decode("mbcs"))
        if info.PdbUnmatched or not loaded_pdb.is_file() or loaded_pdb.parent.resolve() != self.engine_dir:
            self.close()
            raise RuntimeError("拒绝使用错配或指定目录之外的 PDB: {}".format(loaded_pdb))
        self.module = {
            "loaded_pdb": str(loaded_pdb),
            "pdb_unmatched": bool(info.PdbUnmatched),
            "symbol_type": info.SymType,
            "pdb_age": info.PdbAge,
            "image_size": info.ImageSize,
            "base": hex(self.base),
            "options": hex(self.options),
        }
        return self

    def resolve(self, offset):
        capacity = 8192
        buffer = ctypes.create_string_buffer(ctypes.sizeof(_SymbolInfo) + capacity - 1)
        info = ctypes.cast(buffer, ctypes.POINTER(_SymbolInfo))
        info.contents.SizeOfStruct = ctypes.sizeof(_SymbolInfo)
        info.contents.MaxNameLen = capacity
        displacement = _DWORD64()
        if not self.dbg.SymFromAddr(self.handle, self.base + offset, ctypes.byref(displacement), info):
            error = ctypes.get_last_error()
            return {"resolved": False, "error": error, "error_message": ctypes.FormatError(error)}
        symbol = info.contents
        name = ctypes.string_at(ctypes.addressof(buffer) + _SymbolInfo.Name.offset, symbol.NameLen)
        return {
            "resolved": True,
            "symbol": name.decode("utf-8", errors="replace"),
            "displacement": displacement.value,
            "symbol_offset": hex(symbol.Address - self.base),
            "symbol_size": symbol.Size,
            "symbol_tag": symbol.Tag,
            "symbol_flags": hex(symbol.Flags),
        }

    def close(self):
        if self.base:
            self.dbg.SymUnloadModule64(self.handle, self.base)
            self.base = 0
        if self.initialized:
            self.dbg.SymCleanup(self.handle)
            self.initialized = False

    def __exit__(self, exc_type, exc, traceback):
        self.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--trace", type=Path, default=_DEFAULT_TRACE)
    parser.add_argument("--sdk-engine-dir", type=Path, default=_DEFAULT_ENGINE)
    parser.add_argument("--app-dll", type=Path, default=_DEFAULT_APP)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--probe", action="store_true", help="只解前十个地址并打印，不写文件")
    parser.add_argument("--limit", type=int, default=500, help="最多解析的唯一采样地址数量")
    args = parser.parse_args()
    if sys.platform != "win32" or ctypes.sizeof(ctypes.c_void_p) != 8:
        raise RuntimeError("仅支持 Windows x64 Python。")
    if not 1 <= args.limit <= 1000:
        raise ValueError("地址数量必须在 1 到 1000 之间。")
    dll = args.sdk_engine_dir / "flutter_windows.dll"
    sdk_hash = _sha256(dll)
    app_hash = _sha256(args.app_dll)
    if sdk_hash != app_hash:
        raise RuntimeError("运行目录 DLL 与 SDK DLL SHA256 不同，拒绝用该 PDB 解析。")
    trace_doc = json.loads(args.trace.read_text(encoding="utf-8"))
    trace = trace_doc.get("result", trace_doc)
    ordered, groups, inclusive, leaves = _sampled_offsets(trace)
    if len(ordered) > args.limit:
        raise RuntimeError("采样地址 {} 个超过 --limit {}，请显式指定合理上限。".format(len(ordered), args.limit))
    print(json.dumps({"dll_sha256_match": True, "sha256": sdk_hash, "sampled_addresses": len(ordered)}))
    with _LocalSymbols(args.sdk_engine_dir) as symbols:
        print(json.dumps({"module": symbols.module}, ensure_ascii=False))
        mapping = {}
        for offset in ordered[:10] if args.probe else ordered:
            item = {
                "offset": hex(offset),
                "function_indices": groups[offset],
                "inclusive_sample_count": inclusive[offset],
                "leaf_sample_count": leaves[offset],
            }
            item.update(symbols.resolve(offset))
            mapping[hex(offset)] = item
            if args.probe:
                print(json.dumps(item, ensure_ascii=False))
        if args.probe:
            return
        document = {
            "trace": str(args.trace.resolve()),
            "trace_sample_count": len(trace["samples"]),
            "sample_period_us": trace.get("samplePeriod"),
            "sdk_dll": str(dll.resolve()),
            "app_dll": str(args.app_dll.resolve()),
            "dll_sha256": sdk_hash,
            "dll_sha256_match": True,
            "module": symbols.module,
            "address_count": len(mapping),
            "resolved_count": sum(item["resolved"] for item in mapping.values()),
            "symbols": mapping,
            "function_offsets": {str(index): hex(offset) for offset, indices in groups.items() for index in indices},
            "limitations": [
                "仅解析离线 CPU 采样中出现的地址，不代表完整原生调用栈。",
                "inclusive_sample_count 按每条样本去重，不能跨符号相加推算总时间。",
                "SHA256 验证当前 DLL 文件相同；无法证明采样后文件从未被替换。",
            ],
        }
    output = args.output or args.trace.with_name("native-symbols.json")
    if output.exists():
        raise FileExistsError("拒绝覆盖已有分析结果: {}".format(output))
    output.write_text(json.dumps(document, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"output": str(output.resolve()), "resolved": document["resolved_count"], "total": len(mapping)}))


if __name__ == "__main__":
    main()
