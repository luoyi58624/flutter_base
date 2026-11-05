part of 'index.dart';

// 选择与语义由公共声明持有，这里的官方控件只提供视觉，避免一次点击更新两遍。
Widget _checkbox(ElCheckbox c, ElCheckboxState state) => ExcludeFocus(
  child: ExcludeSemantics(
    child: IgnorePointer(
      child: Row(
        mainAxisSize: .min,
        children: [
          Checkbox(
            value: c.indeterminate ? null : state.checked,
            tristate: true,
            onChanged: state.disabled ? null : (_) {},
          ),
          if (c.label != null) Text(c.label!),
        ],
      ),
    ),
  ),
);

Widget _radio(ElRadio c, ElRadioState state) => ExcludeFocus(
  child: ExcludeSemantics(
    child: IgnorePointer(
      child: Row(
        mainAxisSize: .min,
        children: [
          RadioGroup<bool>(
            groupValue: state.checked,
            onChanged: (_) {},
            child: Radio<bool>(value: true, enabled: !state.disabled),
          ),
          if (c.label != null) Text(c.label!),
        ],
      ),
    ),
  ),
);

TextEditingController _textController(ValueNotifier<String> model) {
  final value = useValueListenable(model);
  final controller = useTextEditingController(text: value);
  useEffect(() {
    if (controller.text != value) {
      controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
    return null;
  }, [controller, value]);
  return controller;
}

class _MaterialInput extends ElInputModelValue<String> {
  _MaterialInput(this.c) : super(value: c.value, modelValue: c.modelValue, onChanged: c.onChanged);
  final ElInput c;
  @override
  String? get value => super.value ?? '';
  @override
  Widget obsBuilder(BuildContext context) => _InputField(c, $obs);
}

class _InputField extends HookWidget {
  const _InputField(this.c, this.model);
  final ElInput c;
  final ValueNotifier<String> model;
  @override
  Widget build(BuildContext context) {
    final controller = _textController(model);
    final ownFocus = useFocusNode();
    final focus = c.focusNode ?? ownFocus;
    final hidden = useState(c.showPassword);
    useEffect(() {
      void changed() {
        if (focus.hasFocus) {
          c.onFocus?.call();
        } else {
          c.onBlur?.call();
          final prop = ElFormItem.maybeOf(context);
          if (prop != null) ElForm.maybeOf(context)?.validateField(prop, trigger: .blur);
        }
      }

      focus.addListener(changed);
      return () => focus.removeListener(changed);
    }, [focus, c.onFocus, c.onBlur]);
    Widget? suffix;
    if (c.showPassword) {
      suffix = IconButton(
        tooltip: '显示或隐藏密码',
        onPressed: c.disabled ? null : () => hidden.value = !hidden.value,
        icon: Icon(hidden.value ? Icons.visibility : Icons.visibility_off),
      );
    } else if (c.clearable && model.value.isNotEmpty && !c.disabled && !c.readOnly) {
      suffix = IconButton(
        tooltip: '清空输入',
        onPressed: () {
          model.value = '';
          c.onClear?.call();
        },
        icon: const Icon(Icons.clear),
      );
    } else if (c.suffix != null) {
      suffix = _content(c.suffix);
    }
    return _frame(
      c.style,
      c.semanticLabel,
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: c.width ?? 360),
        child: TextField(
          controller: controller,
          focusNode: focus,
          enabled: !c.disabled,
          readOnly: c.readOnly,
          canRequestFocus: !c.disabled && !c.readOnly,
          autofocus: c.autofocus,
          obscureText: !c.textarea && hidden.value,
          minLines: c.textarea ? c.minLine : 1,
          maxLines: c.textarea ? c.maxLine : 1,
          maxLength: c.maxLength,
          inputFormatters: c.inputFormatters,
          keyboardType: c.keyboardType,
          textInputAction: c.textInputAction,
          textAlign: c.textAlign ?? .start,
          textCapitalization: c.textCapitalization,
          keyboardAppearance: c.keyboardAppearance,
          smartDashesType: c.smartDashesType,
          smartQuotesType: c.smartQuotesType,
          autocorrect: c.autocorrect,
          enableSuggestions: c.enableSuggestions,
          enableInteractiveSelection: c.enableInteractiveSelection,
          enableIMEPersonalizedLearning: c.enableIMEPersonalizedLearning,
          autofillHints: c.autofillHints,
          cursorColor: c.caretColor,
          decoration: InputDecoration(
            hintText: c.placeholder,
            border: const OutlineInputBorder(),
            prefixIcon: c.prefix == null ? null : _content(c.prefix),
            suffixIcon: suffix,
            counterText: c.showWordLimit ? null : '',
          ),
          onChanged: (value) => model.value = value,
          onSubmitted: c.onSubmitted,
        ),
      ),
    );
  }
}

class _MaterialSelect<T> extends ElFormModelValue<T?> {
  _MaterialSelect(this.c)
    : super(
        value: c.value ?? c.initialSelection,
        modelValue: c.modelValue,
        onChanged: c.onChanged == null ? null : (value) => c.onChanged!(value as T),
      );
  final ElSelect<T> c;
  @override
  Widget obsBuilder(BuildContext context) => _frame(
    c.style,
    c.semanticLabel,
    LayoutBuilder(
      builder: (context, constraints) => DropdownMenu<T>(
        width: math.min(c.width ?? 320, constraints.maxWidth),
        initialSelection: $obs.value,
        enabled: c.enabled && !c.disabled,
        focusNode: c.focusNode,
        hintText: c.hintText,
        leadingIcon: c.leadingIcon,
        trailingIcon: c.trailingIcon,
        selectedTrailingIcon: c.selectedTrailingIcon,
        showTrailingIcon: c.showTrailingIcon,
        enableFilter: c.enableFilter,
        enableSearch: c.enableSearch,
        keyboardType: c.keyboardType,
        menuHeight: c.menuHeight,
        inputFormatters: c.inputFormatters,
        textInputAction: c.textInputAction,
        closeBehavior: c.closeBehavior,
        dropdownMenuEntries: [
          for (final item in c.children)
            DropdownMenuEntry<T>(
              value: (item.value ?? item.label) as T,
              label: item.label!,
              labelWidget: item is ElSelectOption<T> ? _content(item.content) : null,
              enabled: item is! ElSelectOption<T> || !item.disabled,
            ),
        ],
        onSelected: (value) {
          if (value == null) return;
          $obs.value = value;
          c.onSelected?.call(value);
        },
      ),
    ),
  );
}

class _MaterialAutocomplete<T> extends ElInputModelValue<String> {
  _MaterialAutocomplete(this.c) : super(value: c.value, modelValue: c.modelValue, onChanged: c.onChanged);
  final ElAutocomplete<T> c;
  @override
  String? get value => super.value ?? '';
  @override
  Widget obsBuilder(BuildContext context) => _AutocompleteField<T>(c, $obs);
}

class _AutocompleteField<T> extends HookWidget {
  const _AutocompleteField(this.c, this.model);
  final ElAutocomplete<T> c;
  final ValueNotifier<String> model;
  @override
  Widget build(BuildContext context) {
    final controller = _textController(model);
    final ownFocus = useFocusNode();
    final focus = c.focusNode ?? ownFocus;
    final generation = useRef(0);
    return _frame(
      c.style,
      c.semanticLabel,
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: c.width ?? 360),
        child: Autocomplete<ElLabelModel<T>>(
          textEditingController: controller,
          focusNode: focus,
          optionsMaxHeight: c.menuHeight,
          displayStringForOption: (option) => option.label ?? '${option.value}',
          optionsBuilder: (text) async {
            final request = ++generation.value;
            if (c.disabled || c.readOnly || (!c.triggerOnFocus && text.text.isEmpty)) return [];
            await Future<void>.delayed(c.debounce);
            if (!context.mounted || request != generation.value) return [];
            return c.fetchSuggestions(text.text);
          },
          onSelected: (option) {
            model.value = option.label ?? '${option.value}';
            c.onSelected?.call(option);
          },
          fieldViewBuilder: (context, editing, node, submit) => TextField(
            controller: editing,
            focusNode: node,
            enabled: !c.disabled,
            readOnly: c.readOnly,
            autofocus: c.autofocus,
            maxLength: c.maxLength,
            keyboardType: c.keyboardType,
            textInputAction: c.textInputAction,
            inputFormatters: c.inputFormatters,
            autofillHints: c.autofillHints,
            decoration: InputDecoration(
              hintText: c.placeholder,
              border: const OutlineInputBorder(),
              counterText: '',
              prefixIcon: c.prefix == null ? null : _content(c.prefix),
              suffixIcon: c.clearable && model.value.isNotEmpty
                  ? IconButton(
                      tooltip: '清空输入',
                      onPressed: c.disabled || c.readOnly
                          ? null
                          : () {
                              model.value = '';
                              c.onClear?.call();
                            },
                      icon: const Icon(Icons.clear),
                    )
                  : null,
            ),
            onChanged: (value) => model.value = value,
            onSubmitted: (value) {
              submit();
              c.onSubmitted?.call(value);
            },
          ),
        ),
      ),
    );
  }
}
