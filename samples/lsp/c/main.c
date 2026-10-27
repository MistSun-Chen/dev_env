#include <stdio.h>

#include "math_utils.h"

int main(void) {
  Point p = {.x = 3, .y = 4};
  int total = add(p.x, p.y);

  printf("add: %d\n", total);
  printf("sum: %d\n", point_sum(p));

  // 输入 p. 试试成员补全；在 add / Point 上试 K、gd、grr、grn。
  return 0;
}
