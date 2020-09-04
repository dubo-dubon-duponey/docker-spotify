target "default" {
  inherits = ["shared"]
  args = {
    BUILD_TITLE = "Librespot"
    BUILD_DESCRIPTION = "A dubo image for Librespot"
  }
  tags = [
    "dubodubonduponey/librespot",
  ]
  // Cross compiling rust is so painstakingly long, reducing platforms to a minimum
  platforms = [
    "linux/amd64",
    "linux/arm64",
    "linux/arm/v7",
  ]
}
