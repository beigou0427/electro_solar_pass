// ==========================================
// 專案名稱：電光證照霸 PRO (ElectroSolar Pass)
// 檔案：lib/utils/ast_math_evaluator.dart
// CTO 注入：Guido van Rossum (Python 之父) - 第 1/3 段：電工 AST 抽象語法樹求值器
// 說明：[符號運算核心] 遞迴下降解析器，動態求值電學公式，零 eval、iOS 原生 AOT 免疫
// ==========================================

import 'dart:math';

/// 詞法單元型別 (Token Types)
enum MathTokenType {
  number,
  identifier,
  plus,
  minus,
  multiply,
  divide,
  power,
  lParen,
  rParen,
  eof
}

/// 詞法標記 (Token)
class MathToken {
  final MathTokenType type;
  final String text;
  final double value;

  const MathToken(this.type, this.text, [this.value = 0.0]);
}

/// AST 抽象語法樹節點基底
abstract class AstNode {
  double evaluate(Map<String, double> context);
}

class NumberNode extends AstNode {
  final double value;
  NumberNode(this.value);
  @override
  double evaluate(Map<String, double> context) => value;
}

class VariableNode extends AstNode {
  final String name;
  VariableNode(this.name);
  @override
  double evaluate(Map<String, double> context) {
    if (name == 'sqrt3') return 1.7320508075688772; // 電工核心常數 √3
    if (name == 'pi') return pi;
    return context[name] ?? (throw FormatException("未定義的電氣變數: $name"));
  }
}

class BinaryOpNode extends AstNode {
  final AstNode left;
  final MathTokenType op;
  final AstNode right;

  BinaryOpNode(this.left, this.op, this.right);

  @override
  double evaluate(Map<String, double> context) {
    final l = left.evaluate(context);
    final r = right.evaluate(context);
    switch (op) {
      case MathTokenType.plus: return l + r;
      case MathTokenType.minus: return l - r;
      case MathTokenType.multiply: return l * r;
      case MathTokenType.divide:
        if (r == 0) throw const FormatException("電氣計算異常：除數不能為零");
        return l / r;
      case MathTokenType.power: return pow(l, r).toDouble();
      default: throw FormatException("不支援的運算子: $op");
    }
  }
}

class FunctionNode extends AstNode {
  final String funcName;
  final AstNode arg;

  FunctionNode(this.funcName, this.arg);

  @override
  double evaluate(Map<String, double> context) {
    final v = arg.evaluate(context);
    switch (funcName.toLowerCase()) {
      case 'sqrt':
        if (v < 0) throw const FormatException("根號內不得為負數");
        return sqrt(v);
      case 'cos': return cos(v);
      case 'sin': return sin(v);
      case 'tan': return tan(v);
      default: throw FormatException("未支援的數學函數: $funcName");
    }
  }
}

/// Guido van Rossum 電工抽象語法樹解析器 (Recursive Descent Parser)
class ElectricalAstEvaluator {
  /// 一鍵執行電學字串公式解析與求值
  /// 範例：eval("sqrt3 * V * I * pf", {'V': 220, 'I': 50, 'pf': 0.85}) ➔ 32389.35 (W)
  static double evaluate(String expression, [Map<String, double> context = const {}]) {
    final tokens = _tokenize(expression);
    final parser = _Parser(tokens);
    final ast = parser.parse();
    return ast.evaluate(context);
  }

  /// 詞法掃描器 (Lexer)
  static List<MathToken> _tokenize(String text) {
    final List<MathToken> tokens = [];
    int i = 0;
    while (i < text.length) {
      final c = text[i];
      if (c == ' ' || c == '\t' || c == '\n') {
        i++;
        continue;
      }
      if (c == '+') { tokens.add(const MathToken(MathTokenType.plus, '+')); i++; }
      else if (c == '-') { tokens.add(const MathToken(MathTokenType.minus, '-')); i++; }
      else if (c == '*' || c == '×') { tokens.add(const MathToken(MathTokenType.multiply, '*')); i++; }
      else if (c == '/' || c == '÷') { tokens.add(const MathToken(MathTokenType.divide, '/')); i++; }
      else if (c == '^') { tokens.add(const MathToken(MathTokenType.power, '^')); i++; }
      else if (c == '(') { tokens.add(const MathToken(MathTokenType.lParen, '(')); i++; }
      else if (c == ')') { tokens.add(const MathToken(MathTokenType.rParen, ')')); i++; }
      else if (_isDigit(c) || c == '.') {
        final start = i;
        while (i < text.length && (_isDigit(text[i]) || text[i] == '.')) {
          i++;
        }
        final numStr = text.substring(start, i);
        tokens.add(MathToken(MathTokenType.number, numStr, double.parse(numStr)));
      } else if (_isAlpha(c)) {
        final start = i;
        while (i < text.length && (_isAlpha(text[i]) || _isDigit(text[i]))) {
          i++;
        }
        final id = text.substring(start, i);
        tokens.add(MathToken(MathTokenType.identifier, id));
      } else {
        throw FormatException("非法字元: $c");
      }
    }
    tokens.add(const MathToken(MathTokenType.eof, ''));
    return tokens;
  }

  static bool _isDigit(String s) => s.codeUnitAt(0) >= 48 && s.codeUnitAt(0) <= 57;
  static bool _isAlpha(String s) {
    final code = s.codeUnitAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122) || s == '_';
  }
}

/// 語法解析器 (Parser)
class _Parser {
  final List<MathToken> tokens;
  int _pos = 0;

  _Parser(this.tokens);

  MathToken get _current => tokens[_pos];

  MathToken _consume(MathTokenType type) {
    if (_current.type == type) {
      final t = _current;
      _pos++;
      return t;
    }
    throw FormatException("預期 $type 但得到 ${_current.type}");
  }

  AstNode parse() {
    final node = _parseExpression();
    if (_current.type != MathTokenType.eof) {
      throw const FormatException("公式語法未完全解析");
    }
    return node;
  }

  AstNode _parseExpression() => _parseAddition();

  AstNode _parseAddition() {
    var node = _parseMultiplication();
    while (_current.type == MathTokenType.plus || _current.type == MathTokenType.minus) {
      final op = _current.type;
      _pos++;
      node = BinaryOpNode(node, op, _parseMultiplication());
    }
    return node;
  }

  AstNode _parseMultiplication() {
    var node = _parsePower();
    while (_current.type == MathTokenType.multiply || _current.type == MathTokenType.divide) {
      final op = _current.type;
      _pos++;
      node = BinaryOpNode(node, op, _parsePower());
    }
    return node;
  }

  AstNode _parsePower() {
    var node = _parsePrimary();
    if (_current.type == MathTokenType.power) {
      _pos++;
      node = BinaryOpNode(node, MathTokenType.power, _parsePower());
    }
    return node;
  }

  AstNode _parsePrimary() {
    if (_current.type == MathTokenType.number) {
      final v = _current.value;
      _consume(MathTokenType.number);
      return NumberNode(v);
    }
    if (_current.type == MathTokenType.minus) {
      _consume(MathTokenType.minus);
      return BinaryOpNode(NumberNode(0.0), MathTokenType.minus, _parsePrimary());
    }
    if (_current.type == MathTokenType.identifier) {
      final name = _current.text;
      _consume(MathTokenType.identifier);
      if (_current.type == MathTokenType.lParen) {
        _consume(MathTokenType.lParen);
        final arg = _parseExpression();
        _consume(MathTokenType.rParen);
        return FunctionNode(name, arg);
      }
      return VariableNode(name);
    }
    if (_current.type == MathTokenType.lParen) {
      _consume(MathTokenType.lParen);
      final node = _parseExpression();
      _consume(MathTokenType.rParen);
      return node;
    }
    throw FormatException("語法錯誤於: ${_current.text}");
  }
}
