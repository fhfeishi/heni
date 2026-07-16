bool shouldUseCompactBottomBar({
  required double windowWidth,
  required bool focusMode,
  required bool verticallyDense,
}) {
  return focusMode || verticallyDense || windowWidth < 1180;
}
