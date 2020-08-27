target "default" {
  inherits = ["shared"]
  args = {
    BUILD_TITLE = "Librespot"
    BUILD_DESCRIPTION = "A dubo image for Librespot"
  }
  tags = [
    "dubodubonduponey/librespot",
  ]
}
