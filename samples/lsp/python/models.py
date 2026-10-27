"""LSP 练习：Python 数据模型。

把光标放在 User 或 display_name 上：
- K：看类型和文档
- gd：跳到定义
- grr：查看引用
- grn：重命名（会同步修改 app.py / diagnostics.py）
"""

from dataclasses import dataclass


@dataclass
class User:
    """一个用户。"""

    name: str
    age: int


def display_name(user: User) -> str:
    """返回适合显示的名字。"""
    return user.name
