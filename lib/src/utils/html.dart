part of flutter_base;

class HtmlUtil {
  HtmlUtil._();

  /// html转纯文本
  static String htmlToText(String html) {
    final document = htmlparser.parse(html);
    return htmlparser.parse(document.body?.text).documentElement?.text ?? '';
  }
}
