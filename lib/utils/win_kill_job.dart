import 'win_kill_job_stub.dart' if (dart.library.io) 'win_kill_job_io.dart' as impl;

/// Windows Job Object：关闭最后一个 handle 时结束 Job 内进程。
///
/// 非 Windows 平台为 no-op；实现按条件导入，避免无关平台强耦合细节。
class WinKillOnCloseJob {
  WinKillOnCloseJob._();

  static bool get boundCurrentProcess => impl.boundCurrentProcess;

  static bool bindCurrentProcess() => impl.bindCurrentProcess();

  static Future<void> launchBreakaway(String executable) => impl.launchBreakaway(executable);

  static bool assignPid(int pid) => impl.assignPid(pid);
}
