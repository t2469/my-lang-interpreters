# 想定されていない入力を与えられた場合に表示させる
def usage
  puts 'usage: wc [-lcw] [file ...]'
  exit 1
end


# 引数は1つ以上必要
if ARGV.empty?
  usage
end


# オプションの初期化
show_line = false
show_word = false
show_byte = false


# ファイル名を格納するための配列
file_paths = []


# オプションとファイル名を解析
ARGV.each do |arg|
  if arg.start_with?('-') && arg != '-'
    (1...arg.length).each do |i|
      option = arg[i]
      if option == 'l'
        show_line = true
      elsif option == 'w'
        show_word = true
      elsif option == 'c'
        show_byte = true
      else
        # 存在しないコマンドを指定された場合の処理
        puts "wc: illegal option -- #{option}"
        usage
      end
    end
  else
    # ワイルドカードの展開を含むファイル名の追加
    files = Dir.glob(arg)
    if files.empty?
      puts "wc: #{arg}: No such file or directory"
    else
      files.each { |file| file_paths << file }
    end
  end
end


# ファイル名が指定されているか確認
if file_paths.empty?
  usage
end


# オプションが一つも指定されていない場合は全て表示する
if !show_line && !show_word && !show_byte
  show_line = true
  show_word = true
  show_byte = true
end


# カウントの初期化
total_line = 0
total_word = 0
total_byte = 0


pattern = /\S+/

file_paths.each do |file_path|
  unless File.exist?(file_path)
    puts "wc: #{file_path}: No such file"
    next
  end


  line_count = 0
  word_count = 0
  byte_count = File.size(file_path)


  open(file_path) do |file|
    file.each do |line|
      line_count += 1
      words = line.scan(pattern)
      word_count += words.size
    end
  end


  # 合計に加算
  total_line += line_count
  total_word += word_count
  total_byte += byte_count


  # 出力
  output = ""
  output += sprintf("%8d", line_count) if show_line
  output += sprintf("%8d", word_count) if show_word
  output += sprintf("%8d", byte_count) if show_byte
  output += " #{file_path}"


  puts(output)
end


# 複数ファイルが指定されている場合、合計も表示
if file_paths.length > 1
  output = ""
  output += sprintf("%8d", total_line) if show_line
  output += sprintf("%8d", total_word) if show_word
  output += sprintf("%8d", total_byte) if show_byte
  output += " total"
  puts(output)
end
