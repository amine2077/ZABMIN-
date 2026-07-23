import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/services/settings_service.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/zcolors.dart';
import '../widgets/glass_card.dart';
import '../widgets/screen_shell.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settings, _) {
        if (!settings.isLoaded) {
          return const Center(
            child: CircularProgressIndicator(color: ZColors.accent),
          );
        }

        return ScreenShell(
          title: 'Settings',
          subtitle: 'Configure alert thresholds and app behavior',
          accentGradient: ZColors.gradientAccent,
          children: [
            _ThresholdSection(settings: settings),
            const SizedBox(height: 20),
            _BehaviorSection(settings: settings),
          ],
        );
      },
    );
  }
}

class _ThresholdSection extends StatelessWidget {
  final SettingsService settings;
  const _ThresholdSection({required this.settings});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      hoverable: false,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: ZRadii.pill,
                  gradient: const LinearGradient(colors: ZColors.gradientDisk),
                ),
              ),
              const SizedBox(width: 10),
              Text('Alert Thresholds', style: ZText.title),
            ],
          ),
          const SizedBox(height: 20),
          _ThresholdSlider(
            label: 'CPU sustained high',
            value: settings.cpuThreshold,
            min: 50,
            max: 100,
            suffix: '%',
            gradient: ZColors.gradientCpu,
            onChanged: (v) => settings.setCpuThreshold(v),
          ),
          const SizedBox(height: 16),
          _ThresholdSlider(
            label: 'RAM high',
            value: settings.ramThreshold,
            min: 50,
            max: 100,
            suffix: '%',
            gradient: ZColors.gradientRam,
            onChanged: (v) => settings.setRamThreshold(v),
          ),
          const SizedBox(height: 16),
          _ThresholdSlider(
            label: 'Disk high',
            value: settings.diskThreshold,
            min: 70,
            max: 100,
            suffix: '%',
            gradient: ZColors.gradientDisk,
            onChanged: (v) => settings.setDiskThreshold(v),
          ),
          const SizedBox(height: 16),
          _ThresholdSlider(
            label: 'Network spike',
            value: settings.netThresholdMbS,
            min: 1,
            max: 100,
            suffix: ' MB/s',
            gradient: ZColors.gradientNet,
            decimals: 1,
            onChanged: (v) => settings.setNetThresholdMbS(v),
          ),
          const SizedBox(height: 16),
          _ThresholdSlider(
            label: 'CPU consecutive seconds',
            value: settings.cpuConsecutiveSeconds.toDouble(),
            min: 5,
            max: 120,
            suffix: 's',
            gradient: ZColors.gradientCpu,
            decimals: 0,
            onChanged: (v) => settings.setCpuConsecutiveSeconds(v.round()),
          ),
        ],
      ),
    );
  }
}

class _ThresholdSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String suffix;
  final List<Color> gradient;
  final int decimals;
  final ValueChanged<double> onChanged;

  const _ThresholdSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.gradient,
    this.decimals = 0,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final display = decimals > 0
        ? value.toStringAsFixed(decimals)
        : value.round().toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: ZText.body)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: gradient.first.withValues(alpha: 0.12),
                borderRadius: ZRadii.pill,
                border: Border.all(
                  color: gradient.first.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '$display$suffix',
                style: ZText.caption.copyWith(
                  color: gradient.first,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: gradient.first,
            inactiveTrackColor: ZColors.border,
            thumbColor: gradient.first,
            overlayColor: gradient.first.withValues(alpha: 0.15),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _BehaviorSection extends StatelessWidget {
  final SettingsService settings;
  const _BehaviorSection({required this.settings});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      hoverable: false,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: ZRadii.pill,
                  gradient: const LinearGradient(
                    colors: ZColors.gradientAccent,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('Behavior', style: ZText.title),
            ],
          ),
          const SizedBox(height: 20),
          _ToggleRow(
            label: 'Minimize to tray on close',
            subtitle: 'Keep monitoring in the background',
            icon: Icons.minimize_rounded,
            gradient: ZColors.gradientGpu,
            value: settings.minimizeToTray,
            onChanged: (v) => settings.setMinimizeToTray(v),
          ),
          const SizedBox(height: 14),
          _ToggleRow(
            label: 'Desktop notifications',
            subtitle: 'Windows toast for critical alerts',
            icon: Icons.notifications_rounded,
            gradient: ZColors.gradientRam,
            value: settings.toastNotifications,
            onChanged: (v) => settings.setToastNotifications(v),
          ),
          const SizedBox(height: 14),
          _ToggleRow(
            label: 'Launch on Windows startup',
            subtitle: 'Start automatically when you log in',
            icon: Icons.rocket_launch_rounded,
            gradient: ZColors.gradientNet,
            value: settings.launchAtStartupEnabled,
            onChanged: (v) => settings.setLaunchAtStartup(v),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: ZRadii.inner,
            gradient: LinearGradient(
              colors: gradient.map((c) => c.withValues(alpha: 0.18)).toList(),
            ),
            border: Border.all(color: ZColors.border),
          ),
          child: Icon(icon, color: gradient.first, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: ZText.body),
              const SizedBox(height: 2),
              Text(subtitle, style: ZText.caption),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: gradient.first,
        ),
      ],
    );
  }
}
