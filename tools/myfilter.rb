def myfilter (enum, &f)
  result = []
  enum.each { |e|
    result << e if f.call(e)
  }
  result
end

# 5より大きいもののみ
array1 = [7, 2, -3, 15]
puts "array1: #{myfilter(array1) {|e| e < 5}}"

# 奇数のもののみ
array2 = [7, 2, -3, 15]
puts "array2: #{myfilter(array2) {|e| e%2==1}}"

# 3の倍数のもののみ
array3 = [1, 2, 3, 4, 5, 6, 7]
puts "array2: #{myfilter(array3) {|e| e%3==0}}"