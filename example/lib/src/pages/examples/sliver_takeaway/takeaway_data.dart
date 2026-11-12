part of 'index.dart';

const _orange = Color(0xfff26718);
const _green = Color(0xff119865);
const _cuisines = ['盖码饭', '粉面', '轻食', '汉堡', '麻辣烫', '烤肉', '咖啡', '地方菜'];
// 与 Web 外卖示例使用同一张四列三行图集和菜系顺序。
const _cuisinePhotoTiles = [
  [11, 0, 1, 0, 1, 11],
  [2, 3, 2, 2, 3, 3],
  [5, 4],
  [6, 7],
  [8],
  [9, 0, 1],
  [10],
  [11, 0, 1],
];

String _money(int cents) => (cents / 100).toStringAsFixed(1);

class _Store {
  _Store({
    required this.id,
    required this.name,
    required this.rating,
    required this.sales,
    required this.minutes,
    required this.distance,
    required this.minimum,
    required this.coupon,
    required this.description,
    required this.review,
    required this.address,
    required this.tags,
    required this.dishes,
  });

  factory _Store.generate(int id) {
    // 每家店独立使用固定种子，惰性生成的先后顺序不会改变图片或文案。
    final random = fake.RandomGenerator(seed: 20261106 + id);
    final cuisine = id % _cuisines.length;
    final summary = _StoreSummary.generate(id, random);
    final ingredients = ['每日清晨采购新鲜食材', '坚持现点现做，拒绝隔夜复热', '米饭选用东北当季大米', '荤素搭配，分量扎实', '独立封签，打包整洁安心'];
    return _Store(
      id: id,
      name: summary.name,
      rating: summary.rating,
      sales: summary.sales,
      minutes: summary.minutes,
      distance: (random.integer(35, min: 3) / 10).toStringAsFixed(1),
      minimum: random.element([0, 10, 15, 20]),
      coupon: random.integer(16, min: 6),
      description: '${[for (var i = 0; i < 2 + id % 3; i++) ingredients[(id + i) % ingredients.length]].join('，')}。',
      review: random.element(['“热乎乎送到，配菜很丰富，已经回购好几次了。”', '“口味刚刚好，包装没有洒，忙碌工作日的午餐首选。”', '“分量足、出餐快，还贴心地把酱汁单独装好了。”']),
      address:
          '${random.element(['科苑', '学府', '春风', '花园'])}路 ${random.integer(188, min: 8)} 号 · 距离地铁口 ${random.integer(8, min: 1)} 分钟',
      tags: ['${random.integer(900, min: 100)} 人近7天下单', '${random.integer(9, min: 2)}年老店', '食无忧 · 放心吃'],
      dishes: [
        for (var index = 0; index < 10 + id % 3; index++)
          _Dish(
            name: _dishNames[cuisine][index % _dishNames[cuisine].length],
            subtitle: random.element(['招牌推荐 · 现点现做', '人气热卖 · 分量十足', '荤素搭配 · 一人吃好', '当季新品 · 值得一试']),
            cents: random.integer(350, min: 99) * 10,
            sales: random.integer(999, min: 50),
            praise: random.integer(100, min: 96),
          ),
      ],
    );
  }

  final int id;
  final String name;
  final String rating;
  final int sales;
  final int minutes;
  final String distance;
  final int minimum;
  final int coupon;
  final String description;
  final String review;
  final String address;
  final List<String> tags;
  final List<_Dish> dishes;
  double menuOffset = 0;
}

// 搜索和排序只建立轻量索引，菜品、图片与评价仍在进入视口时惰性生成。
class _StoreSummary {
  _StoreSummary(this.id, this.name, this.rating, this.sales, this.minutes);
  factory _StoreSummary.generate(int id, [fake.RandomGenerator? source]) {
    final random = source ?? fake.RandomGenerator(seed: 20261106 + id);
    final brand = random.element(['饭点到了', '小巷食堂', '阿婆小灶', '一碗好饭', '街角厨房', '食里香', '四季鲜食', '大口吃饭']);
    final name =
        '$brand · ${_cuisines[id % _cuisines.length]}（${random.element(['科技园', '南山', '大学城', '万象城', '花园路'])}${id + 1}店）';
    return _StoreSummary(
      id,
      name,
      (4.5 + random.integer(5) / 10).toStringAsFixed(1),
      random.integer(9800, min: 300),
      random.integer(40, min: 15),
    );
  }
  final int id;
  final String name;
  final String rating;
  final int sales;
  final int minutes;
}

class _Dish {
  _Dish({required this.name, required this.subtitle, required this.cents, required this.sales, required this.praise});
  final String name;
  final String subtitle;
  final int cents;
  final int sales;
  final int praise;
}

const _dishNames = [
  ['红烧土豆肉片盖码饭', '甜豆肉沫盖码饭', '香辣豆腐双拼饭', '小炒黄牛肉饭', '香菇滑鸡饭', '番茄炒蛋双拼饭'],
  ['招牌牛肉粉', '酸辣肥牛拌面', '鲜虾云吞面', '老坛酸菜肉丝面', '重庆豌杂小面', '菌菇鸡汤米线'],
  ['牛油果鸡胸能量碗', '香煎三文鱼沙拉', '黑椒牛肉杂粮饭', '南瓜藜麦暖沙拉', '烤南瓜鸡蛋三明治', '元气水果酸奶杯'],
  ['经典芝士牛肉堡', '香辣脆鸡堡套餐', '双层和牛汉堡', '黑椒鸡腿堡', '薯条鸡块分享盒', '香浓芝士热狗'],
  ['自选麻辣烫', '番茄浓汤冒菜', '麻酱拌菜双人餐', '川香肥牛冒菜', '藤椒鸡肉烫', '鲜蔬菌菇烫'],
  ['炭烤鸡腿饭', '秘制五花肉拌饭', '孜然牛肉烤肉饭', '韩式肥牛石锅饭', '泡菜猪肉拌饭', '照烧鸡肉双拼饭'],
  ['生椰拿铁', '桂花燕麦拿铁', '冰萃美式咖啡', '榛果风味拿铁', '牛角包早餐组合', '香浓巧克力可颂'],
  ['农家小炒肉套餐', '宫保鸡丁双拼饭', '鱼香肉丝套餐', '砂锅红烧肉', '杭椒牛柳套餐', '清蒸鲈鱼家常套餐'],
];
