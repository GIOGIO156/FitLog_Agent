import 'package:flutter/material.dart';

class SelectedDateHeader extends StatelessWidget {
  const SelectedDateHeader({
    super.key,
    required this.dateText,
    required this.changeLabel,
    required this.onPrevious,
    required this.onNext,
    required this.onChangeDate,
    this.textStyle,
  });

  final String dateText;
  final String changeLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onChangeDate;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
        Expanded(
          child: Text(dateText, textAlign: TextAlign.center, style: textStyle),
        ),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
        TextButton(onPressed: onChangeDate, child: Text(changeLabel)),
      ],
    );
  }
}
