enum ColorMode {
  system, // dynamic colors
  mesh,
  oled,
  yaru,
  custom; // user-defined seed color

  static const ColorMode locara = ColorMode.mesh;
}
