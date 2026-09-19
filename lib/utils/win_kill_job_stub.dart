import 'dart:io';

bool get boundCurrentProcess => false;

bool bindCurrentProcess() => false;

Future<void> launchBreakaway(String executable) async {
  await Process.start(executable, const [], mode: ProcessStartMode.detached);
}

bool assignPid(int pid) => false;
