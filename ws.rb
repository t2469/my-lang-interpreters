require "strscan"

class WhiteSpace
  def initialize
    @code = ""
    @file_name = ARGV[0]
    @file = open(@file_name) # コマンドライン引数で渡されたファイルの内容を取得
    @file.each do |line|
      @code << line
    end
    tokens = tokenize
    puts tokens.inspect
  end

  def tokenize # 字句解析
    result = []
    scanner = StringScanner.new(@code)
    while !(scanner.eos?) # スキャンが最後尾まで達したか
      para = nil # パラメーターをnilに
      unless scanner.scan(/\A( |\n|\t[ \n\t])/)
        raise Exception, "undefined imp"
      end
      imps = {
        " " => :stack,
        "\t " => :arithmetic,
        "\t\t" => :heap,
        "\n" => :flow,
        "\t\n" => :io
      }
      imp = imps[scanner[0]]
      case imp
        #-----スタック操作-----
      when :stack
        unless scanner.scan(/ |\n[ \t\n]/)
          raise Exception, "undefined cmd of stack"
        end
        cmds = {
          " " => :push,
          "\n " => :duplicate,
          "\n\t" => :swap,
          "\n\n" => :discard
        }
        cmd = cmds[scanner[0]]
        if cmd == :push # pushの場合パラメータを取得
          unless scanner.scan(/[ \t]+\n/) # \nが来るまではパラメーター
            raise Exception, "undefined parameter of stack"
          end
          para = scanner[0]
        end

        #-----演算-----
      when :arithmetic
        unless scanner.scan(/ [ \t\n]|\t[ \t]/)
          raise Exception, "undefined cmd of arithmetic"
        end
        cmds = {
          " " => :addition,
          " \t" => :subtraction,
          " \n" => :multiplicate,
          "\t " => :integer_division,
          "\t\t" => :modulo
        }
        cmd = cmds[scanner[0]]

        #-----ヒープ操作-----
      when :heap
        unless scanner.scan(/ |\t/)
          raise Exception, "undefined cmd of heap"
        end
        cmds = {
          " " => :store,
          "\t" => :retrieve
        }
        cmd = cmds[scanner[0]]

        #-----制御命令-----
      when :flow
        unless scanner.scan(/ [ \t\n]|\t[ \t\n]|\n\n/)
          raise Exception, "undefined cmd of flow"
        end
        cmds = {
          " " => :mark,
          " \t" => :call,
          " \n" => :jump_uncondionally,
          "\t " => :jump_zero,
          "\t\t" => :jump_negative,
          "\t\n" => :end_and_transfer,
          "\n\n" => :end,
        }
        cmd = cmds[scanner[0]]
        unless (cmd == :end_and_transfer) || (cmd == :end) #end_and_transferもしくはend以外のコマンドの場合パラメータを取得
          unless scanner.scan(/[ \t]+\n/) # \nが来るまではパラメーター
            raise Exception, "undefined parameter of flow"
          end
          para = scanner[0]
        end

        #-----入出力-----
      when :io
        unless scanner.scan(/ [ \t]|\t[ \t]/)
          raise Exception, "undefined cmd of io"
        end
        cmds = {
          " " => :output_character,
          " \t" => :output_number,
          "\t " => :read_character,
          "\t\t" => :read_number
        }
        cmd = cmds[scanner[0]]
      end
      result << [imp,cmd,para] # それぞれを配列に格納
    end
    result
  end


end
WhiteSpace.new