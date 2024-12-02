def ntimes(n)
  i = 0
  while i < n
    yield
    i += 1
  end
end

ntimes(3) do
  puts "hello"
end
