#include "widget.hpp"

#include <iostream>
#include <utility>

Widget::Widget(std::string name) : name_(std::move(name)) {}

std::string Widget::label() const {
  return name_;
}

void Widget::draw() const {
  std::cout << name_ << '\n';
}

void Button::draw() const {
  std::cout << "[" << label() << "]\n";
}
