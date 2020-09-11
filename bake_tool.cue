package bake

command: {
  image: #Dubo & {
    args: {
      BUILD_TITLE: "Librespot"
      BUILD_DESCRIPTION: "A dubo image for Librespot based on \(args.DEBOOTSTRAP_SUITE) (\(args.DEBOOTSTRAP_DATE))"
    }
  }
}
