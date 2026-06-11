import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';

class LiveTrainNotificationsScreen extends StatelessWidget {
  const LiveTrainNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.08),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Live Train Notifications',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.primary),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        children: [
          // Service disruption banner
          const _DisruptionBanner(),
          const SizedBox(height: 20),

          // Departures header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Departures',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: const Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 16, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      'Customize',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // KJ Line card
          const _DepartureCard(
            lineColor: AppColors.kjLineRed,
            lineLabel: 'KJ Line',
            platform: 'Platform 1',
            station: 'KL Sentral',
            isStarred: true,
            departures: [
              _DepartureEntry(
                direction: 'Towards Gombak',
                status: _DepartureStatus.onTime,
                minutes: '2 min',
                isPrimary: true,
              ),
              _DepartureEntry(
                direction: 'Towards Gombak',
                status: null,
                minutes: '8 min',
                isPrimary: false,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Kajang Line card
          const _DepartureCard(
            lineColor: AppColors.kajangLineGreen,
            lineLabel: 'Kajang Line',
            platform: 'Platform 2',
            station: 'Pasar Seni',
            isStarred: false,
            departures: [
              _DepartureEntry(
                direction: 'Towards Kwasa Damansara',
                status: _DepartureStatus.delayed,
                minutes: '14 min',
                isPrimary: true,
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(currentTab: NavTab.announcement),
    );
  }
}

class _DisruptionBanner extends StatelessWidget {
  const _DisruptionBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 22, color: AppColors.secondary),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Service Disruption',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Minor delays on the MRT Putrajaya Line due to track maintenance near Cyberjaya. Please allow extra travel time.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.onErrorContainer,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: AppColors.secondary),
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

enum _DepartureStatus { onTime, delayed }

class _DepartureEntry {
  final String direction;
  final _DepartureStatus? status;
  final String minutes;
  final bool isPrimary;
  const _DepartureEntry({
    required this.direction,
    required this.status,
    required this.minutes,
    required this.isPrimary,
  });
}

class _DepartureCard extends StatelessWidget {
  final Color lineColor;
  final String lineLabel;
  final String platform;
  final String station;
  final bool isStarred;
  final List<_DepartureEntry> departures;

  const _DepartureCard({
    required this.lineColor,
    required this.lineLabel,
    required this.platform,
    required this.station,
    required this.isStarred,
    required this.departures,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Color bar
            Container(width: 6, color: lineColor),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: lineColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      lineLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.4,
                                        color: lineColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.location_on_outlined,
                                      size: 13, color: AppColors.onSurfaceVariant),
                                  const SizedBox(width: 2),
                                  Text(
                                    platform,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                station,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isStarred ? Icons.star : Icons.star_border,
                          size: 22,
                          color: isStarred ? AppColors.primary : AppColors.outline,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Departure entries
                    ...departures.map((d) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _DepartureRow(entry: d),
                        )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DepartureRow extends StatelessWidget {
  final _DepartureEntry entry;
  const _DepartureRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: entry.isPrimary ? 1.0 : 0.65,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.surfaceVariant),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.direction,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  if (entry.status != null) ...[
                    const SizedBox(height: 4),
                    _StatusBadge(status: entry.status!),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _TimingDisplay(
              minutes: entry.minutes,
              isDelayed: entry.status == _DepartureStatus.delayed,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final _DepartureStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isOnTime = status == _DepartureStatus.onTime;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isOnTime
            ? AppColors.tertiaryContainer.withOpacity(0.2)
            : AppColors.secondaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOnTime ? Icons.check_circle_outline : Icons.access_time,
            size: 11,
            color: isOnTime ? AppColors.tertiary : AppColors.secondary,
          ),
          const SizedBox(width: 4),
          Text(
            isOnTime ? 'On Time' : '10 min Delay',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isOnTime ? AppColors.tertiary : AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimingDisplay extends StatefulWidget {
  final String minutes;
  final bool isDelayed;
  const _TimingDisplay({required this.minutes, required this.isDelayed});

  @override
  State<_TimingDisplay> createState() => _TimingDisplayState();
}

class _TimingDisplayState extends State<_TimingDisplay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _opacity = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
    if (widget.isDelayed) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Text(
      widget.minutes,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: widget.isDelayed ? AppColors.secondary : AppColors.primary,
      ),
    );
    if (!widget.isDelayed) return text;
    return FadeTransition(opacity: _opacity, child: text);
  }
}
