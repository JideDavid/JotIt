import 'package:flutter/material.dart';
import '../../core/constants/sizes.dart';

class ZSnackBar {
  void success(BuildContext context, String successMessage) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(ZSizes.paddingSpaceLg),
        content: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: ZSizes.paddingSpaceLg),
            Expanded(
              child: Text(
                successMessage,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZSizes.borderRadiusLg),
        ),
      ),
    );
  }

  void error(BuildContext context, String errorMessage) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(ZSizes.paddingSpaceLg),
        content: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: ZSizes.paddingSpaceLg),
            Expanded(
              child: Text(
                errorMessage,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZSizes.borderRadiusLg),
        ),
      ),
    );
  }
}
