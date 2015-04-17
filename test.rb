a = {}

a[0] = 1
a[1] = 2

a = a.each do |k,v|
	a[k] -= 1
end

p a