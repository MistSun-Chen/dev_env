"""LSP 练习：故意包含类型错误。

打开后：
- [d / ]d：在诊断之间跳转
- <leader>ld：打开当前文件诊断列表
- 光标放到错误上按 gra：看看 Pyright 提供什么 code action
"""

from models import User


def broken() -> int:
    user = User(name="Ada", age="三十六")
    value: int = user.name
    return value
