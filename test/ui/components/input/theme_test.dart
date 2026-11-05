import 'package:flutter_base/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('输入族声明原样分派，泛型和原始参数不被注册表擦除', (tester) async {
    final seen = <Widget>[];
    Widget input(BuildContext context, ElInput component) {
      seen.add(component);
      return ElView();
    }

    Widget select<T>(BuildContext context, ElSelect<T> component) {
      seen.add(component);
      return ElView();
    }

    Widget autocomplete<T>(BuildContext context, ElAutocomplete<T> component) {
      seen.add(component);
      return ElView();
    }

    Widget number(BuildContext context, ElInputNumber component) {
      seen.add(component);
      return ElView();
    }

    Widget mention<T>(BuildContext context, ElMention<T> component) {
      seen.add(component);
      return ElView();
    }

    Widget tag(BuildContext context, ElInputTag component) {
      seen.add(component);
      return ElView();
    }

    Widget otp(BuildContext context, ElInputOtp component) {
      seen.add(component);
      return ElView();
    }

    final declarations = <Widget>[
      ElInput(value: 'input', textarea: true, minLine: 4),
      ElSelect<int>(value: 1, children: [ElLabelModel('one', 1)]),
      ElAutocomplete<int>(fetchSuggestions: (_) => [ElLabelModel('one', 1)]),
      ElInputNumber(value: 2.5, precision: 2),
      ElMention<int>(options: [ElMentionOption(value: 'one', data: 1)]),
      ElInputTag(value: ['one']),
      ElInputOtp(value: '12'),
    ];
    final builders = ElComponents(
      input: input,
      select: select,
      autocomplete: autocomplete,
      inputNumber: number,
      mention: mention,
      inputTag: tag,
      inputOtp: otp,
    );
    expect(builders.merge(ElComponents()), builders);
    expect(builders.copyWith(input: null).input, isNull);
    expect(builders.copyWith(select: null).select, isNull);
    expect(builders.copyWith(autocomplete: null).autocomplete, isNull);
    expect(builders.copyWith(inputNumber: null).inputNumber, isNull);
    expect(builders.copyWith(mention: null).mention, isNull);
    expect(builders.copyWith(inputTag: null).inputTag, isNull);
    expect(builders.copyWith(inputOtp: null).inputOtp, isNull);
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: ElComponentProvider(
          builders: builders,
          child: Column(children: declarations),
        ),
      ),
    );
    expect(seen, orderedEquals(declarations));
    expect(seen[1], isA<ElSelect<int>>());
    expect(seen[2], isA<ElAutocomplete<int>>());
    expect(seen[4], isA<ElMention<int>>());
  });
}
