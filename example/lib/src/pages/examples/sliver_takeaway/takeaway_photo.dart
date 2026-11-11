part of 'index.dart';

class _StorePhoto extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _StorePhoto({required this.store, required this.photos, required this.size, this.dishIndex});

  final ValueListenable<_Store?> store;
  final ValueListenable<bool> photos;
  final double size;
  final int? dishIndex;

  int _tile(_Store? record) {
    if (record == null) return 0;
    final tiles = _cuisinePhotoTiles[record.id % _cuisinePhotoTiles.length];
    return tiles[(dishIndex ?? 0) % tiles.length];
  }

  String _source(_Store? record) {
    if (record == null) return '';
    final index = dishIndex;
    return index == null
        ? 'https://picsum.photos/seed/takeaway-shop-${record.id}/160/160'
        : 'https://picsum.photos/seed/takeaway-dish-${record.id}-$index/360/360';
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    key: ValueKey(dishIndex == null ? 'takeaway-photo-logo' : 'takeaway-photo-dish-$dishIndex'),
    borderRadius: .circular(8),
    child: SizedBox.square(
      dimension: size,
      child: ValueListenableBuilder<bool>(
        valueListenable: photos,
        builder: (context, network, local) => network
            ? ElListenableBuilder<ValueListenable<_Store?>, String>(
                listenable: store,
                select: (source) => _source(source.value),
                builder: (_, _) => ElImage(_source(store.value), width: size, height: size, fit: .cover),
              )
            : local!,
        child: ElListenableBuilder<ValueListenable<_Store?>, int>(
          listenable: store,
          select: (source) => _tile(source.value),
          // 图集由 ElImage 加载；普通布局裁切图块，换店时保留图片实例。
          child: ElImage(
            'assets/recycler_cards/takeaway-food.webp',
            width: size * 4,
            height: size * 3,
            fit: .fill,
            filterQuality: .low,
          ),
          builder: (_, image) {
            final tile = _tile(store.value);
            return OverflowBox(
              alignment: Alignment(tile % 4 / 3 * 2 - 1, (tile ~/ 4 - 1).toDouble()),
              minWidth: size * 4,
              maxWidth: size * 4,
              minHeight: size * 3,
              maxHeight: size * 3,
              child: image,
            );
          },
        ),
      ),
    ),
  );
}
