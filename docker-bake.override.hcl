variable "REGISTRY" {
  default = "docker.io"
}

target "default" {
  inherits = ["shared"]
  args = {
    BUILD_TITLE = "Librespot"
    BUILD_DESCRIPTION = "A dubo image for Librespot"
  }
  tags = [
    "${REGISTRY}/dubodubonduponey/librespot",
  ]
}
