import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/providers/FestivalProvider.dart';
import 'package:scenickazatva_app/widgets/FirebaseImage.dart';

/// Displays the active festival's logo, title, subtitle and date range.
class FestivalInfoCard extends StatelessWidget {
  const FestivalInfoCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final festivalProvider = Provider.of<FestivalProvider>(context);
    final fest = festivalProvider.festival;

    if (fest.title.isEmpty) return const SizedBox.shrink();

    final dateRange = fest.startDate != null && fest.endDate != null
        ? "${DateFormat("d.M.").format(fest.startDate!)} – ${DateFormat("d.M. yyyy").format(fest.endDate!)}"
        : "";

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            if (fest.logo.isNotEmpty)
              Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.only(right: 16),
                child: FirebaseImage(
                  url: fest.logo,
                  fit: BoxFit.contain,
                  placeholder: const Icon(Icons.festival, size: 40),
                  errorPlaceholder: const Icon(Icons.festival, size: 40),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fest.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (fest.subtitle.isNotEmpty)
                    Text(
                      fest.subtitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  if (dateRange.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        dateRange,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
