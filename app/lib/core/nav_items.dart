import 'package:flutter/material.dart';

import 'theme/zcolors.dart';

class NavItem {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  const NavItem(this.label, this.icon, this.gradient);
}

const List<NavItem> kNavItems = <NavItem>[
  NavItem('Dashboard', Icons.grid_view_rounded, ZColors.gradientAccent),
  NavItem('Processes', Icons.memory_rounded, ZColors.gradientCpu),
  NavItem('Network', Icons.wifi_rounded, ZColors.gradientNet),
  NavItem('Disk', Icons.storage_rounded, ZColors.gradientDisk),
  NavItem('RAM', Icons.view_in_ar_rounded, ZColors.gradientRam),
  NavItem('GPU', Icons.videogame_asset_rounded, ZColors.gradientGpu),
];
