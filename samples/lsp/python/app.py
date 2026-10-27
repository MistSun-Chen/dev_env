"""LSP 练习：Python 主文件。

常用操作：
- K 悬停，gd 定义，grr 引用，grn 重命名
- <leader>ls 查看当前文件符号
- 输入 user. 或 display_name( 触发补全/签名
"""

from models import User, display_name


def main() -> None:
    user = User(name="Ada", age=36)
    print(display_name(user))

    # 在这里输入 user. 试试成员补全。
    # 在这里输入 display_name( 试试签名提示。
    _ = user


if __name__ == "__main__":
    main()
