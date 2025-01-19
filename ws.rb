require 'strscan'

# This is whitespace interpreter
class Whitespace
  def initialize
    # プログラムファイルの読み込み
    begin
      @code = ARGF.readlines.join unless ARGV.empty?
    rescue StandardError
      puts "#{ARGF.filename}: No such file or directory"
    end

    @code.gsub!(/[^ \t\n]/, '') # 空白文字以外は排除

    # IMP表
    @imps = {
      's' => :stack_mnpl,
      'ts' => :arithmetic,
      'tt' => :heap_access,
      'n' => :flow_cntl,
      'tn' => :io
    }

    # スタック操作コマンド表
    @imp_s = {
      's' => :push,
      'ns' => :duplicate,
      'ts' => :n_duplicate,
      'nt' => :switch,
      'nn' => :discard,
      'tn' => :n_discard
    }

    # 算術演算コマンド表
    @imp_ts = {
      'ss' => :add,
      'st' => :sub,
      'sn' => :mul,
      'ts' => :div,
      'tt' => :rem
    }

    # ヒープアクセスコマンド表
    @imp_tt = {
      's' => :h_push,
      't' => :h_pop
    }

    # フロー制御コマンド表
    @imp_n = {
      'ss' => :label_mark,
      'st' => :sub_start,
      'sn' => :jump,
      'ts' => :jump_zero,
      'tt' => :jump_negative,
      'tn' => :sub_end,
      'nn' => :end
    }

    # 入出力コマンド表
    @imp_tn = {
      'ss' => :output_char,
      'st' => :output_num,
      'ts' => :input_char,
      'tt' => :input_num
    }

    ## 字句解析
    begin
      @tokenized_list = tokenize
    rescue StandardError => e
      puts "Error: #{e.message}"
    end
    p @tokenized_list # 確認用

    ## 構文解析
    @tokens = []
    @tokenized_list.each_slice(3) do |a, b, c|
      @tokens << [a, b, c]
    end
    # p @tokens # 確認用

    ## 意味解析
    $stdout.sync = true
    $stdin.sync = true
    @pc = 0 # 現在の位置
    @stack = [] # スタック
    @heap = {} # ヒープ
    @labels = Hash.new do |h, k| # ジャンプラベル
      @tokens.each_with_index do |(imp, cmnd, prmt), idx|
        h[prmt] = idx if cmnd == :label_mark
      end
      h[k]
    end
    @sub_origin = [] # サブルーチンの呼び出し位置
    begin
      evaluate
    rescue SyntaxError => e
      puts "Error: #{e.message}"
    end
  end

  # 字句解析
  def tokenize
    result = []
    line = StringScanner.new(@code)

    loop do
      # IMP切り出し
      unless (imp_sp = line.scan(/\A( |\n|\t[ \n\t])/))
        raise StandardError, 'undefined imp'
      end

      repd_imp = stn_replace_to_s(imp_sp) # impを文字に変換
      imp = @imps[repd_imp] # impをシンボルに変換

      # コマンド切り出し
      cmd_sp = get_command(line, repd_imp) # コマンドを文字に変換

      command = instance_variable_get("@imp_#{repd_imp}")[stn_replace_to_s(cmd_sp)] # コマンドをシンボルに変換

      # パラメータ切り出し(必要なら)
      if parameter_check(imp, command)
        unless (param_sp = line.scan(/\A([ \t]+\n)/))
          raise StandardError, 'undefined parameter'
        end

        param_sp.chop! # 最後の改行を削除
        param = stn_replace_to_i(param_sp) # パラメータを01に変換
      end

      result << imp << command << param
      break unless line.exist?(/ |\t|\n/)
    end
    result
  end

  # 意味解析
  def evaluate
    loop do
      imp, cmnd, prmt = @tokens[@pc]
      @pc += 1
      # puts "#{imp} #{cmnd} #{prmt}" # 確認用

      case imp
      when :stack_mnpl
        case cmnd
        when :push
          @stack.push(prmt)
        when :duplicate
          @stack.push(@stack.last)
        when :n_duplicate
          @stack.push(@stack[convert_to_decimal(prmt)])
        when :switch
          @stack.push(@stack.slice!(-2))
        when :discard
          @stack.pop
        when :n_discard
          @stack.delete_at(convert_to_decimal(prmt))
        else
          raise SyntaxError, "#{cmnd} SyntaxError"
        end

      when :arithmetic
        f_elm = convert_to_decimal(@stack.pop)
        s_elm = convert_to_decimal(@stack.pop)

        case cmnd
        when :add
          ans = s_elm + f_elm
        when :sub
          ans = s_elm - f_elm
        when :mul
          ans = s_elm * f_elm
        when :div
          ans = s_elm / f_elm
        when :rem
          ans = s_elm % f_elm
        else
          raise SyntaxError, "#{cmnd} SyntaxError"
        end

        if ans.negative?
          ans = -ans
          result = "1#{ans.to_s(2)}"
        else
          result = "0#{ans.to_s(2)}"
        end
        @stack.push(result)

      when :heap_access
        case cmnd
        when :h_push
          value = @stack.pop
          key = @stack.pop
          @heap[key] = value
        when :h_pop
          @stack.push(@heap[@stack.pop])
        else
          raise SyntaxError, "#{cmnd} SyntaxError"
        end

      when :flow_cntl
        case cmnd
        when :label_mark
          @labels[prmt] = @pc
        when :sub_start
          @sub_origin.push(@pc)
          @pc = @labels[prmt]
        when :jump
          @pc = @labels[prmt]
        when :jump_zero
          @pc = @labels[prmt] if convert_to_decimal(@stack.pop).zero?
        when :jump_negative
          @pc = @labels[prmt] if convert_to_decimal(@stack.pop).negative?
        when :sub_end
          @pc = @sub_origin.pop
        when :end
          break
        else
          raise SyntaxError, " #{cmnd} SyntaxError"
        end

      when :io
        case cmnd
        when :output_char
          $stdout << convert_to_decimal(@stack.pop).chr
        when :output_num
          $stdout << convert_to_decimal(@stack.pop)
        when :input_char
          @heap[@stack.pop] = "0#{$stdin.getc.ord.to_s(2)}"
        when :input_num
          input = $stdin.gets.to_i
          @heap[@stack.pop] = if input.negative?
                                input = -input
                                "1#{input.to_s(2)}"
                              else
                                "0#{input.to_s(2)}"
                              end
        else
          raise SyntaxError, "#{cmnd} SyntaxError"
        end
      else
        raise SyntaxError, "#{imp} SyntaxError"
      end

      raise SyntaxError, 'SyntaxError' if @pc >= @tokens.length

      # p @stack # 確認用
      # p @heap # 確認用
    end
  end

  # 空白文字を文字に変換
  def stn_replace_to_s(space)
    result = []
    space.chars.each do |sp|
      case sp
      when ' '
        result << 's'
      when /\t/
        result << 't'
      when /\n/
        result << 'n'
      end
    end
    result.join
  end

  # パラメータを01に変換
  def stn_replace_to_i(space)
    result = []
    space.chars.each do |sp|
      case sp
      when ' '
        result << '0'
      when /\t/
        result << '1'
      end
    end
    result.join
  end

  # コマンドを抽出
  def get_command(line, imp)
    result = nil

    case imp
    when 's'
      result = line.scan(/\A( |\n[ \n\t]|\t[ \n])/)
    when 'ts'
      result = line.scan(/\A( [ \t\n]|\t[ \t])/)
    when 'tt'
      result = line.scan(/\A( |\t)/)
    when 'n'
      result = line.scan(/\A( [ \t\n]|\t[ \t\n]|\n\n)/)
    when 'tn'
      result = line.scan(/\A( [ \t]|\t[ \t])/)
    end
    raise StandardError, 'undefined command' unless result

    result
  end

  # パラメータの有無を確認
  def parameter_check(imp, cmd)
    return true if imp == :stack_mnpl && cmd == :push
    return true if imp == :stack_mnpl && cmd == :n_duplicate
    return true if imp == :stack_mnpl && cmd == :n_discard

    return true if imp == :flow_cntl && cmd != :sub_end && cmd != :end

    false
  end

  # 2進数を10進数に変換
  def convert_to_decimal(binary)
    sign = binary.slice(0)

    binary = binary[1..]
    result = binary.to_i(2)

    return -result if sign == '1'

    result
  end
end

Whitespace.new