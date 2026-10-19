import '../grid_ceiling_calculator.dart';
import 'l_ceiling_room.dart';

enum LCeilingStock { main10ft, cross4ft, cross2ft }

class LCeilingSection {
  final CeilingPoint start;
  final CeilingPoint end;
  final LCeilingStock stock;
  final bool isDivider;
  const LCeilingSection(this.start, this.end, this.stock,
      {this.isDivider = false});

  double get lengthMm => ((end.x - start.x).abs() + (end.y - start.y).abs());
}

class LCeilingTile {
  /// Grid footprint, not the physical tile's fitting clearance.
  final List<CeilingPoint> footprint;
  final bool isFull;
  final double cutWidthMm;
  final double cutHeightMm;
  LCeilingTile(Iterable<CeilingPoint> footprint, this.isFull, this.cutWidthMm,
      this.cutHeightMm)
      : footprint = List.unmodifiable(footprint);
}

class LCeilingResult {
  final LCeilingRoom room;
  final PlacementMode mode;
  final List<LCeilingSection> sections;
  final List<LCeilingTile> tiles;
  final int mainRunnerPieces;
  final int tilesToBuy;
  final int wallAnglePieces;
  final int hangerWires;
  final int fourFootBeforeOptimization;
  final bool requiresPerimeterJunction;
  final double cuttingAllowanceMm;

  LCeilingResult({
    required this.room,
    required this.mode,
    required Iterable<LCeilingSection> sections,
    required Iterable<LCeilingTile> tiles,
    required this.mainRunnerPieces,
    required this.tilesToBuy,
    required this.wallAnglePieces,
    required this.hangerWires,
    required this.fourFootBeforeOptimization,
    required this.requiresPerimeterJunction,
    required this.cuttingAllowanceMm,
  })  : sections = List.unmodifiable(sections),
        tiles = List.unmodifiable(tiles);

  double get areaM2 => room.areaMm2 / 1000000;
  double get areaSqFt => room.areaMm2 / 92903.04;
  int get fourFootPieces =>
      sections.where((s) => s.stock == LCeilingStock.cross4ft).length;
  int get twoFootPieces =>
      sections.where((s) => s.stock == LCeilingStock.cross2ft).length;
  int get fullTiles => tiles.where((t) => t.isFull).length;
  int get cutTiles => tiles.length - fullTiles;
}
