import 'package:flutter/material.dart';

class BreadcrumbItem {
  final String label;
  final VoidCallback? onTap;

  BreadcrumbItem({
    required this.label,
    this.onTap,
  });
}

class Breadcrumb extends StatelessWidget {
  final List<BreadcrumbItem> items;

  const Breadcrumb({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: List.generate(items.length, (index) {
        final item = items[index];

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: item.onTap,
              child: Text(
                item.label,
                style: TextStyle(
                  color: item.onTap != null
                      ? Colors.blue
                      : Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            if (index != items.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text(">"),
              ),
          ],
        );
      }),
    );
  }
}