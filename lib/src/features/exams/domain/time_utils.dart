class ExamsTimeUtils {
  static int parseHm(String hm) {
    final parts = hm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return h * 60 + m;
  }

  static bool overlaps(String aStart, String aEnd, String bStart, String bEnd) {
    final as = parseHm(aStart);
    final ae = parseHm(aEnd);
    final bs = parseHm(bStart);
    final be = parseHm(bEnd);
    return !(ae <= bs || as >= be);
  }
}

