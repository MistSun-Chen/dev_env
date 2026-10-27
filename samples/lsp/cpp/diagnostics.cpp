#include "widget.hpp"

void broken() {
  std::string wrong = 42;
  Widget widget = 7;

  (void)wrong;
  (void)widget;
}
