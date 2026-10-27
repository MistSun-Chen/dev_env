#pragma once

#include <string>

class Widget {
 public:
  explicit Widget(std::string name);
  virtual ~Widget() = default;

  std::string label() const;
  virtual void draw() const;

 private:
  std::string name_;
};

class Button : public Widget {
 public:
  using Widget::Widget;

  void draw() const override;
};
