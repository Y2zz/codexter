import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

bool get boundCurrentProcess => _boundCurrent;

bool bindCurrentProcess() {
  if (!Platform.isWindows) return false;
  final job = _ensure();
  if (job == null) return false;
  final current = _k32.lookupFunction<IntPtr Function(), int Function()>('GetCurrentProcess');
  _boundCurrent = job._assignHandle(current());
  return _boundCurrent;
}

Future<void> launchBreakaway(String executable) async {
  if (!Platform.isWindows || !_boundCurrent) {
    await Process.start(executable, const [], mode: ProcessStartMode.detached);
    return;
  }

  final job = _ensure();
  if (job == null) {
    throw ProcessException(executable, const [], 'Windows Job 初始化失败');
  }

  using((arena) {
    final startupInfo = arena<STARTUPINFO>()..ref.cb = sizeOf<STARTUPINFO>();
    final processInfo = arena<PROCESS_INFORMATION>();
    final isInJob = arena<Int32>();
    final result = CreateProcess(
      arena.pcwstr(executable),
      arena.pwstr('"$executable"'),
      null,
      null,
      false,
      CREATE_BREAKAWAY_FROM_JOB,
      null,
      null,
      startupInfo,
      processInfo,
    );
    if (!result.value) {
      throw ProcessException(executable, const [], '无法启动更新安装器', result.error);
    }

    try {
      final checked = IsProcessInJob(
        processInfo.ref.hProcess,
        HANDLE(Pointer.fromAddress(job._job)),
        isInJob,
      );
      if (!checked.value || isInJob.value != 0) {
        TerminateProcess(processInfo.ref.hProcess, 1);
        throw ProcessException(
          executable,
          const [],
          '更新安装器未能脱离 Codexter 进程组',
          checked.value ? 0 : checked.error,
        );
      }
    } finally {
      CloseHandle(processInfo.ref.hThread);
      CloseHandle(processInfo.ref.hProcess);
    }
  });
}

bool assignPid(int pid) {
  if (!Platform.isWindows || pid <= 0) return false;
  final job = _ensure();
  if (job == null) return false;

  final openProcess = _k32
      .lookupFunction<IntPtr Function(Uint32, Int32, Uint32), int Function(int, int, int)>(
        'OpenProcess',
      );
  final handle = openProcess(_processTerminate | _processSetQuota, 0, pid);
  if (handle == 0) return false;
  try {
    return job._assignHandle(handle);
  } finally {
    _closeHandle(handle);
  }
}

const _jobObjectExtendedLimitInformation = 9;
const _jobObjectLimitBreakawayOk = 0x0800;
const _jobObjectLimitKillOnClose = 0x2000;
const _processTerminate = 0x0001;
const _processSetQuota = 0x0100;
const _extendedLimitInfoSize = 144;

DynamicLibrary? _kernel32;
_WinKillOnCloseJob? _instance;
bool _boundCurrent = false;

DynamicLibrary get _k32 {
  return _kernel32 ??= DynamicLibrary.open('kernel32.dll');
}

_WinKillOnCloseJob? _ensure() {
  if (!Platform.isWindows) return null;
  if (_instance != null) return _instance;

  final createJob = _k32.lookupFunction<IntPtr Function(IntPtr, IntPtr), int Function(int, int)>(
    'CreateJobObjectW',
  );
  final job = createJob(0, 0);
  if (job == 0) return null;

  final info = calloc<Uint8>(_extendedLimitInfoSize);
  try {
    (info.cast<Uint32>() + 4).value = _jobObjectLimitKillOnClose | _jobObjectLimitBreakawayOk;
    final setInfo = _k32
        .lookupFunction<
          Int32 Function(IntPtr, Int32, Pointer<Void>, Uint32),
          int Function(int, int, Pointer<Void>, int)
        >('SetInformationJobObject');
    final ok = setInfo(
      job,
      _jobObjectExtendedLimitInformation,
      info.cast(),
      _extendedLimitInfoSize,
    );
    if (ok == 0) {
      _closeHandle(job);
      return null;
    }
  } finally {
    calloc.free(info);
  }

  _instance = _WinKillOnCloseJob(job);
  return _instance;
}

void _closeHandle(int handle) {
  final close = _k32.lookupFunction<Int32 Function(IntPtr), int Function(int)>('CloseHandle');
  close(handle);
}

class _WinKillOnCloseJob {
  _WinKillOnCloseJob(this._job);

  final int _job;

  bool _assignHandle(int processHandle) {
    final assign = _k32.lookupFunction<Int32 Function(IntPtr, IntPtr), int Function(int, int)>(
      'AssignProcessToJobObject',
    );
    return assign(_job, processHandle) != 0;
  }
}
