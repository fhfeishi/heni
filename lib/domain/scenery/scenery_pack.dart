class SceneryPack {
  const SceneryPack({
    required this.id,
    required this.name,
    required this.imagePaths,
    this.transition = SceneryTransition.slowCrossfade,
  });

  final String id;
  final String name;
  final List<String> imagePaths;
  final SceneryTransition transition;

  bool get isEmpty => imagePaths.isEmpty;
}

enum SceneryTransition {
  slowCrossfade,
  quietZoom,
}
