/// Home-screen bag category tiles (image + post-requirement query).
class BagCategoryAssets {
  static const items = [
    BagCategoryItem(
      label: 'D-Cut',
      imageAsset: 'assets/images/category_d_cut.png',
      bagTypeQuery: 'D-Cut',
    ),
    BagCategoryItem(
      label: 'W-Cut',
      imageAsset: 'assets/images/category_w_cut.png',
      bagTypeQuery: 'W-Cut',
    ),
    BagCategoryItem(
      label: 'Box Bags',
      imageAsset: 'assets/images/category_box_bags.png',
      bagTypeQuery: 'Box',
    ),
    BagCategoryItem(
      label: 'Loop Handle',
      imageAsset: 'assets/images/category_loop_handle.png',
      bagTypeQuery: 'Loop',
    ),
    BagCategoryItem(
      label: 'Side Gusset',
      imageAsset: 'assets/images/category_side_gusset.png',
      bagTypeQuery: 'Side Gusset',
    ),
    BagCategoryItem(
      label: 'Other',
      imageAsset: 'assets/images/category_others.png',
      bagTypeQuery: 'Other',
    ),
  ];
}

class BagCategoryItem {
  final String label;
  final String imageAsset;
  final String bagTypeQuery;

  const BagCategoryItem({
    required this.label,
    required this.imageAsset,
    required this.bagTypeQuery,
  });
}
