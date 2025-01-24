def grep(pattern, filename)
  open(filename) do |file|
    file.each do |line|
      puts line if line =~ pattern
    end
  end
end

begin
  pattern_str = ARGV[0]
  filename = ARGV[1]
  pattern = Regexp.new(pattern_str)
  grep(pattern, filename)
rescue RegexpError => e
  puts "grep: unmatched (: /#{pattern_str}/"
rescue Errno::ENOENT => e
  puts "grep: #{filename}: No such file or directory"
rescue => e
  puts "grep: #{e.message}"
end
