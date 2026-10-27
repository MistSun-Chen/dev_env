#include "widget.hpp"

int main() {
  Widget widget{"demo"};
  widget.draw();

  Button button{"ok"};
  button.draw();

  // 输入 widget. 试试补全；在 draw 上试 K、gd、gri、grr。
  // 在 Widget / Button 上试 grn，看看头文件和源文件是否一起改名。
  return 0;
}
