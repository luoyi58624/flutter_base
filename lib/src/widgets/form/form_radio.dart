//
// import 'package:mowork/global.dart';
//
// class FormRadioWidget extends FormField<String> {
//   FormRadioWidget({super.key, required this.listData})
//       : super(
//           onSaved: (value) {
//             LoggerUtil.i(value);
//           },
//           validator: (value) {
//             if (value != '选项二') {
//               return '必须选择选项二';
//             }
//             return null;
//           },
//           initialValue: '选项二',
//           builder: (FormFieldState<String> state) {
//             return Column(
//               children: [
//                 Row(
//                   children: listData
//                       .map(
//                         (e) => Radio(
//                           value: e,
//                           groupValue: state.value,
//                           onChanged: (value) {
//                             // LoggerUtil.i(value);
//                             state.didChange(value);
//                           },
//                         ),
//                       )
//                       .toList(),
//                 ),
//                 if (state.errorText != null)
//                   Text(
//                     state.errorText!,
//                     style: TextStyle(
//                       color: appTheme.errorColor,
//                       fontSize: hintFontSize[
//                               FormInheritedWidget.of(state.context)?.size] ??
//                           defaultHintFontSize,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//               ],
//             );
//           },
//         );
//   final List<String> listData;
// }
//
// /// 测试组件，不要使用
// class RadioWidget extends StatefulWidget {
//   const RadioWidget({super.key});
//
//   @override
//   State<RadioWidget> createState() => _RadioWidgetState();
// }
//
// class _RadioWidgetState extends State<RadioWidget> {
//   String value = '选项一';
//   List<String> listData = ['选项一', '选项二'];
//
//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: listData
//           .map(
//             (e) => Radio(
//               value: e,
//               groupValue: value,
//               onChanged: (value) {
//                 LoggerUtil.i(value);
//                 setState(() {
//                   this.value = value!;
//                 });
//               },
//             ),
//           )
//           .toList(),
//     );
//   }
// }
//
// class FormRadioWidget extends StatefulWidget {
//   const FormRadioWidget({super.key});
//
//   @override
//   State<FormRadioWidget> createState() => _FormRadioWidgetState();
// }
//
// class _FormRadioWidgetState extends State<FormRadioWidget> {
//   String value = '选项一';
//   List<String> listData = ['选项一', '选项二'];
//
//   @override
//   Widget build(BuildContext context) {
//     return FormField(
//       initialValue: value,
//       validator: (value) {
//         if (value != '选项二') {
//           return '必须选择选项二';
//         }
//         return null;
//       },
//       builder: (FormFieldState<String> state) {
//         return Column(
//           children: [
//             Row(
//               children: listData
//                   .map(
//                     (e) => Radio(
//                       value: e,
//                       groupValue: state.value,
//                       onChanged: (value) {
//                         LoggerUtil.i(value);
//                         state.didChange(value);
//                       },
//                     ),
//                   )
//                   .toList(),
//             ),
//             if (state.errorText != null)
//               Text(
//                 state.errorText!,
//                 style: TextStyle(
//                   color: appTheme.errorColor,
//                   fontSize: hintFontSize[FormInheritedWidget.of(state.context)?.size] ?? hintFontSize[FormSize.medium]!,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//           ],
//         );
//       },
//     );
//   }
// }
