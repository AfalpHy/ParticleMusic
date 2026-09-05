import 'package:flutter/services.dart';

SystemUiMode? _appliedUiMode;

// 系统 UI 模式只在目标变化时应用，不能放在 build 里每次重设：全面屏手势
// 上滑时系统临时显示系统栏 → insets 变化触发重建 → 立刻又把栏藏回去，
// 返回桌面的手势被打断（平板宽屏沉浸模式下上滑卡住回不了桌面）。
void applySystemUiMode({SystemUiMode? mode, bool forceApply = false}) {
  if (!forceApply) {
    if (_appliedUiMode == mode) {
      return;
    }
    _appliedUiMode = mode;
  }

  if (_appliedUiMode == SystemUiMode.manual) {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top],
    );
  } else {
    if (_appliedUiMode != null) {
      SystemChrome.setEnabledSystemUIMode(_appliedUiMode!);
    }
  }
}
