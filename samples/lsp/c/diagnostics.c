#include "math_utils.h"

void broken(void) {
  Point p = {.x = 1, .y = 2};
  int wrong = "not an int";
  int missing = add(1);

  (void)p;
  (void)wrong;
  (void)missing;
}
