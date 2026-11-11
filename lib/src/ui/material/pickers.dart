part of 'index.dart';

Widget _picker<T>(ElPicker<T> c, Obs<List<T>> model) {
  final lists = <List<ElMenuOption<T>>>[];
  final selected = <T>[];
  var options = c.options ?? <ElMenuOption<T>>[];
  for (var column = 0; c.columns != null ? column < c.columns!.length : options.isNotEmpty; column++) {
    if (c.columns != null) options = c.columns![column];
    lists.add(options);
    final available = options.where((o) => !o.disabled);
    if (available.isEmpty) break;
    final choice =
        available.where((o) => column < model.value.length && o.value == model.value[column]).firstOrNull ??
        available.first;
    selected.add(choice.value);
    if (c.columns == null) options = choice.children;
  }
  return ElView(
    style: c.style,
    event: c.event,
    child: Row(
      children: [
        for (var i = 0; i < lists.length; i++)
          Expanded(
            child: DropdownButton<T>(
              isExpanded: true,
              value: i < selected.length ? selected[i] : null,
              items: [
                for (final option in lists[i])
                  DropdownMenuItem(value: option.value, enabled: !option.disabled, child: _content(option.label)),
              ],
              onChanged: c.disabled
                  ? null
                  : (value) {
                      if (value == null) return;
                      final next = [...selected];
                      next[i] = value;
                      if (c.options != null) next.removeRange(i + 1, next.length);
                      model.value = next;
                    },
            ),
          ),
      ],
    ),
  );
}

Widget _timePicker(ElTimePicker c, Obs<Duration> model) => _frame(
  c.style,
  c.semanticLabel,
  Builder(
    builder: (context) => OutlinedButton(
      onPressed: c.disabled
          ? null
          : () async {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: model.value.inHours, minute: model.value.inMinutes % 60),
              );
              if (time == null) return;
              final value = Duration(hours: time.hour, minutes: (time.minute ~/ c.minuteStep) * c.minuteStep);
              model.value = value < c.min
                  ? c.min
                  : value > c.max
                  ? c.max
                  : value;
            },
      child: Text(
        '${model.value.inHours.toString().padLeft(2, '0')}:${(model.value.inMinutes % 60).toString().padLeft(2, '0')}',
      ),
    ),
  ),
);

Widget _upload(ElUpload c) => ElView(
  style: c.style,
  event: c.event,
  child: Column(
    mainAxisSize: .min,
    children: [
      if (c.onPick != null) OutlinedButton(onPressed: c.disabled ? null : c.onPick, child: const Text('选择文件')),
      if (c.hint != null) Text(c.hint!),
      for (final file in c.files)
        ListTile(
          title: Text(file.name),
          leading: file.thumbnail,
          subtitle: file.status == .uploading
              ? LinearProgressIndicator(value: file.progress / 100)
              : Text(file.error ?? file.status.name),
          trailing: Row(
            mainAxisSize: .min,
            children: [
              if (file.status == .error && c.onRetry != null)
                IconButton(onPressed: c.disabled ? null : () => c.onRetry!(file), icon: const Icon(Icons.refresh)),
              if (file.status == .uploading && c.onCancel != null)
                IconButton(onPressed: c.disabled ? null : () => c.onCancel!(file), icon: const Icon(Icons.close))
              else if (c.onRemove != null)
                IconButton(
                  onPressed: c.disabled ? null : () => c.onRemove!(file),
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
        ),
    ],
  ),
);

Widget _popup(ElPopup c) => ElView(
  style: c.style,
  event: c.event,
  child: Material(
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          Row(
            children: [
              Expanded(child: _content(c.title)),
              if (c.showClose)
                Builder(
                  builder: (context) =>
                      IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(child: SingleChildScrollView(child: c.child)),
          if (c.footer != null) ...[const SizedBox(height: 24), _content(c.footer)],
        ],
      ),
    ),
  ),
);
