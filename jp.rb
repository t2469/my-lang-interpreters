#!/usr/bin/ruby
require 'strscan'

#================================================
# 生成規則（文法定義）
#================================================
# 文列 = 文 (文)*
# 文 = 代入文 | ‘もし’文 | '繰り返し’'文 | print文 | '{' 文列 '}'
# 代入文 = 変数 ':=' 式 ';'
# もし文 = 'もし' 式 'ならば' 文 'そうでないなら' 文
# 繰り返し文 = '繰り返し' 式 文
# 表示文 = '表示' 式 ';'
# 式 = 項 (( '+' | '-' ) 項)*
# 項 = 因子 (( '*' | '/' ) 因子)*
# 因子 := '-'? (リテラル | '(' 式 ')')

class Jp
  DEBUG = true

  def initialize
    if ARGV.empty?
      puts "ファイルを指定してください。"
      exit
    end

    file_path = ARGV[0]
    unless File.exist?(file_path)
      puts "ファイルが存在しません: #{file_path}"
      exit
    end

    # 字句解析用のキーワード定義
    @keywords = {
      '+' => :add,
      '-' => :sub,
      '*' => :mul,
      '/' => :div,
      '%' => :mod,
      '(' => :lpar,
      ')' => :rpar,
      ':=' => :assign,
      ';' => :semi,
      'もし' => :if,
      'ならば' => :then,
      'そうでないなら' => :else,
      '繰り返し' => :for,
      '出力' => :print,
      '{' => :lbrace,
      '}' => :rbrace
    }.freeze
    @space = {} # 変数を管理するハッシュ
    code = File.read(file_path)
    @scanner = StringScanner.new(code)
    begin
      statements = parse_statements
      statements.each { |stmt| eval(stmt) }
    rescue => e
      puts "エラー: #{e.message}"
    end
  end

  #================================================
  # 字句解析(Lexer)
  #================================================
  def get_token
    # 空白をスキップ
    @scanner.skip(/\s+/)
    return nil if @scanner.eos?

    # キーワードのマッチング(演算子や予約語)
    @keywords.keys.each do |key|
      if @scanner.scan(Regexp.new(Regexp.escape(key)))
        return @keywords[key]
      end
    end

    # 変数名
    if (var = @scanner.scan(/\A[a-zA-Z_]\w*/))
      return [:var, var]
    end

    # 数値(整数や小数)
    if (num = @scanner.scan(/\A\d+(\.\d+)?/))
      return num.include?('.') ? num.to_f : num.to_i
    end

    bad = @scanner.getch
    raise "不正なトークンです: #{bad}"
  end

  def unget_token
    @scanner.unscan
  end

  #================================================
  # 構文解析(Parser)
  #================================================

  # 文列 = 文 (文)*
  def parse_statements
    stmts = []
    while (stmt = parse_statement)
      stmts << stmt
    end
    stmts
  end

  # 文 = 代入文 | 表示文
  def parse_statement
    token = get_token
    return nil if token.nil? # トークンが無ければ文なし

    if token.is_a?(Array) && token[0] == :var
      var_name = token[1]
      # 次に代入演算子が来るかチェック
      if get_token == :assign
        expr = expression
        # 最後に ; が来るかチェック
        expect(:semi, "代入文の末尾に ; がありません")
        return [:assign, var_name, expr]
      else
        raise "代入演算子 ':=' が必要です。"
      end

    elsif token == :print
      # 表示文
      expr = expression
      expect(:semi, "表示文の末尾に ; がありません")
      return [:print, expr]

    else
      # どれでもなければ、トークンを戻して終了(あるいはエラー)
      unget_token
      nil
    end
  end

  #-----------------------------------------------
  # 式 = 項 (( '+' | '-' ) 項)*
  #-----------------------------------------------
  def expression
    result = term
    while true
      token = get_token
      unless token == :add or token == :sub
        unget_token
        break
      end
      result = [token, result, term]
    end
    p ['E', result] if Jp::DEBUG
    result
  end

  #-----------------------------------------------
  # 項 = 因子 (( '*' | '/' ) 因子)*
  #-----------------------------------------------
  def term
    result = factor
    while true
      token = get_token
      unless token == :mul or token == :div
        unget_token
        break
      end
      result = [token, result, factor]
    end
    p ['T', result] if Jp::DEBUG
    result
  end

  #-----------------------------------------------
  # 因子 := '-'? (リテラル | 変数 | '(' 式 ')' )
  #-----------------------------------------------
  def factor
    token = get_token
    minus_flg = 1
    if token == :sub
      minus_flg = -1
      token = get_token
    end

    if token.is_a? Numeric
      p ['F', token * minus_flg] if Jp::DEBUG
      token * minus_flg
    elsif token.is_a?(Array) && token[0] == :var
      var_node = [:var, token[1]]
      if minus_flg == -1
        var_node = [:mul, -1, var_node]
      end
      p ['F(var)', var_node] if DEBUG
      return var_node
    elsif token == :lpar
      result = expression
      unless get_token == :rpar
        raise Exception, "unexpected token"
      end
      p ['F', [:mul, minus_flg, result]] if Jp::DEBUG
      return [:mul, minus_flg, result]
    else
      raise Exception, "unexpected token"
    end
  end

  #================================================
  # 意味解析(Evaluator)
  #================================================
  # 抽象構文木(AST)を評価・実行
  def eval(node)
    case node
    when Array
      case node[0]
      when :assign
        # node = [:assign, var_name, expr]
        var_name = node[1]
        value = eval(node[2])
        @space[var_name] = value
        return value

      when :print
        # node = [:print, expr]
        val = eval(node[1])
        puts val
        return val

      when :var
        # node = [:var, var_name]
        var_name = node[1]
        return @space[var_name] || raise("未定義の変数: #{var_name}")

      when :add, :sub, :mul, :div
        left_val = eval(node[1])
        right_val = eval(node[2])
        case node[0]
        when :add then left_val + right_val
        when :sub then left_val - right_val
        when :mul then left_val * right_val
        when :div
          raise "0で割ることはできません" if right_val == 0 # 0除算対策
          left_val.to_f / right_val
        end
      else
        # それ以外は未対応
        raise "未知のノードです: #{node[0]}"
      end

    when Integer, Float
      # 数値リテラル
      node
    else
      raise "評価不能なノードです: #{node.inspect}"
    end
  end

  #================================================
  # ヘルパー
  #================================================
  def expect(token_kind, err_msg)
    t = get_token
    raise err_msg unless t == token_kind
  end

end

Jp.new
