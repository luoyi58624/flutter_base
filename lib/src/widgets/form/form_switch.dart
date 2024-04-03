//
// import 'package:mowork/global.dart';
//
// @Deprecated('测试组件，不要使用')
// class FormSwitchWidget extends FormField<bool> {
//   FormSwitchWidget({
//     super.key,
//     required this.onChanged,
//   }) : super(
//           autovalidateMode: AutovalidateMode.onUserInteraction,
//           initialValue: false,
//           validator: (value) {
//             // LoggerUtil.i('验证: $value');
//             if (value == false) {
//               return '请打开';
//             }
//             return null;
//           },
//           onSaved: (value) {
//             // LoggerUtil.i(value);
//           },
//           builder: (FormFieldState<bool> state) {
//             // LoggerUtil.i(field.value);
//             return Column(
//               children: [
//                 Switch(
//                   value: state.value!,
//                   onChanged: (value) {
//                     state.didChange(value);
//                   },
//                 ),
//                 if (state.errorText != null)
//                   Text(
//                     state.errorText!,
//                     style: TextStyle(
//                       color: appTheme.errorColor,
//                       fontSize: hintFontSize[FormInheritedWidget.of(state.context)?.size] ?? hintFontSize[FormSize.medium]!,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//               ],
//             );
//           },
//         );
//
//   final ValueChanged<bool> onChanged;
//
// @override
// FormFieldState<bool> createState() => _FormSwitchWidgetState();
// }
//
// class _FormSwitchWidgetState extends FormFieldState<bool> {}
